package services

import (
	"encoding/json"
	"fmt"
	"log"
	"strconv"
	"strings"
	"time"

	"neurotouch/config"
	"neurotouch/controllers"
	"neurotouch/models"

	mqtt "github.com/eclipse/paho.mqtt.golang"
)

var MqttClient mqtt.Client

func InitMqtt() {
	opts := mqtt.NewClientOptions()
	brokerURI := fmt.Sprintf("tcp://%s:%s", config.AppConfig.MqttBroker, config.AppConfig.MqttPort)
	opts.AddBroker(brokerURI)
	opts.SetClientID("neurotouch_backend_service")

	if config.AppConfig.MqttUsername != "" {
		opts.SetUsername(config.AppConfig.MqttUsername)
		opts.SetPassword(config.AppConfig.MqttPassword)
	}

	opts.SetCleanSession(true)
	opts.SetAutoReconnect(true)
	opts.SetMaxReconnectInterval(30 * time.Second)

	opts.OnConnect = func(client mqtt.Client) {
		log.Println("Successfully connected to EMQX MQTT Broker")

		topics := map[string]byte{
			"nt/v1/+/stat/telemetry": 1,
			"nt/v1/+/stat/state":     1,
			"nt/v1/+/lwt":            1,
			"tele/stove/+/status":    1,
			"tele/stove/+/lwt":       1,
		}

		for topic, qos := range topics {
			if token := client.Subscribe(topic, qos, onMessageReceived); token.Wait() && token.Error() != nil {
				log.Printf("Failed to subscribe to topic %s: %v", topic, token.Error())
			} else {
				log.Printf("Subscribed to MQTT topic: %s", topic)
			}
		}
	}

	opts.OnConnectionLost = func(client mqtt.Client, err error) {
		log.Printf("MQTT connection lost: %v", err)
	}

	MqttClient = mqtt.NewClient(opts)
	if token := MqttClient.Connect(); token.Wait() && token.Error() != nil {
		log.Printf("Failed to initiate MQTT broker connection: %v", token.Error())
	}

	// Link controller's publishing stub to the real MQTT client
	controllers.MqttPublish = func(topic string, payload string) {
		log.Printf("🖥️ [SERVER CONSOLE] App sent command via HTTP to topic %s: %s", topic, payload)

		// If sending a command to a gas controller, route to its specific topic
		if strings.HasPrefix(topic, "nt/v1/") && strings.HasSuffix(topic, "/cmd/gas_control") {
			parts := strings.Split(topic, "/")
			if len(parts) >= 3 {
				deviceID := parts[2]
				var dev models.Device
				if err := config.AppConfig.DB.Where("id = ?", deviceID).First(&dev).Error; err == nil {
					if dev.DeviceType == "gas_control" {
						// Transform to gas controller topic
						topic = fmt.Sprintf("cmd/stove/%s/control", deviceID)
					}
				}
			}
		}

		// [SIMULATOR] Fallback since hardware cannot connect to update DB
		parts := strings.Split(topic, "/")
		if len(parts) >= 5 && parts[4] == "state" {
			deviceID := parts[2]
			var parsed map[string]interface{}
			if err := json.Unmarshal([]byte(payload), &parsed); err == nil {
				if sw, ok := parsed["switches"]; ok {
					var device models.Device
					if err := config.AppConfig.DB.Where("id = ?", deviceID).First(&device).Error; err == nil {
						var currentConfig map[string]interface{}
						if device.Config != "" {
							json.Unmarshal([]byte(device.Config), &currentConfig)
						}
						if currentConfig == nil {
							currentConfig = make(map[string]interface{})
						}
						if swMap, ok := sw.(map[string]interface{}); ok {
							for k, v := range swMap {
								currentConfig[k] = v
							}
						}
						swBytes, _ := json.Marshal(currentConfig)
						config.AppConfig.DB.Model(&models.Device{}).Where("id = ?", deviceID).Update("config", string(swBytes))
						log.Printf("💾 [DB SIMULATOR] Saved switch state directly to database for %s: %s", deviceID, string(swBytes))
					}
				}
			}
		} else if len(parts) >= 4 && parts[0] == "cmd" && parts[1] == "stove" {
			deviceID := parts[2]
			var parsed struct {
				Action  string `json:"action"`
				Value   string `json:"value"`
				MotorID int    `json:"motor_id"`
			}
			if err := json.Unmarshal([]byte(payload), &parsed); err == nil {
				config.AppConfig.DB.Model(&models.GasMotor{}).
					Where("device_id = ? AND motor_id = ?", deviceID, parsed.MotorID).
					Update("state", parsed.Value)
				log.Printf("💾 [DB SIMULATOR] Saved gas state %s for motor %d to database", parsed.Value, parsed.MotorID)
			}
		}

		if MqttClient != nil && MqttClient.IsConnected() {
			token := MqttClient.Publish(topic, 1, false, payload)
			token.Wait()
			if token.Error() != nil {
				log.Printf("Failed to publish command to MQTT: %v", token.Error())
			}
		} else {
			log.Printf("[MQTT OFFLINE] Could not publish. Topic: %s, Payload: %s", topic, payload)
		}
	}

	// Start background cron to monitor heartbeat timeouts every 30 seconds
	go startHeartbeatTimeoutMonitor()
}

func onMessageReceived(client mqtt.Client, message mqtt.Message) {
	topic := message.Topic()
	payload := string(message.Payload())

	parts := strings.Split(topic, "/")
	
	// Handle Gas Stove Controller Topics
	if len(parts) >= 4 && parts[0] == "tele" && parts[1] == "stove" {
		handleStoveMessage(parts[2], parts[3], payload)
		return
	}

	// nt/v1/{deviceID}/{direction}/{action}
	if len(parts) < 4 || parts[0] != "nt" || parts[1] != "v1" {
		return
	}

	deviceID := parts[2]
	messageType := parts[3] // stat or lwt

	db := config.AppConfig.DB

	switch messageType {
	case "lwt":
		// Payload: {"uptime": 3600, "firmware": "v1.0.1"}
		var data map[string]interface{}
		_ = json.Unmarshal([]byte(payload), &data)

		now := time.Now()
		updates := map[string]interface{}{
			"is_online": true,
			"last_seen": &now,
		}

		if data != nil {
			if fw, exists := data["firmware"]; exists {
				fwStr := fmt.Sprintf("%v", fw)
				updates["firmware_version"] = &fwStr
			}
		}

		db.Model(&models.Device{}).Where("id = ?", deviceID).Updates(updates)

	case "stat":
		if len(parts) < 5 {
			return
		}
		action := parts[4]

		if action == "telemetry" {
			// Payload: {"rssi": -65, "uptime_sec": 3600, "free_heap": 40000, "fw_version": "1.0.0"}
			var data map[string]interface{}
			_ = json.Unmarshal([]byte(payload), &data)

			now := time.Now()
			updates := map[string]interface{}{
				"is_online": true,
				"last_seen": &now,
			}

			if data != nil {
				if fw, exists := data["fw_version"]; exists {
					fwStr := fmt.Sprintf("%v", fw)
					updates["firmware_version"] = &fwStr
				}
				
				// Optional: Insert specific telemetry metrics into telemetries table
				for k, v := range data {
					if k != "fw_version" && k != "uptime_sec" {
						val, _ := strconv.ParseFloat(fmt.Sprintf("%v", v), 64)
						telemetry := models.Telemetry{
							DeviceID:   deviceID,
							Metric:     k,
							Value:      val,
							RecordedAt: time.Now(),
						}
						db.Create(&telemetry)
					}
				}
			}
			db.Model(&models.Device{}).Where("id = ?", deviceID).Updates(updates)
		} else if action == "state" {
			// State updates are handled directly by EMQX Rules saving to Postgres.
			// But we mark it online here just in case.
			db.Model(&models.Device{}).Where("id = ?", deviceID).Update("is_online", true)
		}
	}
}

func startHeartbeatTimeoutMonitor() {
	ticker := time.NewTicker(30 * time.Second)
	db := config.AppConfig.DB

	for range ticker.C {
		// Mark devices as offline if they haven't sent a heartbeat in 60 seconds
		threshold := time.Now().Add(-60 * time.Second)
		db.Model(&models.Device{}).
			Where("is_online = ? AND last_seen < ?", true, threshold).
			Update("is_online", false)
	}
}

func handleStoveMessage(deviceID string, messageType string, payload string) {
	db := config.AppConfig.DB
	now := time.Now()

	if messageType == "lwt" {
		var data map[string]interface{}
		if err := json.Unmarshal([]byte(payload), &data); err == nil {
			isOnline := false
			if onlineVal, ok := data["online"].(bool); ok {
				isOnline = onlineVal
			}
			db.Model(&models.Device{}).Where("id = ?", deviceID).Updates(map[string]interface{}{
				"is_online": isOnline,
				"last_seen": &now,
			})
		}
	} else if messageType == "status" {
		var data struct {
			Motors []struct {
				ID         int     `json:"id"`
				Detected   bool    `json:"detected"`
				Pos        int     `json:"pos"`
				Deg        float32 `json:"deg"`
				Percent    int     `json:"percent"`
				State      string  `json:"state"`
				Moving     bool    `json:"moving"`
				Torque     bool    `json:"torque"`
				Voltage    float32 `json:"voltage"`
				Temper     int     `json:"temper"`
				PresetOff  int     `json:"presetOff"`
				PresetLow  int     `json:"presetLow"`
				PresetMed  int     `json:"presetMed"`
				PresetHigh int     `json:"presetHigh"`
			} `json:"motors"`
		}

		if err := json.Unmarshal([]byte(payload), &data); err == nil {
			// Update parent device online status
			db.Model(&models.Device{}).Where("id = ?", deviceID).Updates(map[string]interface{}{
				"is_online": true,
				"last_seen": &now,
			})

			// Sync motors to gas_motors table
			for _, m := range data.Motors {
				var motor models.GasMotor
				result := db.Where("device_id = ? AND motor_id = ?", deviceID, m.ID).First(&motor)
				
				motor.DeviceID = deviceID
				motor.MotorID = m.ID
				motor.Detected = m.Detected
				motor.Pos = m.Pos
				motor.Deg = m.Deg
				motor.Percent = m.Percent
				motor.State = m.State
				motor.Moving = m.Moving
				motor.Torque = m.Torque
				motor.Voltage = m.Voltage
				motor.Temper = m.Temper
				motor.PresetOff = m.PresetOff
				motor.PresetLow = m.PresetLow
				motor.PresetMed = m.PresetMed
				motor.PresetHigh = m.PresetHigh
				motor.UpdatedAt = now

				if result.Error != nil {
					db.Create(&motor)
				} else {
					db.Save(&motor)
				}
			}
		}
	}
}
