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

		// Subscribe to wildcards QoS 1
		topics := map[string]byte{
			"nt/v1/+/stat/telemetry": 1,
			"nt/v1/+/stat/state":     1,
			"nt/v1/+/lwt":            1,
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
		
		// [SIMULATOR] Fallback since hardware cannot connect to update DB
		parts := strings.Split(topic, "/")
		if len(parts) >= 5 && parts[4] == "state" {
			deviceID := parts[2]
			var parsed map[string]interface{}
			if err := json.Unmarshal([]byte(payload), &parsed); err == nil {
				if sw, ok := parsed["switches"]; ok {
					swBytes, _ := json.Marshal(sw)
					config.AppConfig.DB.Model(&models.Device{}).Where("id = ?", deviceID).Update("config", string(swBytes))
					log.Printf("💾 [DB SIMULATOR] Saved switch state directly to database for %s: %s", deviceID, string(swBytes))
				}
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
