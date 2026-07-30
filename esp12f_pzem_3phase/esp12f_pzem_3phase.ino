/**
 * ═══════════════════════════════════════════════════════════════
 * Neuro Power Meter — 3-Phase ESP12F Firmware (PZEM-004T v3.0)
 * ═══════════════════════════════════════════════════════════════
 *
 * IMPORTANT HARDWARE NOTE FOR 3-PHASE:
 * This version uses 3 separate Serial ports. You do NOT need to change 
 * the Modbus addresses of the PZEM modules. They can all remain at default.
 * 
 * Wire each PZEM to its respective RX/TX pins on the ESP12F.
 * 
 * Libraries required (install via Arduino Library Manager):
 *   - ESP8266WiFi        (built-in)
 *   - ESP8266WebServer   (built-in)
 *   - ESP8266HTTPClient  (built-in)
 *   - ArduinoJson        v6.x
 *   - PubSubClient       (by Nick O'Leary)
 *   - PZEM004Tv30        (by Jakub Mandula)
 *   - SoftwareSerial     (built-in)
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>
#include <EEPROM.h>
#include <PubSubClient.h>
#include <PZEM004Tv30.h>
#include <SoftwareSerial.h>

// ─── Configuration ────────────────────────────────────────────────────────────

#define AP_SSID "Three_Phase_1X"
#define AP_PASSWORD ""
#define AP_CHANNEL 6
#define AP_IP_ADDR 192, 168, 0, 4
#define AP_GATEWAY 192, 168, 0, 1
#define AP_SUBNET  255, 255, 255, 0

// Backend & MQTT Server configurations
#define BACKEND_HOST           "http://129.121.120.144:8080"
#define BACKEND_PROVISION_PATH "/api/v1/provision/mac-confirm"
#define MQTT_SERVER "129.121.120.144" // Replace with your actual MQTT broker IP
#define MQTT_PORT 1883
#define MQTT_USER "admin"
#define MQTT_PASS "Neurolinx@123"

// GPIO pins
#define LED_PIN 2      // Blue LED (active LOW on ESP12F)

// Phase 1 PZEM
#define PZEM1_RX_PIN 5  // D1
#define PZEM1_TX_PIN 4  // D2

// Phase 2 PZEM
#define PZEM2_RX_PIN 14 // D5
#define PZEM2_TX_PIN 12 // D6

// Phase 3 PZEM
#define PZEM3_RX_PIN 13 // D7
#define PZEM3_TX_PIN 15 // D8

// EEPROM layout
#define EEPROM_SIZE  256
#define SSID_ADDR    0
#define PASS_ADDR    64
#define DEVID_ADDR   192
#define VALID_FLAG   240

// Timeouts
#define WIFI_CONNECT_TIMEOUT_MS  30000
#define HTTP_TIMEOUT_MS          8000
#define POWER_UPDATE_INTERVAL_MS 5000
#define HEARTBEAT_INTERVAL_MS    60000

// ─── Globals ──────────────────────────────────────────────────────────────────
ESP8266WebServer server(80);
WiFiClient       wifiClient;
PubSubClient     mqttClient(wifiClient);

// Separate Serial Buses for each Phase
SoftwareSerial   pzemSerial1(PZEM1_RX_PIN, PZEM1_TX_PIN);
SoftwareSerial   pzemSerial2(PZEM2_RX_PIN, PZEM2_TX_PIN);
SoftwareSerial   pzemSerial3(PZEM3_RX_PIN, PZEM3_TX_PIN);

// Initialize 3 PZEM instances (they can all use default address 0x01 now)
PZEM004Tv30 pzemL1(pzemSerial1);
PZEM004Tv30 pzemL2(pzemSerial2);
PZEM004Tv30 pzemL3(pzemSerial3);

String savedSSID     = "";
String savedPassword = "";
String savedDeviceId = "";
bool   isProvisioned = false;
unsigned long lastPowerUpdate = 0;
unsigned long lastHeartbeat = 0;

// ─── EEPROM Helpers ──────────────────────────────────────────────────────────
void writeString(int addr, const String& str, int maxLen) {
    int len = min((int)str.length(), maxLen - 1);
    for (int i = 0; i < len; i++) {
        EEPROM.write(addr + i, str[i]);
    }
    EEPROM.write(addr + len, '\0');
}
String readString(int addr, int maxLen) {
    String s = "";
    for (int i = 0; i < maxLen; i++) {
        char c = (char)EEPROM.read(addr + i);
        if (c == '\0') break;
        s += c;
    }
    return s;
}
void saveCredentials(const String& ssid, const String& pass, const String& deviceId) {
    EEPROM.begin(EEPROM_SIZE);
    writeString(SSID_ADDR,  ssid,     64);
    writeString(PASS_ADDR,  pass,     128);
    writeString(DEVID_ADDR, deviceId, 32);
    EEPROM.write(VALID_FLAG, 0xAB);
    EEPROM.commit();
    EEPROM.end();
    savedSSID = ssid;
    savedPassword = pass;
    savedDeviceId = deviceId;
    Serial.println("[EEPROM] Credentials saved.");
}
bool loadCredentials() {
    EEPROM.begin(EEPROM_SIZE);
    byte flag = EEPROM.read(VALID_FLAG);
    if (flag != 0xAB) {
        EEPROM.end();
        return false;
    }
    savedSSID     = readString(SSID_ADDR,  64);
    savedPassword = readString(PASS_ADDR,  128);
    savedDeviceId = readString(DEVID_ADDR, 32);
    EEPROM.end();
    return true;
}
void clearCredentials() {
    EEPROM.begin(EEPROM_SIZE);
    EEPROM.write(VALID_FLAG, 0x00);
    EEPROM.commit();
    EEPROM.end();
}

// ─── LED Helpers ─────────────────────────────────────────────────────────────
void ledOn()  { digitalWrite(LED_PIN, LOW); }
void ledOff() { digitalWrite(LED_PIN, HIGH); }
void blinkLed(int times, int delayMs = 200) {
    for (int i = 0; i < times; i++) {
        ledOn(); delay(delayMs);
        ledOff(); delay(delayMs);
    }
}

// ─── MQTT Handlers ───────────────────────────────────────────────────────────
void mqttCallback(char* topic, byte* payload, unsigned int length) {
    String message = "";
    for (int i = 0; i < length; i++) message += (char)payload[i];
    Serial.println("[MQTT] Received on " + String(topic) + ": " + message);
    
    // Process commands here (e.g., reset energy for all phases)
    if (String(topic).endsWith("/cmd/reset_energy")) {
        Serial.println("[PZEM] App requested energy reset for all phases.");
        pzemL1.resetEnergy();
        pzemL2.resetEnergy();
        pzemL3.resetEnergy();
    }
}

void reconnectMqtt() {
    while (!mqttClient.connected()) {
        Serial.print("[MQTT] Attempting connection...");
        String clientId = "NT-PZEM3-" + String(WiFi.macAddress());
        String lwtTopic = "nt/v1/" + savedDeviceId + "/lwt";

        if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASS, lwtTopic.c_str(), 1, true, "{\"status\":\"offline\"}")) {
            Serial.println("connected");
            mqttClient.publish(lwtTopic.c_str(), "{\"status\":\"online\"}", true);
            String cmdTopic = "nt/v1/" + savedDeviceId + "/cmd/#";
            mqttClient.subscribe(cmdTopic.c_str());
        } else {
            Serial.print("failed, rc=");
            Serial.print(mqttClient.state());
            Serial.println(" try again in 5 seconds");
            delay(5000);
        }
    }
}

// ─── AP Mode HTTP Handlers ────────────────────────────────────────────────────
void handleRoot() {
    StaticJsonDocument<256> doc;
    doc["device"]       = "Three_Phase_1X";
    doc["sensor"]       = "PZEM-004T-100A-3Phase";
    doc["mac_address"]  = WiFi.softAPmacAddress();
    doc["firmware"]     = "1.0.0-pzem3";
    doc["status"]       = "awaiting_config";
    String body; serializeJson(doc, body);
    server.send(200, "application/json", body);
}
void handleConfig() {
    if (!server.hasArg("plain")) {
        server.send(400, "application/json", "{\"error\":\"No body\"}");
        return;
    }
    StaticJsonDocument<256> doc;
    deserializeJson(doc, server.arg("plain"));
    const char* ssid     = doc["ssid"]      | "";
    const char* password = doc["password"]  | "";
    const char* deviceId = doc["device_id"] | "";
    
    server.send(200, "application/json", "{\"success\":true}");
    delay(100); server.handleClient(); // Flush response
    saveCredentials(String(ssid), String(password), String(deviceId));
    ESP.restart(); // Reboot to connect to Wi-Fi
}
void handleReset() {
    server.send(200, "application/json", "{\"success\":true}");
    delay(500); clearCredentials(); ESP.restart();
}

// ─── Wi-Fi Station Connection ─────────────────────────────────────────────────
void connectToWiFi(const String& ssid, const String& password) {
    Serial.println("[WiFi] Connecting to: " + ssid);
    blinkLed(3, 100);
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), password.c_str());
    
    unsigned long startMs = millis();
    while (WiFi.status() != WL_CONNECTED) {
        if (millis() - startMs > WIFI_CONNECT_TIMEOUT_MS) {
            Serial.println("[WiFi] Connection TIMEOUT. Rebooting to AP.");
            clearCredentials();
            ESP.restart();
        }
        delay(500);
    }
    Serial.println("\n[WiFi] Connected! IP: " + WiFi.localIP().toString());
    isProvisioned = true;
    ledOn();
    
    String url = String(BACKEND_HOST) + String(BACKEND_PROVISION_PATH) + "?mac=" + WiFi.macAddress() + "&device_id=" + savedDeviceId;
    HTTPClient http;
    http.begin(wifiClient, url);
    http.setTimeout(HTTP_TIMEOUT_MS);
    int httpCode = http.GET();
    if (httpCode == HTTP_CODE_OK) {
        blinkLed(5, 300);
        ledOn();
    }
    http.end();
}

// ─── Helper for JSON Payload Generation ───────────────────────────────────────
void populatePhaseJson(JsonObject obj, PZEM004Tv30& pzem, int phaseNum) {
    float voltage = pzem.voltage();
    if (!isnan(voltage)) {
        String p = String(phaseNum);
        obj["voltage_" + p] = voltage;
        obj["current_" + p] = pzem.current();
        obj["power_" + p] = pzem.power();
        obj["pf_" + p] = pzem.pf();
    }
}

// ─── Setup & Loop ────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    pinMode(LED_PIN, OUTPUT);
    ledOff();
    
    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
    mqttClient.setCallback(mqttCallback);
    
    if (loadCredentials() && savedSSID.length() > 0) {
        connectToWiFi(savedSSID, savedPassword);
    } else {
        Serial.println("[Boot] No credentials — starting AP mode");
        WiFi.mode(WIFI_AP);
        IPAddress apIP(AP_IP_ADDR); IPAddress gateway(AP_GATEWAY); IPAddress subnet(AP_SUBNET);
        WiFi.softAPConfig(apIP, gateway, subnet);
        WiFi.softAP(AP_SSID, AP_PASSWORD, AP_CHANNEL);
        server.on("/", HTTP_GET, handleRoot);
        server.on("/config", HTTP_POST, handleConfig);
        server.on("/reset", HTTP_POST, handleReset);
        server.begin();
    }
}

void loop() {
    if (!isProvisioned) {
        server.handleClient();
        static unsigned long lastBlink = 0;
        if (millis() - lastBlink > 2000) {
            lastBlink = millis();
            blinkLed(1, 150);
        }
    } else {
        if (!mqttClient.connected()) {
            reconnectMqtt();
        }
        mqttClient.loop();
        
        // Publish 3-Phase power data every 5 seconds
        if (millis() - lastPowerUpdate > POWER_UPDATE_INTERVAL_MS) {
            lastPowerUpdate = millis();
            
            String pwrTopic = "nt/v1/" + savedDeviceId + "/stat/telemetry";
            
            // Using a larger buffer since 3 phases = more data
            StaticJsonDocument<768> doc;
            
            // Populate Phase 1, 2, 3 flat keys
            populatePhaseJson(doc.as<JsonObject>(), pzemL1, 1);
            populatePhaseJson(doc.as<JsonObject>(), pzemL2, 2);
            populatePhaseJson(doc.as<JsonObject>(), pzemL3, 3);
            
            // Calculate Totals
            float tEnergy = 0;
            float tPower = 0;
            if(!isnan(pzemL1.energy())) { tEnergy += pzemL1.energy(); tPower += pzemL1.power(); }
            if(!isnan(pzemL2.energy())) { tEnergy += pzemL2.energy(); tPower += pzemL2.power(); }
            if(!isnan(pzemL3.energy())) { tEnergy += pzemL3.energy(); tPower += pzemL3.power(); }
            
            doc["total_energy"] = tEnergy;
            doc["total_power"] = tPower;
            
            float freq = pzemL1.frequency();
            if(!isnan(freq)) doc["frequency"] = freq;
            
            String payload;
            serializeJson(doc, payload);
            mqttClient.publish(pwrTopic.c_str(), payload.c_str());
            
            Serial.println("[PZEM] 3-Phase Data Published.");
        }
        
        // Send heartbeat (telemetry) every 60s
        if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL_MS) {
            lastHeartbeat = millis();
            String telTopic = "nt/v1/" + savedDeviceId + "/stat/telemetry";
            
            StaticJsonDocument<256> doc;
            doc["rssi"] = WiFi.RSSI();
            doc["uptime_sec"] = millis() / 1000;
            doc["free_heap"] = ESP.getFreeHeap();
            doc["fw_version"] = "1.0.0-pzem3";
            
            String hbPayload;
            serializeJson(doc, hbPayload);
            mqttClient.publish(telTopic.c_str(), hbPayload.c_str());
        }
    }
}
