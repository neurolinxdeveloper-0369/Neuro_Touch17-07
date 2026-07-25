/**
 * ═══════════════════════════════════════════════════════════════
 * Neuro Touch Panel 8S — Complete ESP12F Firmware
 * ═══════════════════════════════════════════════════════════════
 *
 * This firmware handles:
 *  1. SoftAP provisioning if Wi-Fi credentials are not saved.
 *  2. EEPROM storage of Wi-Fi credentials and Device ID.
 *  3. Connection to Home Wi-Fi network.
 *  4. Registration to the Cloud Backend (MAC confirmation).
 *  5. Connection to the local MQTT broker using the provided Device ID.
 *  6. Handling MQTT commands (e.g., switches) and publishing telemetry/heartbeats.
 *
 * Libraries required (install via Arduino Library Manager):
 *   - ESP8266WiFi        (built-in with ESP8266 board package)
 *   - ESP8266WebServer   (built-in with ESP8266 board package)
 *   - ESP8266HTTPClient  (built-in with ESP8266 board package)
 *   - ArduinoJson        v6.x
 *   - PubSubClient       (by Nick O'Leary)
 *   - EEPROM             (built-in)
 */
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>
#include <EEPROM.h>
#include <PubSubClient.h>
// ─── Configuration ────────────────────────────────────────────────────────────
// Panel configuration
#define SWITCH_COUNT 8
#define TOSTRING(x) #x
#define AP_SSID "Neuro_Touch_" TOSTRING(SWITCH_COUNT) "S"
// Backend & MQTT Server configurations (Update these!)
#define BACKEND_HOST           "http://129.121.120.144:8082"
#define BACKEND_PROVISION_PATH "/api/v1/provision/mac-confirm"
#define MQTT_SERVER "129.121.120.144" // Replace with your actual MQTT broker IP
#define MQTT_PORT 1883
#define MQTT_USER "admin"
#define MQTT_PASS "Neurolinx@123"
// AP Mode Settings
#define AP_PASSWORD ""
#define AP_CHANNEL 6
#define AP_IP_ADDR 192, 168, 0, 4
#define AP_GATEWAY 192, 168, 0, 1
#define AP_SUBNET  255, 255, 255, 0
// GPIO pins
#define LED_PIN 2   // Blue LED (active LOW on ESP12F)
// Add GPIO definitions for your 8 relays here
// EEPROM layout
#define EEPROM_SIZE  256
#define SSID_ADDR    0
#define PASS_ADDR    64
#define DEVID_ADDR   192
#define VALID_FLAG   240
// Timeouts
#define WIFI_CONNECT_TIMEOUT_MS  30000
#define HTTP_TIMEOUT_MS          8000
// ─── Globals ──────────────────────────────────────────────────────────────────
ESP8266WebServer server(80);
WiFiClient       wifiClient;
PubSubClient     mqttClient(wifiClient);
String savedSSID     = "";
String savedPassword = "";
String savedDeviceId = "";
bool   isProvisioned = false;
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
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, message);
    if (err) return;
    // Check if it's a switch command
    if (String(topic).endsWith("/command/switch")) {
        int index = doc["switch_index"] | 0;
        bool state = doc["state"] | false;

        Serial.printf("[Switch] Toggling switch %d to %s\n", index, state ? "ON" : "OFF");

        // TODO: Write HIGH/LOW to your actual relay GPIO pins here based on 'index'

        // Acknowledge back with telemetry update
        String telemetryTopic = "neurotouch/devices/" + savedDeviceId + "/telemetry/switch";
        String payload = "{\"sw" + String(index) + "\": " + (state ? "true" : "false") + "}";
        mqttClient.publish(telemetryTopic.c_str(), payload.c_str());
    }
}
void reconnectMqtt() {
    while (!mqttClient.connected()) {
        Serial.print("[MQTT] Attempting connection...");
        String clientId = "NT-ESP-" + String(WiFi.macAddress());
        String statusTopic = "neurotouch/devices/" + savedDeviceId + "/status";

        // Connect with Last Will and Testament for status
        if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASS, statusTopic.c_str(), 1, true, "{\"status\":\"offline\"}")) {
            Serial.println("connected");

            // Publish online status immediately
            mqttClient.publish(statusTopic.c_str(), "{\"status\":\"online\"}", true);

            // Subscribe to all commands for this device
            String cmdTopic = "neurotouch/devices/" + savedDeviceId + "/command/#";
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
    doc["device"]       = "Neuro_Touch";
    doc["switch_count"] = SWITCH_COUNT;
    doc["mac_address"]  = WiFi.softAPmacAddress();
    doc["firmware"]     = "1.0.0";
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
            Serial.println("[WiFi] Connection TIMEOUT. Clearing credentials and rebooting to AP.");
            clearCredentials();
            ESP.restart();
        }
        delay(500);
    }
    Serial.println("\n[WiFi] Connected! IP: " + WiFi.localIP().toString());
    isProvisioned = true;
    ledOn(); // Steady blue = connected
    // Report MAC address to backend
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
        // Send heartbeat every 60s
        if (millis() - lastHeartbeat > 60000) {
            lastHeartbeat = millis();
            String hbTopic = "neurotouch/devices/" + savedDeviceId + "/heartbeat";
            String hbPayload = "{\"uptime\":" + String(millis()/1000) + "}";
            mqttClient.publish(hbTopic.c_str(), hbPayload.c_str());
        }
    }
}