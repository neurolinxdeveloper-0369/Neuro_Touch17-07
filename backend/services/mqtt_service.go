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
			"neurotouch/devices/+/telemetry/#": 1,
			"neurotouch/devices/+/status":      1,
			"neurotouch/devices/+/heartbeat":   1,
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
	if len(parts) < 4 || parts[0] != "neurotouch" || parts[1] != "devices" {
		return
	}

	deviceID := parts[2]
	messageType := parts[3]

	db := config.AppConfig.DB

	switch messageType {
	case "heartbeat":
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

	case "status":
		// Payload: {"status": "online"} or {"status": "offline"}
		var data map[string]interface{}
		_ = json.Unmarshal([]byte(payload), &data)

		if data != nil {
			if status, exists := data["status"]; exists {
				isOnline := status == "online"
				db.Model(&models.Device{}).Where("id = ?", deviceID).Update("is_online", isOnline)
			}
		}

	case "telemetry":
		if len(parts) < 5 {
			return
		}
		metric := parts[4]
		// Payload: {"value": 230.5} or value directly
		var val float64
		var err error

		// Try loading json
		var data map[string]interface{}
		if errJson := json.Unmarshal([]byte(payload), &data); errJson == nil && data != nil {
			if v, exists := data["value"]; exists {
				val, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64)
			} else {
				// Try key matching metric
				if v, exists := data[metric]; exists {
					val, _ = strconv.ParseFloat(fmt.Sprintf("%v", v), 64)
				}
			}
		} else {
			// Direct float value string
			val, err = strconv.ParseFloat(payload, 64)
			if err != nil {
				return // invalid payload format
			}
		}

		// Insert into telemetry table
		telemetry := models.Telemetry{
			DeviceID:   deviceID,
			Metric:     metric,
			Value:      val,
			RecordedAt: time.Now(),
		}
		db.Create(&telemetry)
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
