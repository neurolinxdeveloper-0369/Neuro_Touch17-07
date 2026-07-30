/**
 * ═══════════════════════════════════════════════════════════════
 * Neuro Power Meter — 3-Phase ESP12F Firmware (PZEM-004T v3.0)
 * ═══════════════════════════════════════════════════════════════
 *
 * WIRING (Shared 2-wire Modbus bus):
 *   All 3 PZEMs share the SAME RX (D5/GPIO14) and TX (D6/GPIO12) pins.
 *   Each PZEM must be pre-programmed to a unique Modbus address:
 *     Phase R → address 0x01
 *     Phase Y → address 0x02
 *     Phase B → address 0x03
 *
 * HOW TO SET MODBUS ADDRESS (one PZEM at a time):
 *   Connect only ONE PZEM, flash the address-setter sketch, then repeat for next.
 *
 * Libraries required:
 *   - ESP8266WiFi, ESP8266WebServer, ESP8266HTTPClient (built-in)
 *   - ArduinoJson  v6.x
 *   - PubSubClient (by Nick O'Leary)
 *   - PZEM004Tv30  (by Jakub Mandula)
 *   - SoftwareSerial (built-in)
 *
 * JSON Payload Topics:
 *   nt/v1/{device_id}/stat/telemetry
 *   {
 *     "voltage_r": 230.5,  "voltage_y": 229.8,  "voltage_b": 231.2,   (V, phase-to-neutral)
 *     "v_ry": 399.2,        "v_yb": 397.8,        "v_br": 400.1,        (V, line-to-line)
 *     "current_r": 5.1234, "current_y": 4.9876, "current_b": 5.2341,  (A)
 *     "power_r": 1.178,    "power_y": 1.145,    "power_b": 1.210,     (kW)
 *     "energy_r": 0.0030,  "energy_y": 0.0025,  "energy_b": 0.0035,  (kWh)
 *     "frequency": 49.9,                                               (Hz, from R phase)
 *     "pf": 0.96,                                                       (avg power factor)
 *     "total_power": 3.533,                                             (kW)
 *     "total_energy": 0.0090                                            (kWh)
 *   }
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClient.h>
#include <EEPROM.h>
#include <PubSubClient.h>
#include <PZEM004Tv30.h>
#include <SoftwareSerial.h>
#include <ArduinoJson.h>

// ─── Configuration ────────────────────────────────────────────────────────────

#define AP_SSID     "Three_Phase_1X"
#define AP_PASSWORD ""
#define AP_CHANNEL  6
#define AP_IP_ADDR  192, 168, 0, 4
#define AP_GATEWAY  192, 168, 0, 1
#define AP_SUBNET   255, 255, 255, 0

#define BACKEND_HOST           "http://129.121.120.144:8080"
#define BACKEND_PROVISION_PATH "/api/v1/provision/mac-confirm"
#define MQTT_SERVER            "129.121.120.144"
#define MQTT_PORT              1883
#define MQTT_USER              "admin"
#define MQTT_PASS              "Neurolinx@123"

// ─── GPIO ────────────────────────────────────────────────────────────────────
#define LED_PIN    2    // Blue LED (active LOW on ESP12F)

// Shared 2-wire Modbus bus for all 3 PZEMs
#define PZEM_RX_PIN   12      // D6 / GPIO12
#define PZEM_TX_PIN   14      // D5 / GPIO14

// Modbus addresses (pre-programmed per phase)
#define ADDR_R  0x01
#define ADDR_Y  0x02
#define ADDR_B  0x03

// ─── EEPROM layout ───────────────────────────────────────────────────────────
#define EEPROM_SIZE  256
#define SSID_ADDR    0
#define PASS_ADDR    64
#define DEVID_ADDR   192
#define VALID_FLAG   240

// ─── Intervals ───────────────────────────────────────────────────────────────
#define WIFI_CONNECT_TIMEOUT_MS  30000
#define HTTP_TIMEOUT_MS          8000
#define POWER_UPDATE_INTERVAL_MS 5000
#define HEARTBEAT_INTERVAL_MS    60000

// ─── Globals ──────────────────────────────────────────────────────────────────
ESP8266WebServer server(80);
WiFiClient       wifiClient;
PubSubClient     mqttClient(wifiClient);

// ─── Hardware Serial (swapped to D7/D8) for PZEM ─────────────────────────────
// The main Serial will be swapped in setup() to use D7 (RX) and D8 (TX)
// for communication with the PZEMs, freeing up normal pins.

// Three PZEM instances on the shared bus — each with its own Modbus address
PZEM004Tv30 pzemR(&Serial, ADDR_R);   // Phase R (Red)
PZEM004Tv30 pzemY(&Serial, ADDR_Y);   // Phase Y (Yellow)
PZEM004Tv30 pzemB(&Serial, ADDR_B);   // Phase B (Blue)
String savedSSID      = "";
String savedPassword  = "";
String savedDeviceId  = "";
bool   isProvisioned  = false;
unsigned long lastPowerUpdate = 0;
unsigned long lastHeartbeat   = 0;

// ─── EEPROM Helpers ──────────────────────────────────────────────────────────
void writeString(int addr, const String& str, int maxLen) {
    int len = min((int)str.length(), maxLen - 1);
    for (int i = 0; i < len; i++) EEPROM.write(addr + i, str[i]);
    EEPROM.write(addr + len, 0);
    EEPROM.commit();
}

String readString(int addr, int maxLen) {
    String result = "";
    for (int i = 0; i < maxLen; i++) {
        char c = EEPROM.read(addr + i);
        if (c == 0) break;
        result += c;
    }
    return result;
}

bool isProvisioning() {
    return EEPROM.read(VALID_FLAG) != 0xAB;
}

void markProvisioned(const String& ssid, const String& pass, const String& deviceId) {
    writeString(SSID_ADDR,  ssid,     64);
    writeString(PASS_ADDR,  pass,     128);
    writeString(DEVID_ADDR, deviceId, 48);
    EEPROM.write(VALID_FLAG, 0xAB);
    EEPROM.commit();
}

// ─── AP Provisioning ─────────────────────────────────────────────────────────
void startAPMode() {
    IPAddress ip(AP_IP_ADDR), gw(AP_GATEWAY), sn(AP_SUBNET);
    WiFi.softAPConfig(ip, gw, sn);
    WiFi.softAP(AP_SSID, AP_PASSWORD, AP_CHANNEL);
    Serial1.println("[AP] Provisioning AP started: " + String(AP_SSID));

    server.on("/provision", HTTP_POST, []() {
        String body = server.arg("plain");
        StaticJsonDocument<256> doc;
        if (deserializeJson(doc, body) != DeserializationError::Ok) {
            server.send(400, "application/json", "{\"success\":false,\"error\":\"Invalid JSON\"}");
            return;
        }
        String ssid     = doc["ssid"]      | "";
        String pass     = doc["password"]  | "";
        String deviceId = doc["device_id"] | "";
        if (ssid.isEmpty() || deviceId.isEmpty()) {
            server.send(400, "application/json", "{\"success\":false,\"error\":\"Missing fields\"}");
            return;
        }
        markProvisioned(ssid, pass, deviceId);
        server.send(200, "application/json", "{\"success\":true}");
        delay(500);
        ESP.restart();
    });
    server.begin();
}

// ─── Backend MAC Confirm ──────────────────────────────────────────────────────
void confirmMACWithBackend() {
    String mac = WiFi.macAddress();
    mac.replace(":", "%3A");
    String url = String(BACKEND_HOST) + BACKEND_PROVISION_PATH
               + "?mac=" + mac + "&device_id=" + savedDeviceId;

    WiFiClient httpClient;
    HTTPClient http;
    http.begin(httpClient, url);
    http.setTimeout(HTTP_TIMEOUT_MS);
    int code = http.GET();
    Serial1.printf("[HTTP] MAC confirm → %d\n", code);
    http.end();
}

// ─── MQTT ────────────────────────────────────────────────────────────────────
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
    // Commands can be handled here if needed
}

void connectMQTT() {
    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
    mqttClient.setCallback(onMqttMessage);
    String clientId = "nt3ph-" + savedDeviceId;
    Serial1.print("[MQTT] Connecting...");
    if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASS)) {
        Serial1.println(" Connected!");
        String cmdTopic = "nt/v1/" + savedDeviceId + "/cmd/#";
        mqttClient.subscribe(cmdTopic.c_str());
    } else {
        Serial1.printf(" Failed (rc=%d)\n", mqttClient.state());
    }
}

void publishHeartbeat() {
    if (!mqttClient.connected()) return;
    String topic = "nt/v1/" + savedDeviceId + "/stat/telemetry";
    StaticJsonDocument<128> doc;
    doc["rssi"]       = WiFi.RSSI();
    doc["fw_version"] = "1.1.0-3ph";
    doc["uptime_sec"] = millis() / 1000;
    String payload;
    serializeJson(doc, payload);
    mqttClient.publish(topic.c_str(), payload.c_str());
    Serial1.printf("[HB] Published heartbeat\n");
}

// ─── Line-to-Line Voltage Calculation ────────────────────────────────────────
// Formula: V_LL = sqrt(Va² + Vb² + Va·Vb)  (for balanced/unbalanced systems)
float lineVoltage(float va, float vb) {
    return sqrt((va * va) + (vb * vb) + (va * vb));
}

// ─── 3-Phase Telemetry Publisher ─────────────────────────────────────────────
void publishPowerData() {
    if (!mqttClient.connected()) return;

    // Read Phase R
    float vR  = pzemR.voltage();
    float iR  = pzemR.current();
    float wR  = pzemR.power();    // Watts
    float eR  = pzemR.energy();   // kWh (library returns kWh)
    float hzR = pzemR.frequency();
    float pfR = pzemR.pf();

    // Read Phase Y
    float vY  = pzemY.voltage();
    float iY  = pzemY.current();
    float wY  = pzemY.power();    // Watts
    float eY  = pzemY.energy();   // kWh
    float hzY = pzemY.frequency();
    float pfY = pzemY.pf();

    // Read Phase B
    float vB  = pzemB.voltage();
    float iB  = pzemB.current();
    float wB  = pzemB.power();    // Watts
    float eB  = pzemB.energy();   // kWh
    float hzB = pzemB.frequency();
    float pfB = pzemB.pf();

    // Validate — skip if all phases are NaN (bus not responding)
    if (isnan(vR) && isnan(vY) && isnan(vB)) {
        Serial1.println("[PZEM] All phases NaN — check wiring/addresses");
        return;
    }

    // ── Power: Watts → kW ────────────────────────────────────────────────────
    float kwR = isnan(wR) ? 0.0f : wR / 1000.0f;
    float kwY = isnan(wY) ? 0.0f : wY / 1000.0f;
    float kwB = isnan(wB) ? 0.0f : wB / 1000.0f;

    // ── Energy: library already returns kWh ──────────────────────────────────
    float kwhR = isnan(eR) ? 0.0f : eR;
    float kwhY = isnan(eY) ? 0.0f : eY;
    float kwhB = isnan(eB) ? 0.0f : eB;

    // ── Totals ────────────────────────────────────────────────────────────────
    float totalKW  = kwR + kwY + kwB;
    float totalKWh = kwhR + kwhY + kwhB;

    // ── Line-to-Line Voltages ─────────────────────────────────────────────────
    float safeVR = isnan(vR) ? 0.0f : vR;
    float safeVY = isnan(vY) ? 0.0f : vY;
    float safeVB = isnan(vB) ? 0.0f : vB;
    float vRY = lineVoltage(safeVR, safeVY);
    float vYB = lineVoltage(safeVY, safeVB);
    float vBR = lineVoltage(safeVB, safeVR);

    // ── Average PF (skip NaN phases) ─────────────────────────────────────────
    float pfSum = 0.0f; int pfCount = 0;
    if (!isnan(pfR)) { pfSum += pfR; pfCount++; }
    if (!isnan(pfY)) { pfSum += pfY; pfCount++; }
    if (!isnan(pfB)) { pfSum += pfB; pfCount++; }
    float avgPf = pfCount > 0 ? pfSum / pfCount : 0.0f;

    // Use R phase frequency (most stable reference)
    float freq = isnan(hzR) ? (isnan(hzY) ? hzB : hzY) : hzR;

    Serial1.println("--- Phase R ---");
    Serial1.print("Voltage: "); Serial1.println(safeVR);
    Serial1.print("Current: "); Serial1.println(isnan(iR)?0:iR);
    Serial1.print("Power: "); Serial1.println(kwR);
    Serial1.print("Energy: "); Serial1.println(kwhR);
    Serial1.print("Frequency: "); Serial1.println(freq);
    
    Serial1.println("--- Phase Y ---");
    Serial1.print("Voltage: "); Serial1.println(safeVY);
    Serial1.print("Current: "); Serial1.println(isnan(iY)?0:iY);
    Serial1.print("Power: "); Serial1.println(kwY);
    Serial1.print("Energy: "); Serial1.println(kwhY);
    
    Serial1.println("--- Phase B ---");
    Serial1.print("Voltage: "); Serial1.println(safeVB);
    Serial1.print("Current: "); Serial1.println(isnan(iB)?0:iB);
    Serial1.print("Power: "); Serial1.println(kwB);
    Serial1.print("Energy: "); Serial1.println(kwhB);
    
    Serial1.println("--- Totals & Lines ---");
    Serial1.print("VRY: "); Serial1.println(vRY);
    Serial1.print("VYB: "); Serial1.println(vYB);
    Serial1.print("VBR: "); Serial1.println(vBR);
    Serial1.print("Total kW: "); Serial1.println(totalKW);
    Serial1.print("Total kWh: "); Serial1.println(totalKWh);
    Serial1.print("Avg PF: "); Serial1.println(avgPf);

    // ── Build JSON payload ────────────────────────────────────────────────────
    StaticJsonDocument<512> doc;

    // Phase-to-neutral voltages
    if (!isnan(vR)) doc["voltage_r"] = serialized(String(safeVR, 1));
    if (!isnan(vY)) doc["voltage_y"] = serialized(String(safeVY, 1));
    if (!isnan(vB)) doc["voltage_b"] = serialized(String(safeVB, 1));

    // Line-to-line voltages
    doc["v_ry"] = serialized(String(vRY, 1));
    doc["v_yb"] = serialized(String(vYB, 1));
    doc["v_br"] = serialized(String(vBR, 1));

    // Phase currents
    if (!isnan(iR)) doc["current_r"] = serialized(String(iR, 4));
    if (!isnan(iY)) doc["current_y"] = serialized(String(iY, 4));
    if (!isnan(iB)) doc["current_b"] = serialized(String(iB, 4));

    // Phase power (kW)
    doc["power_r"] = serialized(String(kwR, 4));
    doc["power_y"] = serialized(String(kwY, 4));
    doc["power_b"] = serialized(String(kwB, 4));

    // Phase energy (kWh)
    doc["energy_r"] = serialized(String(kwhR, 4));
    doc["energy_y"] = serialized(String(kwhY, 4));
    doc["energy_b"] = serialized(String(kwhB, 4));

    // Shared values
    if (!isnan(freq)) doc["frequency"] = serialized(String(freq, 1));
    doc["pf"]           = serialized(String(avgPf, 2));
    doc["total_power"]  = serialized(String(totalKW,  4));
    doc["total_energy"] = serialized(String(totalKWh, 4));

    String topic = "nt/v1/" + savedDeviceId + "/stat/telemetry";
    String payload;
    serializeJson(doc, payload);
    mqttClient.publish(topic.c_str(), payload.c_str());
    Serial1.println("[MQTT] Published 3-phase telemetry: " + payload);
}

// ─── WiFi Connection ─────────────────────────────────────────────────────────
bool connectWiFi(const String& ssid, const String& pass) {
    WiFi.begin(ssid.c_str(), pass.c_str());
    Serial1.print("[WiFi] Connecting to " + ssid);
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_CONNECT_TIMEOUT_MS) {
        delay(500); Serial1.print(".");
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial1.println("\n[WiFi] Connected! IP: " + WiFi.localIP().toString());
        return true;
    }
    Serial1.println("\n[WiFi] Failed.");
    return false;
}

// ─── Setup ───────────────────────────────────────────────────────────────────
void setup() {
    // 1. Initialize PZEM Hardware Serial and swap it to D7(RX) and D8(TX)
    Serial.begin(9600);
    Serial.swap();

    // 2. Initialize Serial1 for debug output (on D4/GPIO2)
    Serial1.begin(115200);

    EEPROM.begin(EEPROM_SIZE);
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH); // OFF initially

    // Give PZEMs time to boot
    delay(1000);

    Serial1.println("\n[BOOT] Neuro 3-Phase Power Meter v1.1.0");

    if (isProvisioning()) {
        Serial1.println("[BOOT] Not provisioned — starting AP mode");
        startAPMode();
        return;
    }

    savedSSID     = readString(SSID_ADDR,  64);
    savedPassword = readString(PASS_ADDR,  128);
    savedDeviceId = readString(DEVID_ADDR, 48);
    isProvisioned = true;
    Serial1.println("[BOOT] Device ID: " + savedDeviceId);

    WiFi.mode(WIFI_STA);
    if (!connectWiFi(savedSSID, savedPassword)) {
        Serial1.println("[BOOT] WiFi failed — restarting in AP mode");
        EEPROM.write(VALID_FLAG, 0xFF);
        EEPROM.commit();
        ESP.restart();
        return;
    }

    digitalWrite(LED_PIN, LOW); // LED ON = connected

    confirmMACWithBackend();
    connectMQTT();
    publishHeartbeat();
    lastHeartbeat = millis();
}

// ─── Loop ────────────────────────────────────────────────────────────────────
void loop() {
    if (!isProvisioned) {
        server.handleClient();
        return;
    }

    // Maintain MQTT
    if (!mqttClient.connected()) {
        Serial1.println("[MQTT] Reconnecting...");
        connectMQTT();
    }
    mqttClient.loop();

    // Publish 3-phase telemetry
    if (millis() - lastPowerUpdate > POWER_UPDATE_INTERVAL_MS) {
        lastPowerUpdate = millis();
        publishPowerData();
    }

    // Heartbeat
    if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL_MS) {
        lastHeartbeat = millis();
        publishHeartbeat();
    }
}
