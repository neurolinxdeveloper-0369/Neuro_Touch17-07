/**
 * ═══════════════════════════════════════════════════════════════
 * Neuro Temp Monitor — Complete ESP32 Firmware
 * ═══════════════════════════════════════════════════════════════
 *
 * This firmware handles:
 *  1. SoftAP provisioning if Wi-Fi credentials are not saved.
 *  2. EEPROM storage of Wi-Fi credentials and Device ID.
 *  3. Connection to Home Wi-Fi network.
 *  4. Registration to the Cloud Backend (MAC confirmation).
 *  5. Connection to the local MQTT broker using the provided Device ID.
 *  6. Reading MAX31856 Temp Sensor and 2x PZEM-004T v3.0 over MQTT.
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
// Use hardware SPI for MAX31856 (ESP32 VSPI: CS=5, MOSI=23, MISO=19, SCK=18)
Adafruit_MAX31856 maxthermo = Adafruit_MAX31856(5);

// PZEM instances for Fans (HardwareSerial 1 and 2)
// Fan 1 on Serial1 (RX=16, TX=17)
PZEM004Tv30 pzemFan1(&Serial1, 16, 17);
// Fan 2 on Serial2 (RX=14, TX=15)
PZEM004Tv30 pzemFan2(&Serial2, 14, 15);

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
void loadCredentials() {
    EEPROM.begin(EEPROM_SIZE);
    if (EEPROM.read(VALID_FLAG) == 1) {
        savedSSID = readString(SSID_ADDR, 64);
        savedPassword = readString(PASS_ADDR, 64);
        savedDeviceId = readString(DEVID_ADDR, 48);
        isProvisioned = (savedSSID.length() > 0 && savedDeviceId.length() > 0);
    }
}
void clearCredentials() {
    EEPROM.begin(EEPROM_SIZE);
    EEPROM.write(VALID_FLAG, 0);
    EEPROM.commit();
    isProvisioned = false;
}

// ─── Utility Functions ────────────────────────────────────────────────────────
String getMacAddress() {
    uint8_t mac[6];
    WiFi.macAddress(mac);
    char macStr[18];
    sprintf(macStr, "%02X:%02X:%02X:%02X:%02X:%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return String(macStr);
}
String getMacAddressClean() {
    uint8_t mac[6];
    WiFi.macAddress(mac);
    char macStr[18];
    sprintf(macStr, "%02x%02x%02x%02x%02x%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return String(macStr);
}

// ─── Web Server Handlers ──────────────────────────────────────────────────────
void handleRoot() {
    String mac = getMacAddress();
    String html = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
  <title>Neuro Touch Setup</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0f172a; color: white; margin: 0; display: flex; align-items: center; justify-content: center; height: 100vh; }
    .card { background: #1e293b; padding: 2rem; border-radius: 12px; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.5); width: 90%; max-width: 400px; text-align: center; }
    h2 { color: #38bdf8; margin-top: 0; }
    input[type="text"], input[type="password"] { width: 100%; padding: 12px; margin: 8px 0 20px 0; border: 1px solid #334155; border-radius: 6px; background: #0f172a; color: white; box-sizing: border-box; }
    input[type="submit"] { width: 100%; padding: 12px; background: #38bdf8; color: #0f172a; border: none; border-radius: 6px; font-weight: bold; font-size: 16px; cursor: pointer; transition: 0.2s; }
    input[type="submit"]:hover { background: #0ea5e9; }
    .mac { font-family: monospace; color: #94a3b8; font-size: 12px; margin-bottom: 20px; display: block; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Configure Device</h2>
    <span class="mac">MAC: )rawliteral" + mac + R"rawliteral(</span>
    <form action="/save" method="POST">
      <div style="text-align: left;"><label>Wi-Fi SSID</label></div>
      <input type="text" name="ssid" required placeholder="Network Name">
      <div style="text-align: left;"><label>Wi-Fi Password</label></div>
      <input type="password" name="password" placeholder="Leave blank if open">
      <input type="submit" value="Connect & Register">
    </form>
  </div>
</body>
</html>
)rawliteral";
    server.send(200, "text/html", html);
}

void handleSave() {
    if (server.hasArg("ssid")) {
        String newSSID = server.arg("ssid");
        String newPass = server.arg("password");
        
        server.send(200, "text/html", "<html><body style='background:#0f172a;color:white;text-align:center;font-family:sans-serif;padding-top:20vh;'><h2>Connecting...</h2><p>Please wait while the device registers with Neuro Touch.</p></body></html>");
        
        Serial.println("[PROVISION] Received credentials for: " + newSSID);
        
        // Temporarily connect to check internet & register MAC
        WiFi.begin(newSSID.c_str(), newPass.c_str());
        
        unsigned long startAttempt = millis();
        bool connected = false;
        while (millis() - startAttempt < WIFI_CONNECT_TIMEOUT_MS) {
            if (WiFi.status() == WL_CONNECTED) {
                connected = true;
                break;
            }
            delay(500);
            Serial.print(".");
        }
        
        if (connected) {
            Serial.println("\n[PROVISION] Connected to Wi-Fi. Registering MAC...");
            
            HTTPClient http;
            String url = String(BACKEND_HOST) + String(BACKEND_PROVISION_PATH);
            http.begin(wifiClient, url);
            http.addHeader("Content-Type", "application/json");
            http.setTimeout(HTTP_TIMEOUT_MS);
            
            StaticJsonDocument<128> reqDoc;
            reqDoc["mac_address"] = getMacAddressClean();
            String reqBody;
            serializeJson(reqDoc, reqBody);
            
            int httpCode = http.POST(reqBody);
            Serial.printf("[PROVISION] HTTP POST code: %d\n", httpCode);
            
            if (httpCode == 200 || httpCode == 201) {
                String payload = http.getString();
                StaticJsonDocument<256> resDoc;
                DeserializationError error = deserializeJson(resDoc, payload);
                
                if (!error && resDoc.containsKey("device_id")) {
                    String devId = resDoc["device_id"].as<String>();
                    Serial.println("[PROVISION] Success! Device ID: " + devId);
                    
                    saveCredentials(newSSID, newPass, devId);
                    
                    delay(1000);
                    ESP.restart(); // Restart into normal mode
                } else {
                    Serial.println("[PROVISION] Error parsing backend response.");
                }
            } else {
                Serial.println("[PROVISION] Backend rejected MAC or unreachable.");
            }
            http.end();
        } else {
            Serial.println("\n[PROVISION] Failed to connect to Wi-Fi with provided credentials.");
        }
        
        // If we reach here, something failed. Revert to AP mode by restarting.
        ESP.restart();
    }
}

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n\n═════════════════════════════════════════════════");
    Serial.println("   Neuro Temp Monitor (MAX31856 + 2x PZEM)       ");
    Serial.println("═════════════════════════════════════════════════");

    // Initialize EEPROM & Load Config
    loadCredentials();
    
    // Check if user is forcing a reset (hold BOOT button or touch pin logic can go here)
    // For now, if not provisioned, enter AP mode.

    if (!isProvisioned) {
        Serial.println("[SYS] No credentials. Starting SoftAP Provisioning Mode.");
        WiFi.mode(WIFI_AP);
        
        IPAddress ip(AP_IP_ADDR);
        IPAddress gateway(AP_GATEWAY);
        IPAddress subnet(AP_SUBNET);
        WiFi.softAPConfig(ip, gateway, subnet);
        WiFi.softAP(AP_SSID, AP_PASSWORD, AP_CHANNEL);
        
        Serial.print("[SYS] AP IP Address: ");
        Serial.println(WiFi.softAPIP());
        
        server.on("/", HTTP_GET, handleRoot);
        server.on("/save", HTTP_POST, handleSave);
        server.begin();
        Serial.println("[SYS] HTTP Server started for Captive Portal.");
    } else {
        Serial.println("[SYS] Booting in Station Mode.");
        Serial.println("[SYS] SSID: " + savedSSID);
        Serial.println("[SYS] Device ID: " + savedDeviceId);
        
        WiFi.mode(WIFI_STA);
        WiFi.begin(savedSSID.c_str(), savedPassword.c_str());

        mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
        
        // Initialize Sensors
        if (!maxthermo.begin()) {
            Serial.println("[ERROR] Could not initialize MAX31856. Check wiring!");
        } else {
            maxthermo.setThermocoupleType(MAX31856_TCTYPE_K);
            Serial.println("[SENSOR] MAX31856 initialized. Type K Thermocouple set.");
        }
    }
}

// ─── Main Loop ────────────────────────────────────────────────────────────────
void loop() {
    if (!isProvisioned) {
        // Handle AP portal requests
        server.handleClient();
        return;
    }

    // Normal Station Mode Operations
    if (WiFi.status() != WL_CONNECTED) {
        Serial.print("[WiFi] Reconnecting");
        while (WiFi.status() != WL_CONNECTED) {
            delay(500);
            Serial.print(".");
        }
        Serial.println("\n[WiFi] Reconnected!");
    }

    if (!mqttClient.connected()) {
        Serial.print("[MQTT] Attempting connection...");
        String clientId = savedDeviceId + "-" + String(random(0xffff), HEX);
        if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASS)) {
            Serial.println(" Connected!");
            String statusTopic = "nt/v1/" + savedDeviceId + "/stat/status";
            mqttClient.publish(statusTopic.c_str(), "online", true);
        } else {
            Serial.print(" Failed, rc=");
            Serial.print(mqttClient.state());
            Serial.println(" Try again in 5s");
            delay(5000);
            return;
        }
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

        Serial.printf("[SENSOR] Temp: %.2fC | CJ: %.2fC\n", thermocouple, coldJunction);
        Serial.printf("[FAN] Fan1: %.2fA | Fan2: %.2fA\n", currentFan1, currentFan2);

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
