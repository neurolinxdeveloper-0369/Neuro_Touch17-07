/**
 * ═══════════════════════════════════════════════════════════════
 * Neuro Power Meter — Complete ESP12F Firmware (PZEM-004T v3.0)
 * ═══════════════════════════════════════════════════════════════
 *
 * This firmware handles:
 *  1. SoftAP provisioning if Wi-Fi credentials are not saved.
 *  2. EEPROM storage of Wi-Fi credentials and Device ID.
 *  3. Connection to Home Wi-Fi network.
 *  4. Registration to the Cloud Backend (MAC confirmation).
 *  5. Connection to the local MQTT broker using the provided Device ID.
 *  6. Reading PZEM-004T v3.0 (100A) data and publishing over MQTT.
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

#define AP_SSID "Single_Phase_1X"
#define AP_PASSWORD ""
#define AP_CHANNEL 6
#define AP_IP_ADDR 192, 168, 0, 4
#define AP_GATEWAY 192, 168, 0, 1
#define AP_SUBNET  255, 255, 255, 0

// Backend & MQTT Server configurations
#define BACKEND_HOST           "http://129.121.120.144:8080"
#define BACKEND_PROVISION_PATH "/api/v1/provision/mac-confirm"
#define MQTT_SERVER "129.121.120.144" // Replace with your actual MQTT broker IP
#define MQTT_PORT 8086
#define MQTT_USER "admin"
#define MQTT_PASS "Neurolinx@123"

// GPIO pins
#define LED_PIN 2   // Blue LED (active LOW on ESP12F)
#define PZEM_RX_PIN 14 // D5 (GPIO14) on ESP12F / NodeMCU
#define PZEM_TX_PIN 12 // D6 (GPIO12) on ESP12F / NodeMCU

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
SoftwareSerial   pzemSWSerial(PZEM_RX_PIN, PZEM_TX_PIN);
PZEM004Tv30      pzem(pzemSWSerial);

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
    
    // Process commands here (e.g., reset energy from app)
    if (String(topic).endsWith("/cmd/reset_energy")) {
        Serial.println("[PZEM] App requested energy reset.");
        pzem.resetEnergy();
    }
}

void reconnectMqtt() {
    while (!mqttClient.connected()) {
        Serial.print("[MQTT] Attempting connection...");
        String clientId = "NT-PZEM-" + String(WiFi.macAddress());
        String lwtTopic = "nt/v1/" + savedDeviceId + "/lwt";

        // Connect with Last Will and Testament for status
        if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASS, lwtTopic.c_str(), 1, true, "{\"status\":\"offline\"}")) {
            Serial.println("connected");
            
            // Publish online status immediately (Retained)
            mqttClient.publish(lwtTopic.c_str(), "{\"status\":\"online\"}", true);

            // Subscribe to all commands for this device
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
    doc["device"]       = "Single_Phase_1X";
    doc["sensor"]       = "PZEM-004T-100A";
    doc["mac_address"]  = WiFi.softAPmacAddress();
    doc["firmware"]     = "1.0.0-pzem";
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
    
    // Optional: Reset Energy on boot for testing (comment out for production)
    // pzem.resetEnergy();
    
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
        
        // Publish PZEM power data every 5 seconds
        if (millis() - lastPowerUpdate > POWER_UPDATE_INTERVAL_MS) {
            lastPowerUpdate = millis();
            
            float voltage   = pzem.voltage();
            float current   = pzem.current();
            float powerW    = pzem.power();      // Watts from PZEM
            float energy    = pzem.energy();     // kWh (library returns kWh)
            float frequency = pzem.frequency();
            float pf        = pzem.pf();
            
            if (isnan(voltage)) {
                Serial.println("[PZEM] Error reading data. Check wiring!");
            } else {
                float powerKW = powerW / 1000.0f;  // Convert W → kW
                
                Serial.printf("[PZEM] V: %.1f, I: %.4f A, P: %.4f kW, E: %.4f kWh, Hz: %.1f, PF: %.2f\n", 
                              voltage, current, powerKW, energy, frequency, pf);
                              
                String pwrTopic = "nt/v1/" + savedDeviceId + "/stat/telemetry";
                StaticJsonDocument<256> doc;
                doc["voltage"]      = serialized(String(voltage,   1));
                doc["current"]      = serialized(String(current,   4));
                doc["power"]        = serialized(String(powerKW,   4));  // kW
                doc["energy_kwh"]   = serialized(String(energy,    4));  // kWh
                doc["frequency"]    = serialized(String(frequency, 1));
                doc["power_factor"] = serialized(String(pf,        2));
                
                String payload;
                serializeJson(doc, payload);
                mqttClient.publish(pwrTopic.c_str(), payload.c_str());
                Serial.println("[MQTT] Published: " + payload);
            }
        }
        
        // Send heartbeat (telemetry) every 60s
        if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL_MS) {
            lastHeartbeat = millis();
            String telTopic = "nt/v1/" + savedDeviceId + "/stat/telemetry";
            
            StaticJsonDocument<256> doc;
            doc["rssi"] = WiFi.RSSI();
            doc["uptime_sec"] = millis() / 1000;
            doc["free_heap"] = ESP.getFreeHeap();
            doc["fw_version"] = "1.0.0-pzem";
            
            String hbPayload;
            serializeJson(doc, hbPayload);
            mqttClient.publish(telTopic.c_str(), hbPayload.c_str());
        }
    }
}
