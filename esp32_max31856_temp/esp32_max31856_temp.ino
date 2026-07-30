#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Adafruit_MAX31856.h>
#include <PZEM004Tv30.h>
#include <SPI.h>

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------
const char* ssid = "YOUR_SSID";
const char* pass = "YOUR_PASSWORD";

const char* mqtt_server = "192.168.1.100"; // Replace with your backend IP
const int mqtt_port = 8086; // EMQX default port
const char* mqtt_user = "neuro_device";
const char* mqtt_pass = "neuro_secret";

// -----------------------------------------------------------------------------
// MAX31856 & PZEM Setup
// -----------------------------------------------------------------------------
// Use hardware SPI for MAX31856 (ESP32 VSPI: CS=5, MOSI=23, MISO=19, SCK=18):
Adafruit_MAX31856 maxthermo = Adafruit_MAX31856(5);

// PZEM instances for Fans (HardwareSerial 1 and 2)
// Fan 1 on Serial1 (RX=16, TX=17)
PZEM004Tv30 pzemFan1(&Serial1, 16, 17);
// Fan 2 on Serial2 (RX=14, TX=15)
PZEM004Tv30 pzemFan2(&Serial2, 14, 15);

// -----------------------------------------------------------------------------
// Global Variables
// -----------------------------------------------------------------------------
WiFiClient espClient;
PubSubClient mqttClient(espClient);

String savedMacAddress;
String savedDeviceId;

unsigned long lastPublish = 0;
const unsigned long PUBLISH_INTERVAL = 5000; // 5 seconds

// -----------------------------------------------------------------------------
// Utility Functions
// -----------------------------------------------------------------------------
String getMacAddress() {
    uint8_t mac[6];
    WiFi.macAddress(mac);
    char macStr[18];
    sprintf(macStr, "%02x%02x%02x%02x%02x%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return String(macStr);
}

// -----------------------------------------------------------------------------
// WiFi & MQTT Setup
// -----------------------------------------------------------------------------
void connectWiFi() {
    Serial.print("[WiFi] Connecting to ");
    Serial.println(ssid);
    WiFi.begin(ssid, pass);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\n[WiFi] Connected!");
    Serial.print("[WiFi] IP: ");
    Serial.println(WiFi.localIP());
}

void reconnectMQTT() {
    while (!mqttClient.connected()) {
        Serial.print("[MQTT] Attempting connection...");
        
        // Client ID e.g., "esp32-temp-aabbccddeeff"
        String clientId = "esp32-temp-" + savedMacAddress;

        if (mqttClient.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
            Serial.println(" Connected!");
            // Publish online status
            String statusTopic = "nt/v1/" + savedDeviceId + "/stat/status";
            mqttClient.publish(statusTopic.c_str(), "online", true);
        } else {
            Serial.print(" Failed, rc=");
            Serial.print(mqttClient.state());
            Serial.println(" Trying again in 5 seconds");
            delay(5000);
        }
    }
}

// -----------------------------------------------------------------------------
// Main Setup
// -----------------------------------------------------------------------------
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n\n--- Neuro Touch ESP32 Temp Monitor (MAX31856) ---");

    // Initialize Sensor
    if (!maxthermo.begin()) {
        Serial.println("[ERROR] Could not initialize MAX31856. Check wiring!");
        while (1) delay(10);
    }
    
    // Set thermocouple type (default is K type, change if you use J, T, etc.)
    maxthermo.setThermocoupleType(MAX31856_TCTYPE_K);
    Serial.println("[SENSOR] MAX31856 initialized. Type K Thermocouple set.");

    // Connect Networking
    connectWiFi();
    
    savedMacAddress = getMacAddress();
    savedDeviceId = "nt-" + savedMacAddress.substring(6); // match backend format 'nt-XXXXXX'
    
    Serial.println("[SYS] Device ID: " + savedDeviceId);

    mqttClient.setServer(mqtt_server, mqtt_port);
}

// -----------------------------------------------------------------------------
// Main Loop
// -----------------------------------------------------------------------------
void loop() {
    if (WiFi.status() != WL_CONNECTED) {
        connectWiFi();
    }
    if (!mqttClient.connected()) {
        reconnectMQTT();
    }
    mqttClient.loop();

    if (millis() - lastPublish >= PUBLISH_INTERVAL) {
        lastPublish = millis();
        
        // Read Temperature
        float coldJunction = maxthermo.readCJTemperature();
        float thermocouple = maxthermo.readThermocoupleTemperature();
        
        // Check for faults
        uint8_t fault = maxthermo.readFault();
        if (fault) {
            Serial.print("[SENSOR] Fault detected: ");
            if (fault & MAX31856_FAULT_CJRANGE) Serial.print("Cold Junction Range ");
            if (fault & MAX31856_FAULT_TCRANGE) Serial.print("Thermocouple Range ");
            if (fault & MAX31856_FAULT_CJHIGH)  Serial.print("Cold Junction High ");
            if (fault & MAX31856_FAULT_CJLOW)   Serial.print("Cold Junction Low ");
            if (fault & MAX31856_FAULT_TCHIGH)  Serial.print("Thermocouple High ");
            if (fault & MAX31856_FAULT_TCLOW)   Serial.print("Thermocouple Low ");
            if (fault & MAX31856_FAULT_OVUV)    Serial.print("Over/Under Voltage ");
            if (fault & MAX31856_FAULT_OPEN)    Serial.print("Thermocouple Open ");
            Serial.println();
            return; // Skip publish on fault
        }

        Serial.print("[SENSOR] CJ Temp: ");
        Serial.print(coldJunction);
        Serial.print(" C  |  TC Temp: ");
        Serial.print(thermocouple);
        Serial.println(" C");

        // Read PZEM currents
        float currentFan1 = pzemFan1.current();
        float currentFan2 = pzemFan2.current();

        if (isnan(currentFan1)) currentFan1 = 0.0;
        if (isnan(currentFan2)) currentFan2 = 0.0;

        Serial.print("[FAN] Fan1 Current: ");
        Serial.print(currentFan1);
        Serial.print(" A  |  Fan2 Current: ");
        Serial.print(currentFan2);
        Serial.println(" A");

        // Build JSON Payload
        StaticJsonDocument<256> doc;
        doc["temperature"] = serialized(String(thermocouple, 2));
        doc["cold_junction"] = serialized(String(coldJunction, 2));
        doc["fan1_current"] = serialized(String(currentFan1, 2));
        doc["fan2_current"] = serialized(String(currentFan2, 2));
        
        String payload;
        serializeJson(doc, payload);

        // Publish Telemetry
        String telemetryTopic = "nt/v1/" + savedDeviceId + "/stat/telemetry";
        mqttClient.publish(telemetryTopic.c_str(), payload.c_str());
        
        Serial.println("[MQTT] Published: " + payload);
    }
}
