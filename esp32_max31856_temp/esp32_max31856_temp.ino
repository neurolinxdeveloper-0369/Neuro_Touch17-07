/**
 * ═══════════════════════════════════════════════════════════════
 * Neuro Temp Monitor — Complete ESP32 Firmware
 * ═══════════════════════════════════════════════════════════════
 */

#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <EEPROM.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Adafruit_MAX31856.h>
#include <PZEM004Tv30.h>
#include <SPI.h>

// ─── Configuration ────────────────────────────────────────────────────────────

#define AP_SSID "Temp_Monitor_1T"
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

// EEPROM layout
#define EEPROM_SIZE  256
#define SSID_ADDR    0
#define PASS_ADDR    64
#define DEVID_ADDR   192
#define VALID_FLAG   240

// Timeouts
#define WIFI_CONNECT_TIMEOUT_MS  30000
#define HTTP_TIMEOUT_MS          8000
#define TELEMETRY_INTERVAL_MS    5000

// ─── Hardware Setup ──────────────────────────────────────────────────────────
Adafruit_MAX31856 maxthermo = Adafruit_MAX31856(5); // CS=5
PZEM004Tv30 pzemFan1(&Serial1, 16, 17); // Fan 1
PZEM004Tv30 pzemFan2(&Serial2, 14, 15); // Fan 2

// ─── Globals ──────────────────────────────────────────────────────────────────
WebServer    server(80);
WiFiClient   wifiClient;
PubSubClient mqttClient(wifiClient);

String savedSSID     = "";
String savedPassword = "";
String savedDeviceId = "";
bool   isProvisioned = false;
unsigned long lastPublish = 0;

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
    writeString(SSID_ADDR, ssid, 64);
    writeString(PASS_ADDR, pass, 64);
    writeString(DEVID_ADDR, deviceId, 48);
    EEPROM.write(VALID_FLAG, 1);
    EEPROM.commit();
}
bool loadCredentials() {
    EEPROM.begin(EEPROM_SIZE);
    if (EEPROM.read(VALID_FLAG) == 1) {
        savedSSID = readString(SSID_ADDR, 64);
        savedPassword = readString(PASS_ADDR, 64);
        savedDeviceId = readString(DEVID_ADDR, 48);
        return true;
    }
    return false;
}
void clearCredentials() {
    EEPROM.begin(EEPROM_SIZE);
    EEPROM.write(VALID_FLAG, 0);
    EEPROM.commit();
    isProvisioned = false;
}

// ─── MQTT Reconnect ───────────────────────────────────────────────────────────
void reconnectMqtt() {
    while (!mqttClient.connected()) {
        Serial.print("[MQTT] Attempting connection...");
        String clientId = "NT-TEMP-" + String(WiFi.macAddress());
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

void mqttCallback(char* topic, byte* payload, unsigned int length) {
    String msg;
    for (int i = 0; i < length; i++) {
        msg += (char)payload[i];
    }
    Serial.print("[MQTT] Message arrived [");
    Serial.print(topic);
    Serial.print("] ");
    Serial.println(msg);
}

// ─── AP Mode HTTP Handlers ────────────────────────────────────────────────────
void handleRoot() {
    StaticJsonDocument<256> doc;
    doc["device"]       = "Temp_Monitor_1T";
    doc["sensor"]       = "MAX31856_2xPZEM";
    doc["mac_address"]  = WiFi.softAPmacAddress();
    doc["firmware"]     = "1.0.0-temp";
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
        Serial.print(".");
    }
    Serial.println("\n[WiFi] Connected! IP: " + WiFi.localIP().toString());
    isProvisioned = true;
    
    // Report MAC address to backend
    String url = String(BACKEND_HOST) + String(BACKEND_PROVISION_PATH) + "?mac=" + WiFi.macAddress() + "&device_id=" + savedDeviceId;
    HTTPClient http;
    http.begin(url);
    http.setTimeout(HTTP_TIMEOUT_MS);
    int httpCode = http.GET();
    if (httpCode == HTTP_CODE_OK) {
        Serial.println("[PROVISION] Backend MAC confirm successful!");
    }
    http.end();
}

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n\n═════════════════════════════════════════════════");
    Serial.println("   Neuro Temp Monitor (MAX31856 + 2x PZEM)       ");
    Serial.println("═════════════════════════════════════════════════");

    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
    mqttClient.setCallback(mqttCallback);

    if (loadCredentials() && savedSSID.length() > 0) {
        connectToWiFi(savedSSID, savedPassword);
        
        // Initialize Sensors only if we are in STA mode connecting
        if (!maxthermo.begin()) {
            Serial.println("[ERROR] Could not initialize MAX31856.");
        } else {
            maxthermo.setThermocoupleType(MAX31856_TCTYPE_K);
            Serial.println("[SENSOR] MAX31856 initialized.");
        }
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

// ─── Main Loop ────────────────────────────────────────────────────────────────
void loop() {
    if (!isProvisioned) {
        server.handleClient();
        return;
    }

    if (WiFi.status() != WL_CONNECTED) {
        Serial.print("[WiFi] Reconnecting...");
        WiFi.begin(savedSSID.c_str(), savedPassword.c_str());
        while (WiFi.status() != WL_CONNECTED) {
            delay(500);
            Serial.print(".");
        }
        Serial.println("\n[WiFi] Reconnected!");
    }

    if (!mqttClient.connected()) {
        reconnectMqtt();
    }
    mqttClient.loop();

    // Telemetry Publishing
    if (millis() - lastPublish >= TELEMETRY_INTERVAL_MS) {
        lastPublish = millis();
        
        float coldJunction = maxthermo.readCJTemperature();
        float thermocouple = maxthermo.readThermocoupleTemperature();
        
        uint8_t fault = maxthermo.readFault();
        if (fault) {
            Serial.println("[SENSOR] MAX31856 Fault detected! Skipping publish.");
            return;
        }

        float currentFan1 = pzemFan1.current();
        float currentFan2 = pzemFan2.current();

        if (isnan(currentFan1)) currentFan1 = 0.0;
        if (isnan(currentFan2)) currentFan2 = 0.0;

        StaticJsonDocument<256> doc;
        doc["temperature"] = serialized(String(thermocouple, 2));
        doc["cold_junction"] = serialized(String(coldJunction, 2));
        doc["fan1_current"] = serialized(String(currentFan1, 2));
        doc["fan2_current"] = serialized(String(currentFan2, 2));
        
        String payload;
        serializeJson(doc, payload);

        String telemetryTopic = "nt/v1/" + savedDeviceId + "/stat/telemetry";
        mqttClient.publish(telemetryTopic.c_str(), payload.c_str());
        
        Serial.println("[MQTT] Published: " + payload);
    }
}
