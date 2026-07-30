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
		// Payload: {"uptime": 3600, "firmware": "v1.0.1"} or {"online": false} or "Offline"
		var data map[string]interface{}
		err := json.Unmarshal([]byte(payload), &data)

		isOnline := true
		if err == nil {
			if onlineVal, ok := data["online"].(bool); ok {
				isOnline = onlineVal
			} else if statusStr, ok := data["status"].(string); ok {
				if strings.ToLower(statusStr) == "offline" {
					isOnline = false
				}
			}
		} else {
			if strings.ToLower(strings.TrimSpace(payload)) == "offline" {
				isOnline = false
			}
		}

		now := time.Now()
		updates := map[string]interface{}{
			"is_online": isOnline,
			"last_seen": &now,
		}

		if data != nil {
			if fw, exists := data["firmware"]; exists {
				fwStr := fmt.Sprintf("%v", fw)
				updates["firmware_version"] = &fwStr
			}
			if rssi, exists := data["rssi"]; exists {
				if r, err := strconv.Atoi(fmt.Sprintf("%v", rssi)); err == nil {
					updates["rssi"] = &r
				}
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
				if rssi, exists := data["rssi"]; exists {
					if r, err := strconv.Atoi(fmt.Sprintf("%v", rssi)); err == nil {
						updates["rssi"] = &r
					}
				}
				
				_, hasEnergyKwh := data["energy_kwh"]
				_, hasTotalEnergy := data["total_energy"]
				_, hasVoltage1 := data["voltage_1"]
				
				if hasEnergyKwh || hasTotalEnergy || hasVoltage1 {
					energy := models.EnergyReading{
						DeviceID: deviceID,
						RecordedAt: time.Now(),
					}
					
					// 1-Phase mappings (fallback)
					if v, ok := data["voltage"]; ok { energy.Voltage1, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["current"]; ok { energy.Current1, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["power"]; ok { energy.Power1, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["power_factor"]; ok { energy.Pf1, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["energy_kwh"]; ok { energy.TotalEnergy, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					
					// 3-Phase mappings
					if v, ok := data["voltage_1"]; ok { energy.Voltage1, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["current_1"]; ok { energy.Current1, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["power_1"]; ok { energy.Power1, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["pf_1"]; ok { energy.Pf1, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					
					if v, ok := data["voltage_2"]; ok { energy.Voltage2, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["current_2"]; ok { energy.Current2, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["power_2"]; ok { energy.Power2, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["pf_2"]; ok { energy.Pf2, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					
					if v, ok := data["voltage_3"]; ok { energy.Voltage3, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["current_3"]; ok { energy.Current3, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["power_3"]; ok { energy.Power3, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["pf_3"]; ok { energy.Pf3, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					
					if v, ok := data["total_power"]; ok { energy.TotalPower, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["total_energy"]; ok { energy.TotalEnergy, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					if v, ok := data["frequency"]; ok { energy.Frequency, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64) }
					
					db.Create(&energy)
				} else {
					// ----------------------------------------------------
					// TEMP MONITOR THRESHOLD ALERTS LOGIC
					// ----------------------------------------------------
					if tempVal, ok := data["temperature"]; ok {
						tempFloat, _ := strconv.ParseFloat(fmt.Sprintf("%v", tempVal), 64)

						var device models.Device
						if err := db.Where("id = ?", deviceID).First(&device).Error; err == nil {
							var cfg map[string]interface{}
							if device.Config != "" {
								json.Unmarshal([]byte(device.Config), &cfg)
								
								// Alert threshold processing
								sendAlert := false
								alertMessage := ""

								if maxTempRaw, exists := cfg["max_temp"]; exists {
									maxTemp, _ := strconv.ParseFloat(fmt.Sprintf("%v", maxTempRaw), 64)
									if tempFloat >= maxTemp {
										sendAlert = true
										alertMessage = fmt.Sprintf("Temperature %.1f exceeded MAX threshold of %.1f!", tempFloat, maxTemp)
									}
								}

								if !sendAlert { // only send one alert at a time
									if minTempRaw, exists := cfg["min_temp"]; exists {
										minTemp, _ := strconv.ParseFloat(fmt.Sprintf("%v", minTempRaw), 64)
										if tempFloat <= minTemp {
											sendAlert = true
											alertMessage = fmt.Sprintf("Temperature %.1f dropped below MIN threshold of %.1f!", tempFloat, minTemp)
										}
									}
								}

								if sendAlert {
									// Simple debouncing: Check if we already alerted in the last 15 minutes
									var lastAlert models.Notification
									err := db.Where("device_id = ? AND title = ? AND created_at > ?", device.ID, "Temperature Alert", time.Now().Add(-15*time.Minute)).Order("created_at desc").First(&lastAlert).Error
									
									if err != nil { // No recent alert found
										// Create notification for Home Owner
										var home models.Home
										if err := db.Where("id = ?", device.HomeID).First(&home).Error; err == nil {
											db.Create(&models.Notification{
												UserID:   home.OwnerID,
												Title:    "Temperature Alert",
												Body:     fmt.Sprintf("%s: %s", device.Name, alertMessage),
												DeviceID: &device.ID,
											})

											// TRIGGER FCM FULL-SCREEN ALARM
											var owner models.User
											if err := db.Where("id = ?", home.OwnerID).First(&owner).Error; err == nil {
												if owner.FCMToken != nil && *owner.FCMToken != "" {
													roomName := "Unknown Room"
													if device.RoomID != nil {
														// Optional: We can lookup the room name, or just pass assignment type
														roomName = device.AssignmentType
													} else {
														roomName = device.AssignmentType
													}
													go SendCriticalAlarm(*owner.FCMToken, device.ID, roomName, tempFloat)
												}
											}
										}
									}
								}
							}
						}
					}
					// ----------------------------------------------------

					// Optional: Insert specific telemetry metrics into telemetries table
					for k, v := range data {
						if k != "fw_version" && k != "uptime_sec" && k != "timestamp" {
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
			}
			db.Model(&models.Device{}).Where("id = ?", deviceID).Updates(updates)
		} else if action == "state" {
			// Save the state to Postgres directly when MQTT status is received from hardware
			var data map[string]interface{}
			if err := json.Unmarshal([]byte(payload), &data); err == nil {
				if sw, ok := data["switches"]; ok {
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
					}
				}
			}
			db.Model(&models.Device{}).Where("id = ?", deviceID).Update("is_online", true)
		}
	}
}

func startHeartbeatTimeoutMonitor() {
	ticker := time.NewTicker(30 * time.Second)
	db := config.AppConfig.DB

	for range ticker.C {
		// Mark devices as offline if they haven't sent a heartbeat in 120 seconds
		threshold := time.Now().Add(-120 * time.Second)
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
