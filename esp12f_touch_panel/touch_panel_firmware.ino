  /**
   * ═══════════════════════════════════════════════════════════════
   * Rollin Lift Touch Panel — ESP12F SoftAP Provisioning Firmware
   * ═══════════════════════════════════════════════════════════════
   *
   * Panel variants:  6 | 7 | 8
   * AP Mode SSID:    Rollin_Lift_Panel_N  (N = PANEL_NUMBER below)
   * AP IP Address:   192.168.0.4
   * Config Endpoint: POST http://192.168.0.4/config
   *
   * Workflow:
   *   1. On boot, if no Wi-Fi credentials saved → start SoftAP mode
   *   2. Phone connects to "Rollin_Lift_Panel_N" hotspot
   *   3. Flutter app POSTs {"ssid":"...","password":"...","device_id":"..."}
   *   4. Device saves to EEPROM, connects to home Wi-Fi
   *   5. On success → GETs http://[backend]/api/v1/provision/mac-confirm?mac=XX:XX:XX
   *   6. Blue LED steady = provisioned & online
   *
   * Hardware:
   *   - ESP12F (ESP8266 module)
   *   - LED on GPIO2 (blue LED, active LOW)
   *   - 6/7/8 touch relay outputs on GPIO4, GPIO5, GPIO12, GPIO13, GPIO14, GPIO16
   *     (and GPIO0, GPIO15 for panels 7 & 8)
   *
   * Libraries required (install via Arduino Library Manager):
   *   - ESP8266WiFi        (built-in with ESP8266 board package)
   *   - ESP8266WebServer   (built-in with ESP8266 board package)
   *   - ESP8266HTTPClient  (built-in with ESP8266 board package)
   *   - ArduinoJson        v6.x
   *   - EEPROM             (built-in)
   *
   * Arduino Board Settings:
   *   - Board: NodeMCU 1.0 (ESP-12E Module) or Generic ESP8266 Module
   *   - Flash Size: 4MB (FS:1MB OTA:~1019KB)
   *   - Upload Speed: 115200
   */

  #include <Arduino.h>
  #include <ESP8266WiFi.h>
  #include <ESP8266WebServer.h>
  #include <ESP8266HTTPClient.h>
  #include <WiFiClient.h>
  #include <ArduinoJson.h>
  #include <EEPROM.h>

  // ─── Configuration ────────────────────────────────────────────────────────────

  // ⚠️ Change this to 6, 7, or 8 before flashing each panel variant
  #define PANEL_NUMBER 8

  // Stringify helpers — needed to turn PANEL_NUMBER (an int macro) into a string
  #define STRINGIFY(x) #x
  #define TOSTRING(x)  STRINGIFY(x)

  // Backend server (the Go API) — update to your server's public IP/domain
  #define BACKEND_HOST           "http://129.121.12.144:8082"
  #define BACKEND_PROVISION_PATH "/api/v1/provision/mac-confirm"

  // AP Credentials — SSID suffix matches panel number (e.g. Rollin_Lift_Panel_8)
  #define AP_SSID     "Rollin_Lift_Panel_" TOSTRING(PANEL_NUMBER)
  #define AP_PASSWORD ""           // Open hotspot (no password)
  #define AP_CHANNEL 6
  #define AP_IP_ADDR 192, 168, 0, 4
  #define AP_GATEWAY 192, 168, 0, 1
  #define AP_SUBNET  255, 255, 255, 0

  // GPIO pins
  #define LED_PIN 2   // Blue LED (active LOW on ESP12F)

  // EEPROM layout
  #define EEPROM_SIZE  256
  #define SSID_ADDR    0    // 64 bytes for SSID
  #define PASS_ADDR    64   // 128 bytes for password
  #define DEVID_ADDR   192  // 32 bytes for device ID
  #define VALID_FLAG   240  // 1 byte: 0xAB = valid credentials stored

  // Wi-Fi timeouts
  #define WIFI_CONNECT_TIMEOUT_MS  30000
  #define HTTP_TIMEOUT_MS          8000

  // ─── Globals ──────────────────────────────────────────────────────────────────

  ESP8266WebServer server(80);
  WiFiClient       wifiClient;

  String savedSSID     = "";
  String savedPassword = "";
  String savedDeviceId = "";
  bool   isProvisioned = false;

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
    Serial.println("[EEPROM] Loaded — SSID: " + savedSSID);
    return true;
  }

  void clearCredentials() {
    EEPROM.begin(EEPROM_SIZE);
    EEPROM.write(VALID_FLAG, 0x00);
    EEPROM.commit();
    EEPROM.end();
    Serial.println("[EEPROM] Credentials cleared.");
  }

  // ─── LED Helpers ─────────────────────────────────────────────────────────────

  void ledOn()  { digitalWrite(LED_PIN, LOW); }   // Active LOW
  void ledOff() { digitalWrite(LED_PIN, HIGH); }

  void blinkLed(int times, int delayMs = 200) {
    for (int i = 0; i < times; i++) {
      ledOn();
      delay(delayMs);
      ledOff();
      delay(delayMs);
    }
  }

  // ─── AP Mode HTTP Handlers ────────────────────────────────────────────────────

  /**
   * GET /
   * Returns device info as JSON (used for health check).
   */
  void handleRoot() {
    String mac = WiFi.softAPmacAddress();
    mac.replace(":", "");

    StaticJsonDocument<256> doc;
    doc["device"]      = "Rollin_Lift_Panel";
    doc["panel"]       = PANEL_NUMBER;
    doc["mac_address"] = WiFi.softAPmacAddress();
    doc["firmware"]    = "1.0.0";
    doc["status"]      = "awaiting_config";

    String body;
    serializeJson(doc, body);

    server.send(200, "application/json", body);
  }

  /**
   * POST /config
   * Receives Wi-Fi credentials from the Flutter app.
   * Body: { "ssid": "...", "password": "...", "device_id": "nt-XXXXXXXX" }
   */
  void handleConfig() {
    if (!server.hasArg("plain")) {
      server.send(400, "application/json", "{\"error\":\"No body\"}");
      return;
    }

    String body = server.arg("plain");
    Serial.println("[HTTP] POST /config: " + body);

    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, body);
    if (err) {
      server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
      return;
    }

    const char* ssid     = doc["ssid"]      | "";
    const char* password = doc["password"]  | "";
    const char* deviceId = doc["device_id"] | "";

    if (strlen(ssid) == 0) {
      server.send(400, "application/json", "{\"error\":\"ssid is required\"}");
      return;
    }

    // Acknowledge immediately — we will connect asynchronously
    server.send(200, "application/json", "{\"success\":true,\"message\":\"Credentials received, connecting...\"}");

    // Allow the HTTP response to flush
    delay(100);
    server.handleClient();

    // Save to EEPROM and connect
    saveCredentials(String(ssid), String(password), String(deviceId));
    connectToWiFi(String(ssid), String(password));
  }

  /**
   * POST /reset
   * Clears saved credentials and reboots into AP mode.
   */
  void handleReset() {
    server.send(200, "application/json", "{\"success\":true,\"message\":\"Resetting device...\"}");
    delay(500);
    clearCredentials();
    ESP.restart();
  }

  // ─── Wi-Fi Station Connection ─────────────────────────────────────────────────

  void connectToWiFi(const String& ssid, const String& password) {
    Serial.println("[WiFi] Connecting to: " + ssid);

    blinkLed(3, 100);  // Quick blink = attempting

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), password.c_str());

    unsigned long startMs = millis();
    while (WiFi.status() != WL_CONNECTED) {
      if (millis() - startMs > WIFI_CONNECT_TIMEOUT_MS) {
        Serial.println("[WiFi] Connection TIMEOUT. Reverting to AP mode.");
        blinkLed(10, 80);  // Fast blinks = failed
        startAPMode();
        return;
      }
      delay(500);
      Serial.print(".");
    }

    Serial.println("\n[WiFi] Connected!");
    Serial.println("  IP:  " + WiFi.localIP().toString());
    Serial.println("  MAC: " + WiFi.macAddress());

    isProvisioned = true;
    ledOn();  // Steady blue = connected

    // Report MAC address to backend
    reportMacToBackend();
  }

  // ─── Report MAC to Backend ────────────────────────────────────────────────────

  void reportMacToBackend() {
    String mac = WiFi.macAddress();
    String deviceId = savedDeviceId;

    // Build URL
    String url = String(BACKEND_HOST) + String(BACKEND_PROVISION_PATH) +
                 "?mac=" + mac +
                 "&device_id=" + deviceId;

    Serial.println("[HTTP] Reporting MAC to backend: " + url);

    HTTPClient http;
    http.begin(wifiClient, url);
    http.setTimeout(HTTP_TIMEOUT_MS);

    int httpCode = http.GET();
    if (httpCode == HTTP_CODE_OK) {
      String resp = http.getString();
      Serial.println("[HTTP] Backend response: " + resp);
      blinkLed(5, 300);  // 5 slow blinks = success
      ledOn();
    } else {
      Serial.println("[HTTP] Backend error: " + String(httpCode));
      // Will retry on next boot
    }
    http.end();
  }

  // ─── AP Mode Setup ────────────────────────────────────────────────────────────

  void startAPMode() {
    Serial.println("[AP] Starting SoftAP...");
    Serial.println("[AP] SSID: " AP_SSID);

    WiFi.mode(WIFI_AP);

    IPAddress apIP(AP_IP_ADDR);
    IPAddress gateway(AP_GATEWAY);
    IPAddress subnet(AP_SUBNET);
    WiFi.softAPConfig(apIP, gateway, subnet);
    WiFi.softAP(AP_SSID, AP_PASSWORD, AP_CHANNEL);

    Serial.println("[AP] IP: " + WiFi.softAPIP().toString());

    // Register HTTP endpoints
    server.on("/",       HTTP_GET,  handleRoot);
    server.on("/config", HTTP_POST, handleConfig);
    server.on("/reset",  HTTP_POST, handleReset);
    server.onNotFound([]() {
      server.send(404, "application/json", "{\"error\":\"Not found\"}");
    });
    server.begin();

    Serial.println("[AP] HTTP server started on port 80");

    // Blink slowly to signal AP mode
    blinkLed(2, 500);
  }

  // ─── Setup & Loop ────────────────────────────────────────────────────────────

  void setup() {
    Serial.begin(115200);
    delay(200);
    Serial.println("\n\n=== Rollin Lift Touch Panel " + String(PANEL_NUMBER) + " Booting ===");

    pinMode(LED_PIN, OUTPUT);
    ledOff();

    // Try to load saved credentials
    if (loadCredentials() && savedSSID.length() > 0) {
      Serial.println("[Boot] Saved credentials found — connecting to: " + savedSSID);
      connectToWiFi(savedSSID, savedPassword);
    } else {
      Serial.println("[Boot] No credentials — starting AP mode");
      startAPMode();
    }
  }

  void loop() {
    if (!isProvisioned) {
      server.handleClient();

      // Slow LED pulse in AP mode
      static unsigned long lastBlink = 0;
      if (millis() - lastBlink > 2000) {
        lastBlink = millis();
        blinkLed(1, 150);
      }
    } else {
      // Device is provisioned and online
      // TODO: Handle MQTT messages for switch control here
      delay(100);
    }
  }
