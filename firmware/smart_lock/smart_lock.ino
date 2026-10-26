/*
 * ESP32-C3 Smart RFID Lock
 *
 * Features:
 * - RFID card authentication
 * - WiFi connectivity with device discovery
 * - HTTP API for remote control and monitoring
 * - Entry logging with timestamps
 * - WS2812B LED status indicator
 * - Local operation without WiFi
 * - Automatic switch control (5 second timeout)
 *
 * Pin Configuration:
 * - MFRC522 RFID: SS=7, RST=10, SCK=4, MISO=5, MOSI=6
 * - Switch (relay): GPIO2
 * - WS2812B LED: GPIO3
 *
 * HTTP API:
 * - GET  /info            - Device discovery info (no auth)
 * - GET  /api/status      - Get lock status and logs
 * - POST /api/unlock      - Remotely unlock
 * - POST /api/lock        - Remotely lock
 * - POST /api/led-color   - Set LED color
 * - POST /api/add-card    - Add authorized card
 * - POST /api/remove-card - Remove authorized card
 * - GET  /api/cards       - List authorized cards (masked)
 */

#include <Adafruit_NeoPixel.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <MFRC522.h>
#include <Preferences.h>
#include <SPI.h>
#include <WebServer.h>
#include <WiFi.h>
#include <time.h>

// ==================== HARDWARE PIN DEFINITIONS ====================
#define SS_PIN 7      // SDA
#define RST_PIN 10    // RST
#define SCK_PIN 4     // GPIO4 (A4)
#define MISO_PIN 5    // Default MISO
#define MOSI_PIN 6    // Default MOSI
#define SWITCH_PIN 2  // GPIO2 (A2) - Relay control
#define LED_PIN 3     // GPIO3 (A3) - WS2812B

// ==================== TIMING CONSTANTS ====================
#define SWITCH_ON_TIME 5000         // 5 seconds auto-off
#define RFID_DEBOUNCE_TIME 500      // Prevent multiple reads
#define WIFI_CONNECT_TIMEOUT 10000  // WiFi connection timeout
#define WIFI_RETRY_DELAY 500        // Retry delay
#define LED_BLINK_SPEED 150         // LED blink interval

// ==================== DEVICE CONFIGURATION ====================
#define DEVICE_TYPE "smart_lock"
#define FIRMWARE_VERSION "1.0.0"
#define MAX_LOG_ENTRIES 50  // Maximum entry logs to store
#define MAX_CARDS 10        // Maximum authorized cards

// Generate unique lock ID from MAC address
String LOCK_ID = "";

// Default WiFi credentials (same as lamp)
const char* DEFAULT_SSID = "Your_WiFi_SSID";
const char* DEFAULT_PASSWORD = "Your_WiFi_Password";

// Device authentication password
const char* LOCK_PASSWORD = "your_secure_password";

// ==================== AUTHORIZED CARDS ====================
// Initial authorized cards (stored in NVS)
const String INITIAL_CARDS[] = {"CARD_UID_1", "CARD_UID_2"};
const int NUM_INITIAL_CARDS = 2;

// ==================== GLOBAL OBJECTS ====================
MFRC522 rfid(SS_PIN, RST_PIN);
Adafruit_NeoPixel led(1, LED_PIN, NEO_GRB + NEO_KHZ800);
WebServer server(80);
Preferences preferences;

// ==================== STATE VARIABLES ====================
unsigned long switchOnStartTime = 0;
bool switchActive = false;
bool wifiConnected = false;
String wifiSSID = "";
String wifiPassword = "";
bool timeSynchronized = false;

// Custom LED color (can be changed via API)
uint32_t customIdleColor = 0;
bool useCustomColor = false;

// Entry log structure
struct EntryLog {
    time_t timestamp;  // epoch seconds (UTC)
    String cardUID;
    bool granted;
    String remoteIP;  // Empty if local RFID
};

EntryLog entryLogs[MAX_LOG_ENTRIES];
int logIndex = 0;
int logCount = 0;

// Authorized cards list (stored in NVS)
String authorizedCards[MAX_CARDS];
int numAuthorizedCards = 0;

// ==================== LED COLORS ====================
const uint32_t COLOR_IDLE = 0x000032;             // Dim blue (idle)
const uint32_t COLOR_GRANTED = 0x00FF00;          // Green (access granted)
const uint32_t COLOR_DENIED = 0xFF0000;           // Red (access denied)
const uint32_t COLOR_WIFI_CONNECTING = 0xFFFF00;  // Yellow (WiFi connecting)
const uint32_t COLOR_WIFI_SUCCESS = 0x00FFFF;     // Cyan (WiFi connected)
const uint32_t COLOR_WIFI_FAILED = 0xFF00FF;      // Magenta (WiFi failed)
const uint32_t COLOR_OFF = 0x000000;              // Off

// ==================== FUNCTION DECLARATIONS ====================
void setupWiFi();
void setupHTTPServer();
void setupRFID();
void loadAuthorizedCards();
void saveAuthorizedCards();
void handleRFID();
void grantAccess(String cardUID, String remoteIP = "");
void denyAccess(String cardUID);
void addEntryLog(String cardUID, bool granted, String remoteIP = "");
void setLEDColor(uint32_t color);
void blinkLED(uint32_t color, int times, int delayMs);
String getUptime();
String formatISOTime(time_t ts);
time_t getCurrentTimestamp();
void syncTimeIfNeeded();
String getCardLabel(const String& uid);
void clearEntryLogs();
bool validateAuth();
void sendJSONResponse(int code, const JsonDocument& doc);
void sendErrorResponse(int code, const char* message);

// HTTP Handlers
void handleInfo();
void handleStatus();
void handleUnlock();
void handleLock();
void handleSetLEDColor();
void handleAddCard();
void handleRemoveCard();
void handleListCards();
void handleClearLogs();
void handleExportLogsCSV();
void handleExportLogsPDF();

// ==================== SETUP ====================
void setup() {
    Serial.begin(115200);
    Serial.println("\n\n===================================");
    Serial.println("ESP32-C3 Smart RFID Lock");
    Serial.println("===================================");

    // Generate unique ID from MAC
    uint8_t mac[6];
    WiFi.macAddress(mac);
    LOCK_ID = String(mac[3], HEX) + String(mac[4], HEX) + String(mac[5], HEX);
    LOCK_ID.toUpperCase();
    Serial.print("Lock ID: ");
    Serial.println(LOCK_ID);

    // Initialize switch pin
    pinMode(SWITCH_PIN, OUTPUT);
    digitalWrite(SWITCH_PIN, LOW);

    // Initialize LED
    led.begin();
    led.setBrightness(100);
    setLEDColor(COLOR_IDLE);

    // Initialize NVS for persistent storage
    preferences.begin("smart-lock", false);

    // Load WiFi credentials from NVS
    wifiSSID = preferences.getString("wifi_ssid", DEFAULT_SSID);
    wifiPassword = preferences.getString("wifi_pass", DEFAULT_PASSWORD);

    // Load authorized cards
    loadAuthorizedCards();

    // Initialize RFID
    setupRFID();

    // Setup WiFi (non-blocking, will continue if fails)
    setupWiFi();

    Serial.println("\n===================================");
    Serial.println("Smart Lock Ready!");
    Serial.println("===================================");
    Serial.println("Scan your RFID card/tag...\n");
}

// ==================== MAIN LOOP ====================
void loop() {
    // Handle WiFi and HTTP server (if connected)
    if (wifiConnected) {
        server.handleClient();
    }

    // Handle switch timing (auto turn off after 5 seconds)
    if (switchActive && (millis() - switchOnStartTime >= SWITCH_ON_TIME)) {
        digitalWrite(SWITCH_PIN, LOW);
        switchActive = false;

        // Return to idle color
        if (useCustomColor && customIdleColor != 0) {
            setLEDColor(customIdleColor);
        } else {
            setLEDColor(COLOR_IDLE);
        }

        Serial.println("Switch turned OFF automatically");
    }

    // Handle RFID scanning
    handleRFID();

    delay(10);  // Small delay for stability
}

// ==================== RFID INITIALIZATION ====================
void setupRFID() {
    Serial.println("Initializing RFID reader...");

    // Initialize SPI with custom pins
    SPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, SS_PIN);

    // Initialize MFRC522
    rfid.PCD_Init();
    rfid.PCD_DumpVersionToSerial();

    Serial.println("RFID reader initialized");
    Serial.println("Authorized Cards:");
    for (int i = 0; i < numAuthorizedCards; i++) {
        Serial.print("  ");
        Serial.print(i + 1);
        Serial.print(". ");
        Serial.println(authorizedCards[i]);
    }
}

// ==================== WIFI SETUP ====================
void setupWiFi() {
    Serial.println("\nConnecting to WiFi...");
    Serial.print("SSID: ");
    Serial.println(wifiSSID);

    // Show connecting status on LED
    blinkLED(COLOR_WIFI_CONNECTING, 2, LED_BLINK_SPEED);

    WiFi.mode(WIFI_STA);
    WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED &&
           (millis() - startTime) < WIFI_CONNECT_TIMEOUT) {
        delay(WIFI_RETRY_DELAY);
        Serial.print(".");
    }

    if (WiFi.status() == WL_CONNECTED) {
        wifiConnected = true;
        Serial.println("\n✓ WiFi Connected!");
        Serial.print("IP Address: ");
        Serial.println(WiFi.localIP());
        Serial.print("MAC Address: ");
        Serial.println(WiFi.macAddress());

        // Show success - blink cyan 3 times
        blinkLED(COLOR_WIFI_SUCCESS, 3, LED_BLINK_SPEED);

        // Setup mDNS for device discovery
        String hostname = String("smartlock-") + LOCK_ID;
        hostname.toLowerCase();

        if (MDNS.begin(hostname.c_str())) {
            Serial.print("mDNS responder started: ");
            Serial.print(hostname);
            Serial.println(".local");

            // Add HTTP service
            MDNS.addService("http", "tcp", 80);

            // Add IoT lock discovery service
            MDNS.addService("iot-lock", "tcp", 80);
            MDNS.addServiceTxt("iot-lock", "tcp", "id", LOCK_ID.c_str());
            MDNS.addServiceTxt("iot-lock", "tcp", "name", "Smart Lock");
            MDNS.addServiceTxt("iot-lock", "tcp", "type", DEVICE_TYPE);
            MDNS.addServiceTxt("iot-lock", "tcp", "version", FIRMWARE_VERSION);

            // Add generic IoT device service
            MDNS.addService("iot-device", "tcp", 80);
            MDNS.addServiceTxt("iot-device", "tcp", "id", LOCK_ID.c_str());
            MDNS.addServiceTxt("iot-device", "tcp", "type", DEVICE_TYPE);

            Serial.println("mDNS services registered");
        }

        // Setup HTTP server
        setupHTTPServer();

        // Sync time from NTP
        syncTimeIfNeeded();

    } else {
        wifiConnected = false;
        Serial.println("\n✗ WiFi Connection Failed");
        Serial.println("Operating in LOCAL MODE (RFID only)");

        // Show failure - blink magenta 3 times
        blinkLED(COLOR_WIFI_FAILED, 3, LED_BLINK_SPEED);
    }

    // Return to idle color
    setLEDColor(COLOR_IDLE);
}

// ==================== HTTP SERVER SETUP ====================
void setupHTTPServer() {
    // Device info (no auth required for discovery)
    server.on("/info", HTTP_GET, handleInfo);
    server.on("/api/info", HTTP_GET, handleInfo);

    // Lock control (requires auth)
    server.on("/api/status", HTTP_GET, handleStatus);
    server.on("/api/unlock", HTTP_POST, handleUnlock);
    server.on("/api/lock", HTTP_POST, handleLock);
    server.on("/api/led-color", HTTP_POST, handleSetLEDColor);
    server.on("/api/logs/clear", HTTP_POST, handleClearLogs);
    server.on("/api/logs/csv", HTTP_GET, handleExportLogsCSV);
    server.on("/api/logs/pdf", HTTP_GET, handleExportLogsPDF);

    // Card management (requires auth)
    server.on("/api/add-card", HTTP_POST, handleAddCard);
    server.on("/api/remove-card", HTTP_POST, handleRemoveCard);
    server.on("/api/cards", HTTP_GET, handleListCards);

    // CORS headers for all responses
    server.enableCORS(true);

    server.begin();
    Serial.println("HTTP server started on port 80");
}

// ==================== RFID CARD HANDLING ====================
void handleRFID() {
    // Look for new cards
    if (!rfid.PICC_IsNewCardPresent()) {
        return;
    }

    // Select one of the cards
    if (!rfid.PICC_ReadCardSerial()) {
        return;
    }

    // Card detected - read UID
    String scannedUID = "";
    for (byte i = 0; i < rfid.uid.size; i++) {
        scannedUID += String(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
        scannedUID += String(rfid.uid.uidByte[i], HEX);
    }
    scannedUID.toUpperCase();

    Serial.println("\n--- Card Detected ---");
    Serial.print("UID: ");
    Serial.println(scannedUID);

    // Check if card is authorized
    bool authorized = false;
    for (int i = 0; i < numAuthorizedCards; i++) {
        if (scannedUID == authorizedCards[i]) {
            authorized = true;
            break;
        }
    }

    if (authorized) {
        Serial.println("✓ ACCESS GRANTED!");
        grantAccess(scannedUID);
    } else {
        Serial.println("✗ ACCESS DENIED!");
        denyAccess(scannedUID);
    }

    Serial.println("--------------------\n");

    // Halt PICC
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();

    delay(RFID_DEBOUNCE_TIME);
}

// ==================== ACCESS CONTROL ====================
void grantAccess(String cardUID, String remoteIP) {
    // Turn on switch
    digitalWrite(SWITCH_PIN, HIGH);
    switchActive = true;
    switchOnStartTime = millis();

    // Blink green LED 3 times quickly
    for (int i = 0; i < 3; i++) {
        setLEDColor(COLOR_GRANTED);
        delay(LED_BLINK_SPEED);
        setLEDColor(COLOR_OFF);
        delay(LED_BLINK_SPEED);
    }

    // Keep green solid while switch is on
    setLEDColor(COLOR_GRANTED);

    // Log entry
    addEntryLog(cardUID, true, remoteIP);

    if (remoteIP.length() > 0) {
        Serial.print("Remote unlock from: ");
        Serial.println(remoteIP);
    }
    Serial.println("Switch turned ON for 5 seconds");
}

void denyAccess(String cardUID) {
    // Blink red LED 5 times rapidly
    for (int i = 0; i < 5; i++) {
        setLEDColor(COLOR_DENIED);
        delay(100);
        setLEDColor(COLOR_OFF);
        delay(100);
    }

    // Keep red for 2 seconds
    setLEDColor(COLOR_DENIED);
    delay(2000);

    // Return to idle color
    if (useCustomColor && customIdleColor != 0) {
        setLEDColor(customIdleColor);
    } else {
        setLEDColor(COLOR_IDLE);
    }

    // Log entry
    addEntryLog(cardUID, false, "");
}

// ==================== ENTRY LOGGING ====================
void addEntryLog(String cardUID, bool granted, String remoteIP) {
    entryLogs[logIndex].timestamp = getCurrentTimestamp();
    entryLogs[logIndex].cardUID = cardUID;
    entryLogs[logIndex].granted = granted;
    entryLogs[logIndex].remoteIP = remoteIP;

    logIndex = (logIndex + 1) % MAX_LOG_ENTRIES;
    if (logCount < MAX_LOG_ENTRIES) {
        logCount++;
    }

    Serial.print("Entry logged: ");
    Serial.print(cardUID);
    Serial.print(" - ");
    Serial.println(granted ? "GRANTED" : "DENIED");
}

// ==================== LED CONTROL ====================
void setLEDColor(uint32_t color) {
    led.setPixelColor(0, color);
    led.show();
}

void blinkLED(uint32_t color, int times, int delayMs) {
    for (int i = 0; i < times; i++) {
        setLEDColor(color);
        delay(delayMs);
        setLEDColor(COLOR_OFF);
        delay(delayMs);
    }
}

// ==================== CARD MANAGEMENT ====================
void loadAuthorizedCards() {
    numAuthorizedCards = preferences.getInt("num_cards", 0);

    if (numAuthorizedCards == 0) {
        // First time - load initial cards
        numAuthorizedCards = NUM_INITIAL_CARDS;
        for (int i = 0; i < NUM_INITIAL_CARDS; i++) {
            authorizedCards[i] = INITIAL_CARDS[i];
        }
        saveAuthorizedCards();
        Serial.println("Initialized with default authorized cards");
    } else {
        // Load from NVS
        for (int i = 0; i < numAuthorizedCards && i < MAX_CARDS; i++) {
            String key = "card_" + String(i);
            authorizedCards[i] = preferences.getString(key.c_str(), "");
        }
        Serial.print("Loaded ");
        Serial.print(numAuthorizedCards);
        Serial.println(" authorized cards from storage");
    }
}

void saveAuthorizedCards() {
    preferences.putInt("num_cards", numAuthorizedCards);
    for (int i = 0; i < numAuthorizedCards; i++) {
        String key = "card_" + String(i);
        preferences.putString(key.c_str(), authorizedCards[i]);
    }
    Serial.println("Authorized cards saved to storage");
}

// ==================== UTILITY FUNCTIONS ====================
String getUptime() {
    unsigned long uptime = millis() / 1000;
    unsigned long days = uptime / 86400;
    uptime %= 86400;
    unsigned long hours = uptime / 3600;
    uptime %= 3600;
    unsigned long minutes = uptime / 60;
    unsigned long seconds = uptime % 60;

    char buffer[32];
    sprintf(buffer, "%lud %02lu:%02lu:%02lu", days, hours, minutes, seconds);
    return String(buffer);
}

// Return current epoch seconds; if NTP not ready, fall back to millis-based
// seconds
time_t getCurrentTimestamp() {
    time_t now = time(nullptr);
    if (now > 1700000000) {  // rough sanity check (>= Nov 2023)
        return now;
    }
    return (millis() / 1000);  // fallback
}

// Sync time using NTP if connected and not yet synced
void syncTimeIfNeeded() {
    if (!wifiConnected) return;
    if (timeSynchronized) return;

    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    Serial.println("Syncing time via NTP...");

    int retries = 0;
    const int maxRetries = 20;
    while (retries < maxRetries) {
        time_t now = time(nullptr);
        if (now > 1700000000) {  // valid epoch
            timeSynchronized = true;
            Serial.print("Time synced: ");
            Serial.println(formatISOTime(now));
            break;
        }
        retries++;
        delay(250);
    }

    if (!timeSynchronized) {
        Serial.println("Time sync failed (will retry later)");
    }
}

String formatISOTime(time_t ts) {
    if (ts <= 0) return "";
    struct tm timeinfo;
    gmtime_r(&ts, &timeinfo);
    char buf[25];
    // 2024-01-01T12:34:56Z
    snprintf(buf, sizeof(buf), "%04d-%02d-%02dT%02d:%02d:%02dZ",
             timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
             timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
    return String(buf);
}

// Known card labels
String getCardLabel(const String& uid) {
    if (uid == "A1653B1D") return "Key chain";
    if (uid == "F9FA8E14") return "Card in the app";
    if (uid == "REMOTE") return "Remote command";
    return "Unknown";
}

void clearEntryLogs() {
    logIndex = 0;
    logCount = 0;
    for (int i = 0; i < MAX_LOG_ENTRIES; i++) {
        entryLogs[i].timestamp = 0;
        entryLogs[i].cardUID = "";
        entryLogs[i].granted = false;
        entryLogs[i].remoteIP = "";
    }
}

bool validateAuth() {
    if (!server.hasHeader("Authorization")) {
        return false;
    }

    String auth = server.header("Authorization");
    return (auth == String("Bearer ") + LOCK_PASSWORD);
}

void sendJSONResponse(int code, const JsonDocument& doc) {
    String output;
    serializeJson(doc, output);
    server.send(code, "application/json", output);
}

void sendErrorResponse(int code, const char* message) {
    StaticJsonDocument<128> doc;
    doc["success"] = false;
    doc["error"] = message;
    sendJSONResponse(code, doc);
}

// ==================== HTTP HANDLERS ====================

// Device info for discovery (no auth required)
void handleInfo() {
    Serial.println("\n=== /info endpoint called ===");
    Serial.print("Client IP: ");
    Serial.println(server.client().remoteIP());

    StaticJsonDocument<512> doc;
    doc["success"] = true;
    doc["id"] = LOCK_ID;
    doc["name"] = "Smart Lock";
    doc["type"] = DEVICE_TYPE;
    doc["version"] = FIRMWARE_VERSION;
    doc["ip"] = WiFi.localIP().toString();
    doc["mac"] = WiFi.macAddress();
    doc["requiresAuth"] = true;

    JsonObject capabilities = doc.createNestedObject("capabilities");
    capabilities["unlock"] = true;
    capabilities["lock"] = true;
    capabilities["ledControl"] = true;
    capabilities["cardManagement"] = true;
    capabilities["entryLogs"] = true;
    capabilities["maxCards"] = MAX_CARDS;
    capabilities["maxLogs"] = MAX_LOG_ENTRIES;

    Serial.println("Sending response:");
    serializeJsonPretty(doc, Serial);
    Serial.println("=== /info response sent ===\n");

    sendJSONResponse(200, doc);
}

// Get lock status and recent entry logs
void handleStatus() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    DynamicJsonDocument doc(2048);
    doc["success"] = true;
    doc["locked"] = !switchActive;
    doc["uptime"] = getUptime();
    doc["wifiConnected"] = wifiConnected;
    doc["numCards"] = numAuthorizedCards;
    doc["logCount"] = logCount;

    // Add entry logs
    JsonArray logs = doc.createNestedArray("logs");
    int startIdx = (logIndex - logCount + MAX_LOG_ENTRIES) % MAX_LOG_ENTRIES;

    for (int i = 0; i < logCount; i++) {
        int idx = (startIdx + i) % MAX_LOG_ENTRIES;
        JsonObject log = logs.createNestedObject();
        log["timestamp"] = entryLogs[idx].timestamp;
        log["isoTime"] = formatISOTime(entryLogs[idx].timestamp);
        log["cardUID"] = entryLogs[idx].cardUID;
        log["label"] = getCardLabel(entryLogs[idx].cardUID);
        log["granted"] = entryLogs[idx].granted;
        if (entryLogs[idx].remoteIP.length() > 0) {
            log["remoteIP"] = entryLogs[idx].remoteIP;
        }
    }

    sendJSONResponse(200, doc);
}

// Remote unlock
void handleUnlock() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    String clientIP = server.client().remoteIP().toString();
    Serial.print("Remote unlock request from: ");
    Serial.println(clientIP);

    grantAccess("REMOTE", clientIP);

    StaticJsonDocument<128> doc;
    doc["success"] = true;
    doc["message"] = "Unlocked for 5 seconds";
    sendJSONResponse(200, doc);
}

// Remote lock (force close)
void handleLock() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    digitalWrite(SWITCH_PIN, LOW);
    switchActive = false;

    // Set to denied color briefly, then idle
    setLEDColor(COLOR_DENIED);
    delay(500);

    if (useCustomColor && customIdleColor != 0) {
        setLEDColor(customIdleColor);
    } else {
        setLEDColor(COLOR_IDLE);
    }

    Serial.println("Remote lock requested - switch forced OFF");

    StaticJsonDocument<128> doc;
    doc["success"] = true;
    doc["message"] = "Locked";
    sendJSONResponse(200, doc);
}

// Set custom LED color
void handleSetLEDColor() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "Missing request body");
        return;
    }

    StaticJsonDocument<256> reqDoc;
    DeserializationError error = deserializeJson(reqDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (reqDoc.containsKey("r") && reqDoc.containsKey("g") &&
        reqDoc.containsKey("b")) {
        int r = reqDoc["r"];
        int g = reqDoc["g"];
        int b = reqDoc["b"];

        customIdleColor = led.Color(r, g, b);
        useCustomColor = true;

        // If not currently in access state, apply immediately
        if (!switchActive) {
            setLEDColor(customIdleColor);
        }

        Serial.print("LED color changed to RGB(");
        Serial.print(r);
        Serial.print(", ");
        Serial.print(g);
        Serial.print(", ");
        Serial.print(b);
        Serial.println(")");

        StaticJsonDocument<128> doc;
        doc["success"] = true;
        doc["message"] = "LED color updated";
        sendJSONResponse(200, doc);
    } else {
        sendErrorResponse(400, "Missing r, g, b parameters");
    }
}

// Add authorized card
void handleAddCard() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "Missing request body");
        return;
    }

    StaticJsonDocument<256> reqDoc;
    DeserializationError error = deserializeJson(reqDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!reqDoc.containsKey("uid")) {
        sendErrorResponse(400, "Missing uid parameter");
        return;
    }

    String newUID = reqDoc["uid"].as<String>();
    newUID.toUpperCase();

    // Check if card already exists
    for (int i = 0; i < numAuthorizedCards; i++) {
        if (authorizedCards[i] == newUID) {
            sendErrorResponse(409, "Card already authorized");
            return;
        }
    }

    // Check if we have space
    if (numAuthorizedCards >= MAX_CARDS) {
        sendErrorResponse(507, "Maximum cards reached");
        return;
    }

    // Add card
    authorizedCards[numAuthorizedCards] = newUID;
    numAuthorizedCards++;
    saveAuthorizedCards();

    Serial.print("New card authorized: ");
    Serial.println(newUID);

    StaticJsonDocument<128> doc;
    doc["success"] = true;
    doc["message"] = "Card added";
    doc["uid"] = newUID;
    sendJSONResponse(200, doc);
}

// Remove authorized card
void handleRemoveCard() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "Missing request body");
        return;
    }

    StaticJsonDocument<256> reqDoc;
    DeserializationError error = deserializeJson(reqDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!reqDoc.containsKey("uid")) {
        sendErrorResponse(400, "Missing uid parameter");
        return;
    }

    String removeUID = reqDoc["uid"].as<String>();
    removeUID.toUpperCase();

    // Find and remove card
    bool found = false;
    for (int i = 0; i < numAuthorizedCards; i++) {
        if (authorizedCards[i] == removeUID) {
            // Shift remaining cards
            for (int j = i; j < numAuthorizedCards - 1; j++) {
                authorizedCards[j] = authorizedCards[j + 1];
            }
            numAuthorizedCards--;
            found = true;
            break;
        }
    }

    if (!found) {
        sendErrorResponse(404, "Card not found");
        return;
    }

    saveAuthorizedCards();

    Serial.print("Card removed: ");
    Serial.println(removeUID);

    StaticJsonDocument<128> doc;
    doc["success"] = true;
    doc["message"] = "Card removed";
    sendJSONResponse(200, doc);
}

// List authorized cards (masked for security)
void handleListCards() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    StaticJsonDocument<512> doc;
    doc["success"] = true;
    doc["count"] = numAuthorizedCards;

    JsonArray cards = doc.createNestedArray("cards");
    for (int i = 0; i < numAuthorizedCards; i++) {
        JsonObject card = cards.createNestedObject();
        card["index"] = i;

        // Mask UID for security (show only last 4 chars)
        String uid = authorizedCards[i];
        if (uid.length() > 4) {
            card["uid"] = "****" + uid.substring(uid.length() - 4);
        } else {
            card["uid"] = uid;
        }
    }

    sendJSONResponse(200, doc);
}

// Clear all entry logs
void handleClearLogs() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    clearEntryLogs();

    StaticJsonDocument<128> doc;
    doc["success"] = true;
    doc["message"] = "Logs cleared";
    sendJSONResponse(200, doc);
}

// Export logs as CSV
void handleExportLogsCSV() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    String csv = "timestamp,isoTime,cardUID,label,granted,remoteIP\n";

    int startIdx = (logIndex - logCount + MAX_LOG_ENTRIES) % MAX_LOG_ENTRIES;
    for (int i = 0; i < logCount; i++) {
        int idx = (startIdx + i) % MAX_LOG_ENTRIES;
        const EntryLog& log = entryLogs[idx];

        csv += String(log.timestamp);
        csv += ",";
        csv += formatISOTime(log.timestamp);
        csv += ",";
        csv += log.cardUID;
        csv += ",";
        csv += getCardLabel(log.cardUID);
        csv += ",";
        csv += log.granted ? "granted" : "denied";
        csv += ",";
        csv += log.remoteIP;
        csv += "\n";
    }

    server.sendHeader("Content-Type", "text/csv");
    server.sendHeader("Content-Disposition",
                      "attachment; filename=lock_logs.csv");
    server.send(200, "text/csv", csv);
}

// Export logs as a minimal PDF (text-based list)
void handleExportLogsPDF() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    // Build a simple text body to embed in PDF
    String body = "Smart Lock Logs\n\n";
    int startIdx = (logIndex - logCount + MAX_LOG_ENTRIES) % MAX_LOG_ENTRIES;
    for (int i = 0; i < logCount; i++) {
        int idx = (startIdx + i) % MAX_LOG_ENTRIES;
        const EntryLog& log = entryLogs[idx];
        body += formatISOTime(log.timestamp);
        body += "  ";
        body += log.cardUID;
        body += " (";
        body += getCardLabel(log.cardUID);
        body += ")  ";
        body += log.granted ? "GRANTED" : "DENIED";
        if (log.remoteIP.length() > 0) {
            body += "  IP:";
            body += log.remoteIP;
        }
        body += "\n";
    }

    // Minimal PDF wrapper (single page, text stream)
    String pdf;
    pdf += "%PDF-1.1\n";
    pdf += "1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n";
    pdf += "2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n";
    pdf +=
        "3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 "
        "R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n";

    // Escape parentheses in body
    String escapedBody = "";
    for (unsigned int i = 0; i < body.length(); i++) {
        char c = body[i];
        if (c == '(' || c == ')') {
            escapedBody += '\\';
        }
        escapedBody += c;
    }

    String stream = "BT /F1 12 Tf 36 756 Td 14 TL (" + escapedBody + ") Tj ET";
    pdf += "4 0 obj<</Length ";
    pdf += String(stream.length());
    pdf += ">>stream\n";
    pdf += stream;
    pdf += "\nendstream endobj\n";
    pdf += "5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n";
    pdf += "xref\n0 6\n0000000000 65535 f \n";
    int offsets[6];
    // For simplicity, do not compute accurate xref offsets; send as binary-less
    // string
    pdf += "trailer<</Size 6/Root 1 0 R>>\nstartxref\n0\n%%EOF";

    server.sendHeader("Content-Type", "application/pdf");
    server.sendHeader("Content-Disposition",
                      "attachment; filename=lock_logs.pdf");
    server.send(200, "application/pdf", pdf);
}

