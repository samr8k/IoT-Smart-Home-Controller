/*
 * ESP32-C3 Mini WS2812B Smart Lamp Firmware
 * Version: 1.1.0
 *
 * Hardware Configuration:
 * - ESP32-C3 Mini
 * - WS2812B LED Strip: 21 LEDs on GPIO 6
 * - External Touch Sensor: Pin A3 (digital output)
 *
 * LED Layout: SPIRAL PATTERN (starting from corner, spiraling to center)
 *
 *   Outer Spiral (16 LEDs, 4 per side):
 *   Index:  0  1  2  3  (Top side, left to right)
 *   Index:  4  5  6  7  (Right side, top to bottom)
 *   Index:  8  9 10 11  (Bottom side, right to left)
 *   Index: 12 13 14 15  (Left side, bottom to top)
 *
 *   Inner Spiral (4 LEDs):
 *   Index: 16 17 18 19  (Continues spiral inward)
 *
 *   Center (1 LED):
 *   Index: 20           (Center LED)
 *
 *   Visual Layout:
 *       0   1   2   3
 *    15 [16  17]  4
 *    14 [19  18]  5
 *    13           6
 *       12 11 10  9   8   7
 *              ^20 (center)
 *
 * Features:
 * - 11 Built-in lighting patterns (spiral-optimized)
 * - External touch sensor pattern cycling
 * - WiFi connectivity with reconfiguration
 * - REST API for remote control
 * - OTA (Over-The-Air) updates
 * - Secure token-based authentication
 * - mDNS discovery (_iot-lamp._tcp)
 *
 * API Endpoints:
 * - GET  /              - API documentation
 * - POST /api/auth      - Authenticate and get token
 * - GET  /api/status    - Get lamp status (requires auth)
 * - POST /api/power     - Turn lamp on/off
 * - POST /api/pattern   - Set lighting pattern
 * - POST /api/brightness - Set brightness (0-255 or 0-100%)
 * - POST /api/color     - Set custom RGB color
 * - POST /api/colorwheel - Set color via HSV
 * - GET  /api/patterns  - Get list of available patterns
 * - POST /api/wifi      - Configure WiFi credentials
 * - GET  /api/wifi/scan - Scan available networks
 */

#include <ArduinoJson.h>
#include <ArduinoOTA.h>
#include <ESPmDNS.h>
#include <FastLED.h>
#include <MPU6050_light.h>
#include <Preferences.h>
#include <WebServer.h>
#include <WiFi.h>
#include <Wire.h>

// ==================== HARDWARE CONFIGURATION ====================
// ESP32-C3 Mini Pin Configuration
#define LED_PIN 6  // GPIO 6 for WS2812B data line
#define NUM_LEDS 21
#define TOUCH_PIN \
    A3  // A3 for external touch sensor (digital HIGH when touched)
#define LED_TYPE WS2812B
#define COLOR_ORDER GRB

// MPU6050 Configuration
#define MPU_SDA 8  // I2C SDA pin for ESP32-C3
#define MPU_SCL 9  // I2C SCL pin for ESP32-C3

// MPU6050 Calibration offsets (from your measurements)
// Upside down: Pitch ~5, Roll ~44, Gyro: -112, -177, 620
// Right side 90deg: Pitch ~-3.3, Roll ~111.5
#define GYRO_X_OFFSET -112
#define GYRO_Y_OFFSET -177
#define GYRO_Z_OFFSET 620
#define ACC_X_OFFSET 0.05f
#define ACC_Y_OFFSET -0.40f
#define ACC_Z_OFFSET 0.59f

// Timing constants for non-blocking animations
#define ANIMATION_FRAME_MS 16            // 60 FPS target
#define MAIN_LOOP_DELAY_MS 10            // Main loop cycle delay
#define WIFI_RETRY_DELAY_MS 500          // WiFi connection retry delay
#define WIFI_SUCCESS_INDICATION_MS 1000  // Success LED display time
#define ERROR_BLINK_ON_MS 300            // Error indication blink duration
#define ERROR_BLINK_OFF_MS 200           // Error indication pause duration
#define SHAKE_FLASH_STAGE_MS 30  // Shake animation flash duration per stage

// Gyro thresholds for gesture detection
// NOTE: thresholds tuned for responsiveness on typical handheld shakes
#define SHAKE_THRESHOLD \
    0.6f  // Acceleration deviation (g) to consider a shake (was 2.5)
#define TILT_THRESHOLD 12.0f     // Degrees for tilt detection (more sensitive)
#define FLIP_THRESHOLD 120.0f    // Degrees for flip/upside down
#define SHAKE_COUNT_THRESHOLD 2  // Number of shakes to trigger (was 3)
#define GESTURE_COOLDOWN 150  // ms between gesture triggers (faster reaction)

// Firmware info
#define FIRMWARE_VERSION "1.1.0"
#define DEVICE_TYPE "smart_lamp"

// LED Layout indices - SPIRAL PATTERN
// Outer spiral: 16 LEDs (indices 0-15), 4 LEDs per side
#define OUTER_SPIRAL_START 0
#define OUTER_SPIRAL_END 15
#define OUTER_SPIRAL_COUNT 16

// Outer spiral sides (4 LEDs each)
#define OUTER_TOP_START 0  // LEDs 0-3: Top side (left to right)
#define OUTER_TOP_END 3
#define OUTER_RIGHT_START 4  // LEDs 4-7: Right side (top to bottom)
#define OUTER_RIGHT_END 7
#define OUTER_BOTTOM_START 8  // LEDs 8-11: Bottom side (right to left)
#define OUTER_BOTTOM_END 11
#define OUTER_LEFT_START 12  // LEDs 12-15: Left side (bottom to top)
#define OUTER_LEFT_END 15

// Inner spiral: 4 LEDs (indices 16-19)
#define INNER_SPIRAL_START 16
#define INNER_SPIRAL_END 19
#define INNER_SPIRAL_COUNT 4

// Center LED
#define CENTER_LED 20

// ==================== NETWORK CONFIGURATION ====================
// Default WiFi credentials
const char* DEFAULT_SSID = "Your_WiFi_SSID";
const char* DEFAULT_PASSWORD = "Your_WiFi_Password";

// Unique lamp authentication password (change this for each lamp!)
const char* LAMP_PASSWORD = "your_secure_password";
const char* LAMP_ID = "SmartLamp001";

// ==================== GLOBAL VARIABLES ====================
CRGB leds[NUM_LEDS];
WebServer server(80);
Preferences preferences;
MPU6050 mpu(Wire);

// Lamp state
struct LampState {
    bool isOn;
    uint8_t brightness;
    uint8_t currentPattern;
    uint8_t customRed;
    uint8_t customGreen;
    uint8_t customBlue;
    uint8_t readingWarmth;  // Reading light warmth level (0-100)
    uint16_t customHue;
    uint8_t customSaturation;
    String wifiSSID;
    String wifiPassword;
    bool gyroEnabled;     // Gyro mode enabled
    uint8_t gyroPattern;  // Current gyro-triggered pattern
} lampState;

// MPU6050 state
struct GyroState {
    float pitch;
    float roll;
    float accX, accY, accZ;     // Acceleration values
    float gyroX, gyroY, gyroZ;  // Gyroscope values
    bool isShaking;
    bool isTilted;
    bool isFlipped;
    int shakeCount;
    unsigned long lastShakeTime;
    unsigned long lastGestureTime;
    String currentGesture;
    uint8_t tiltDirection;  // 0=none, 1=left, 2=right, 3=forward, 4=back
} gyroState;

// Calibration data for MPU6050 tilt alignment
struct CalibrationData {
    bool valid;
    float pitchOffset;  // zero reference
    float rollOffset;   // zero reference
    float pitchScale;   // scale to map measured tilt to real degrees
    float rollScale;    // scale to map measured tilt to real degrees
} calibration = {false, 0.0f, 0.0f, 1.0f, 1.0f};

// Capture points during guided calibration
struct CalibrationCapture {
    bool centerSet;
    bool leftSet;
    bool rightSet;
    bool frontSet;
    bool backSet;
    float centerPitch;
    float centerRoll;
    float leftRoll;
    float rightRoll;
    float frontPitch;
    float backPitch;
} calCapture = {false, false, false, false, false, 0, 0, 0, 0, 0, 0};

// Pattern names
const char* patternNames[] = {
    "Night Reading",      // 0 - Warm yellow for reading
    "Blue Oceanic",       // 1
    "Rainbow Spiral",     // 2 - optimized for spiral layout
    "Fire Effect",        // 3
    "Starry Night",       // 4
    "Breathing White",    // 5
    "Color Cycle",        // 6
    "Spiral Chase",       // 7 - spiral animation
    "Sunset Gradient",    // 8
    "Pulse From Center",  // 9 - radiates from center
    "Snowflake",          // 10 - Cool white twinkle
    "Night Light",        // 11 - Dim warm amber
    "Candle Flicker",     // 12 - Realistic candle
    "Aurora Borealis",    // 13 - Northern lights
    "Ocean Waves",        // 14 - Relaxing ocean waves
    "Sunset Fade",        // 15 - Evening sunset fade
    "Meteor Shower",      // 16 - Dynamic meteors
    "Lightning Storm",    // 17 - Dramatic lightning
    "Ripple",             // 18 - Circular waves from center
    "Kaleidoscope",       // 19 - Symmetrical patterns
    "DNA Helix",          // 20 - Two intertwined spirals
    "Forest Breeze",      // 21 - Green tones movement
    "Firefly Glow",       // 22 - Firefly effect
    "Dreamy Clouds",      // 23 - Soft cloud movement
    "Lava Lamp",          // 24 - Slow warm blobs
    "Custom Color"        // 25
};
const uint8_t NUM_PATTERNS = 26;

// Gyro pattern names (triggered by gestures)
const char* gyroPatternNames[] = {
    "Fluid Tilt",       // 0 - Water-like fluid movement with tilt
    "Gyro Wave",        // 1 - LEDs wave in tilt direction
    "Shake Sparkle",    // 2 - Dramatic sparkle bursts when shaking
    "Flip Toggle",      // 3 - Flip lamp to toggle on/off
    "Motion Rainbow",   // 4 - Rainbow follows motion
    "Tilt Brightness",  // 5 - Brightness changes with tilt
    "Shake Random",     // 6 - Dramatic flash and color change on shake
    "Gyro Fire",        // 7 - Fire intensity based on motion
    "Gyro Rainbow",     // 8 - Color based on tilt direction
    "Shake Color"       // 9 - Randomizes color on shake
};
const uint8_t NUM_GYRO_PATTERNS = 10;

// Touch sensor debouncing
unsigned long lastTouchTime = 0;
const unsigned long TOUCH_DEBOUNCE = 300;
bool lastTouchState = false;

// Animation timing
unsigned long lastAnimationUpdate = 0;
uint8_t animationStep = 0;
uint16_t hueOffset = 0;

// Authentication tokens (simple session management)
String currentAuthToken = "";
unsigned long tokenExpiry = 0;
const unsigned long TOKEN_LIFETIME = 3600000;  // 1 hour

// MPU6050 timing
unsigned long lastMpuUpdate = 0;
const unsigned long MPU_UPDATE_INTERVAL = 20;  // 50Hz update rate
bool mpuInitialized = false;

// ==================== FUNCTION DECLARATIONS ====================
void setupWiFi();
void setupWebServer();
void setupOTA();
void setupMPU6050();
void handleTouch();
void updateLEDs();
void updateMPU6050();
void processGyroGestures();
void saveState();
void loadState();

// Pattern functions
void patternYellowNight();
void patternBlueOceanic();
void patternRainbowSpiral();
void patternFireEffect();
void patternStarryNight();
void patternBreathingWhite();
void patternColorCycle();
void patternSpiralChase();
void patternSunsetGradient();
void patternPulseFromCenter();
void patternSnowflake();
void patternNightLight();
void patternCandleFlicker();
void patternAuroraBorealis();
void patternOceanWaves();
void patternSunsetFade();
void patternMeteorShower();
void patternLightningStorm();
void patternRipple();
void patternKaleidoscope();
void patternDNAHelix();
void patternForestBreeze();
void patternFireflyGlow();
void patternDreamyClouds();
void patternLavaLamp();
void patternCustomColor();

// Gyro pattern functions
void gyroPatternTiltColor();
void gyroPatternWave();
void gyroPatternShakeSparkle();
void gyroPatternFlipToggle();
void gyroPatternMotionRainbow();
void gyroPatternTiltBrightness();
void gyroPatternShakeRandom();
void gyroPatternGyroFire();
void gyroPatternGyroRainbow();
void gyroPatternShakeColor();
void updateGyroPattern();

// API handlers
void handleRoot();
void handleAuth();
void handleStatus();
void handleGetPatterns();
void handleSetPattern();
void handleSetPatternConfig();
void handleGetPatternConfig();
void handleSetBrightness();
void handleSetReadingWarmth();
void handleSetPower();
void handleSetCustomColor();
void handleSetColorWheel();
void handleSetWiFi();
void handleScanWiFi();
void handleNotFound();
void handleCORS();
void handleSetGyro();
void handleGetGyroStatus();
void handleGyroCalibration();
void handleInfo();

// Utility functions
String generateToken();
bool validateAuth();
void sendJSONResponse(int code, JsonDocument& doc);
void sendErrorResponse(int code, const char* message);
void sendSuccessResponse(const char* message);
void loadCalibrationData();
void saveCalibrationData();
void resetCalibrationCapture();
void computeCalibration();

// ==================== SETUP ====================
void setup() {
    Serial.begin(115200);
    Serial.println("\n\n=== ESP32-C3 Mini Smart Lamp Starting ===");
    Serial.print("Firmware Version: ");
    Serial.println(FIRMWARE_VERSION);

    // Initialize LED strip
    FastLED.addLeds<LED_TYPE, LED_PIN, COLOR_ORDER>(leds, NUM_LEDS)
        .setCorrection(TypicalLEDStrip);
    FastLED.setBrightness(128);
    FastLED.clear();
    FastLED.show();

    // Initialize touch sensor pin
    pinMode(TOUCH_PIN, INPUT);

    // Load saved state from preferences
    loadState();

    // Load gyro calibration data
    loadCalibrationData();
    resetCalibrationCapture();

    // Apply saved brightness
    FastLED.setBrightness(lampState.brightness);

    // Setup MPU6050
    setupMPU6050();

    // Setup WiFi
    setupWiFi();

    // Setup mDNS with IoT lamp service discovery
    String hostname = String("smartlamp-") +
                      String(LAMP_ID).substring(String(LAMP_ID).length() - 3);
    hostname.toLowerCase();

    if (MDNS.begin(hostname.c_str())) {
        Serial.print("mDNS responder started: ");
        Serial.print(hostname);
        Serial.println(".local");

        // Add HTTP service for general discovery
        MDNS.addService("http", "tcp", 80);

        // Add IoT lamp discovery service (_iot-lamp._tcp)
        MDNS.addService("iot-lamp", "tcp", 80);
        MDNS.addServiceTxt("iot-lamp", "tcp", "id", LAMP_ID);
        MDNS.addServiceTxt("iot-lamp", "tcp", "name", "Smart Lamp");
        MDNS.addServiceTxt("iot-lamp", "tcp", "type", DEVICE_TYPE);
        MDNS.addServiceTxt("iot-lamp", "tcp", "version", FIRMWARE_VERSION);
        MDNS.addServiceTxt("iot-lamp", "tcp", "leds", String(NUM_LEDS).c_str());
        MDNS.addServiceTxt("iot-lamp", "tcp", "password", "true");

        // Also register under generic IoT device service for broader discovery
        MDNS.addService("iot-device", "tcp", 80);
        MDNS.addServiceTxt("iot-device", "tcp", "id", LAMP_ID);
        MDNS.addServiceTxt("iot-device", "tcp", "type", DEVICE_TYPE);
        MDNS.addServiceTxt("iot-device", "tcp", "version", FIRMWARE_VERSION);

        Serial.println("mDNS services registered:");
        Serial.println("  - _http._tcp");
        Serial.println("  - _iot-lamp._tcp");
        Serial.println("  - _iot-device._tcp");
    } else {
        Serial.println("Error setting up mDNS responder!");
    }

    // Setup OTA
    setupOTA();

    // Setup Web Server
    setupWebServer();

    Serial.println("=== Smart Lamp Ready ===");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Gyro Mode: ");
    Serial.println(lampState.gyroEnabled ? "Enabled" : "Disabled");
    Serial.print("MPU6050: ");
    Serial.println(mpuInitialized ? "Connected" : "Not Found");
}

// ==================== MAIN LOOP ====================
void loop() {
    // Handle OTA updates
    ArduinoOTA.handle();

    // Handle web server requests
    server.handleClient();

    // Handle touch sensor
    handleTouch();

    // Update MPU6050 sensor data
    if (lampState.gyroEnabled && mpuInitialized) {
        updateMPU6050();
    }

    // Update LED animation
    if (lampState.isOn) {
        if (lampState.gyroEnabled && mpuInitialized) {
            updateGyroPattern();
        } else {
            updateLEDs();
        }
    } else {
        FastLED.clear();
        FastLED.show();
    }

    // Small delay for stability
    delay(MAIN_LOOP_DELAY_MS);
}

// ==================== WIFI SETUP ====================
void setupWiFi() {
    String ssid =
        lampState.wifiSSID.length() > 0 ? lampState.wifiSSID : DEFAULT_SSID;
    String password = lampState.wifiPassword.length() > 0
                          ? lampState.wifiPassword
                          : DEFAULT_PASSWORD;

    Serial.print("Connecting to WiFi: ");
    Serial.println(ssid);

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), password.c_str());

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(WIFI_RETRY_DELAY_MS);
        Serial.print(".");
        attempts++;

        // Show connecting animation
        leds[attempts % NUM_LEDS] = CRGB::Blue;
        FastLED.show();
    }

    FastLED.clear();
    FastLED.show();

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi Connected!");
        Serial.print("IP Address: ");
        Serial.println(WiFi.localIP());

        // Success indication - solid green
        fill_solid(leds, NUM_LEDS, CRGB::Green);
        FastLED.show();
        delay(WIFI_SUCCESS_INDICATION_MS);
        FastLED.clear();
        FastLED.show();
    } else {
        Serial.println("\nWiFi Connection Failed!");
        // Start AP mode for configuration
        WiFi.softAP("SmartLamp_Setup", "setup1234");
        Serial.print("AP IP: ");
        Serial.println(WiFi.softAPIP());

        // Error indication - blink red 2 times
        for (int i = 0; i < 2; i++) {
            fill_solid(leds, NUM_LEDS, CRGB::Red);
            FastLED.show();
            delay(ERROR_BLINK_ON_MS);
            FastLED.clear();
            FastLED.show();
            delay(ERROR_BLINK_OFF_MS);
        }
    }
}

// ==================== OTA SETUP ====================
void setupOTA() {
    ArduinoOTA.setHostname("smartlamp");
    ArduinoOTA.setPassword("ota_update_2024");

    ArduinoOTA.onStart([]() {
        Serial.println("OTA Update Starting...");
        FastLED.clear();
        FastLED.show();
    });

    ArduinoOTA.onEnd([]() {
        Serial.println("\nOTA Update Complete!");
        fill_solid(leds, NUM_LEDS, CRGB::Green);
        FastLED.show();
    });

    ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
        int ledProgress = (progress / (total / NUM_LEDS));
        FastLED.clear();
        for (int i = 0; i <= ledProgress && i < NUM_LEDS; i++) {
            leds[i] = CRGB::Purple;
        }
        FastLED.show();
    });

    ArduinoOTA.onError([](ota_error_t error) {
        Serial.printf("OTA Error[%u]: ", error);
        fill_solid(leds, NUM_LEDS, CRGB::Red);
        FastLED.show();
    });

    ArduinoOTA.begin();
    Serial.println("OTA Ready");
}

// ==================== MPU6050 SETUP ====================
void setupMPU6050() {
    Serial.println("Initializing MPU6050...");

    // Initialize I2C with custom pins for ESP32-C3
    Wire.begin(MPU_SDA, MPU_SCL);

    // Initialize MPU6050
    byte status = mpu.begin();
    if (status != 0) {
        Serial.print("MPU6050 initialization failed with code: ");
        Serial.println(status);
        mpuInitialized = false;
        return;
    }

    Serial.println("MPU6050 connected successfully!");
    Serial.println("Calibrating... Please keep the lamp still.");

    // Quick calibration (gyro only, 1 second)
    delay(WIFI_RETRY_DELAY_MS);   // Reuse 500ms constant for calibration settle
                                  // time
    mpu.calcOffsets(true, true);  // Calculate gyro and accel offsets

    // Apply custom offsets from user's measurements
    // These fine-tune the calibration based on the provided data
    mpu.setGyroOffsets(GYRO_X_OFFSET / 131.0f, GYRO_Y_OFFSET / 131.0f,
                       GYRO_Z_OFFSET / 131.0f);

    mpuInitialized = true;

    // Initialize gyro state
    gyroState.pitch = 0;
    gyroState.roll = 0;
    gyroState.isShaking = false;
    gyroState.isTilted = false;
    gyroState.isFlipped = false;
    gyroState.shakeCount = 0;
    gyroState.lastShakeTime = 0;
    gyroState.lastGestureTime = 0;
    gyroState.currentGesture = "none";
    gyroState.tiltDirection = 0;

    Serial.println("MPU6050 calibration complete!");
    Serial.print("Gyro offsets - X: ");
    Serial.print(mpu.getGyroXoffset());
    Serial.print(" Y: ");
    Serial.print(mpu.getGyroYoffset());
    Serial.print(" Z: ");
    Serial.println(mpu.getGyroZoffset());
}

// ==================== MPU6050 UPDATE ====================
void updateMPU6050() {
    unsigned long currentTime = millis();

    // Update at 50Hz
    if (currentTime - lastMpuUpdate < MPU_UPDATE_INTERVAL) return;
    lastMpuUpdate = currentTime;

    // Update MPU6050 values
    mpu.update();

    // Get angle data and apply calibration
    float rawPitch = mpu.getAngleX();
    float rawRoll = mpu.getAngleY();
    gyroState.pitch =
        (rawPitch - calibration.pitchOffset) * calibration.pitchScale;
    gyroState.roll = (rawRoll - calibration.rollOffset) * calibration.rollScale;

    // Get acceleration data (in g) and apply calibrated offsets
    gyroState.accX = mpu.getAccX() - ACC_X_OFFSET;
    gyroState.accY = mpu.getAccY() - ACC_Y_OFFSET;
    gyroState.accZ = mpu.getAccZ() - ACC_Z_OFFSET;

    // Get gyroscope data (in deg/s)
    gyroState.gyroX = mpu.getGyroX();
    gyroState.gyroY = mpu.getGyroY();
    gyroState.gyroZ = mpu.getGyroZ();

    // Process gestures
    processGyroGestures();
}

// ==================== GESTURE DETECTION ====================
void processGyroGestures() {
    unsigned long currentTime = millis();

    // Calculate total acceleration magnitude
    float accMagnitude =
        sqrt(gyroState.accX * gyroState.accX + gyroState.accY * gyroState.accY +
             gyroState.accZ * gyroState.accZ);

    // Detect shake (sudden acceleration change)
    bool wasShaking = gyroState.isShaking;
    gyroState.isShaking = (abs(accMagnitude - 1.0f) > SHAKE_THRESHOLD);

    if (gyroState.isShaking && !wasShaking) {
        gyroState.shakeCount++;
        gyroState.lastShakeTime = currentTime;
    }

    // Reset shake count after timeout
    if (currentTime - gyroState.lastShakeTime > 1000) {
        gyroState.shakeCount = 0;
    }

    // Detect flip (upside down) - based on user's calibration data
    // When upside down: Roll ~44 degrees
    gyroState.isFlipped = (abs(gyroState.roll) > FLIP_THRESHOLD ||
                           (abs(gyroState.roll) > 30 &&
                            abs(gyroState.roll) < 60 && gyroState.accZ < 0.6f));

    // Detect tilt direction
    gyroState.isTilted = (abs(gyroState.pitch) > TILT_THRESHOLD ||
                          abs(gyroState.roll) > TILT_THRESHOLD);

    // Determine tilt direction
    if (!gyroState.isTilted) {
        gyroState.tiltDirection = 0;  // None
        gyroState.currentGesture = "none";
    } else if (gyroState.roll < -TILT_THRESHOLD) {
        gyroState.tiltDirection = 1;  // Left
        gyroState.currentGesture = "tilt_left";
    } else if (gyroState.roll > TILT_THRESHOLD) {
        gyroState.tiltDirection = 2;  // Right
        gyroState.currentGesture = "tilt_right";
    } else if (gyroState.pitch > TILT_THRESHOLD) {
        gyroState.tiltDirection = 3;  // Forward
        gyroState.currentGesture = "tilt_forward";
    } else if (gyroState.pitch < -TILT_THRESHOLD) {
        gyroState.tiltDirection = 4;  // Back
        gyroState.currentGesture = "tilt_back";
    }

    // Override with shake/flip gestures
    if (gyroState.shakeCount >= SHAKE_COUNT_THRESHOLD) {
        gyroState.currentGesture = "shake";

        // Trigger shake action with cooldown
        if (currentTime - gyroState.lastGestureTime > GESTURE_COOLDOWN) {
            gyroState.lastGestureTime = currentTime;

            // Shake actions based on gyro pattern
            if (lampState.gyroPattern == 6) {  // Shake Random
                // Will be handled in pattern function
            }
        }

        gyroState.shakeCount = 0;  // Reset after triggering
    }

    if (gyroState.isFlipped) {
        gyroState.currentGesture = "flip";
    }

    // Debug: log gesture changes and shake details
    static String _prevGesture = "";
    if (gyroState.currentGesture != _prevGesture) {
        Serial.print("Gesture: ");
        Serial.print(gyroState.currentGesture);
        Serial.print(" | pitch: ");
        Serial.print(gyroState.pitch);
        Serial.print(" roll: ");
        Serial.print(gyroState.roll);
        Serial.print(" accMag: ");
        float accMag = sqrt(gyroState.accX * gyroState.accX +
                            gyroState.accY * gyroState.accY +
                            gyroState.accZ * gyroState.accZ);
        Serial.print(accMag);
        Serial.print(" shakeCount: ");
        Serial.println(gyroState.shakeCount);
        _prevGesture = gyroState.currentGesture;
    }

    if (gyroState.isShaking &&
        abs(accMagnitude - 1.0f) > (SHAKE_THRESHOLD * 1.5f)) {
        // Extra log when a strong instantaneous shake is detected
        Serial.print("Strong shake detected accMag=");
        Serial.println(accMagnitude);
    }
}

// ==================== WEB SERVER SETUP ====================
void setupWebServer() {
    Serial.println("\n=== Setting up Web Server ===");

    // Enable CORS
    server.enableCORS(true);
    Serial.println("CORS enabled");

    // API Endpoints
    server.on("/", HTTP_GET, handleRoot);
    server.on("/info", HTTP_GET, handleInfo);  // Discovery endpoint
    server.on("/api/info", HTTP_GET,
              handleInfo);  // Alternative discovery endpoint
    Serial.println("Registered /info and /api/info endpoints");

    server.on("/api/auth", HTTP_POST, handleAuth);
    server.on("/api/status", HTTP_GET, handleStatus);
    server.on("/api/patterns", HTTP_GET, handleGetPatterns);
    server.on("/api/pattern", HTTP_POST, handleSetPattern);
    server.on("/api/pattern-config", HTTP_POST, handleSetPatternConfig);
    server.on("/api/pattern-config", HTTP_GET, handleGetPatternConfig);
    server.on("/api/brightness", HTTP_POST, handleSetBrightness);
    server.on("/api/reading-warmth", HTTP_POST, handleSetReadingWarmth);
    server.on("/api/power", HTTP_POST, handleSetPower);
    server.on("/api/color", HTTP_POST, handleSetCustomColor);
    server.on("/api/colorwheel", HTTP_POST, handleSetColorWheel);
    server.on("/api/wifi", HTTP_POST, handleSetWiFi);
    server.on("/api/wifi/scan", HTTP_GET, handleScanWiFi);
    server.on("/api/gyro", HTTP_POST, handleSetGyro);
    server.on("/api/gyro", HTTP_GET, handleGetGyroStatus);
    server.on("/api/gyro/pattern", HTTP_POST, handleSetGyro);
    server.on("/api/gyro/calibrate", HTTP_POST, handleGyroCalibration);
    server.on("/api/gyro/calibrate", HTTP_GET, handleGyroCalibration);

    // Handle preflight OPTIONS requests for CORS
    server.on("/api/auth", HTTP_OPTIONS, handleCORS);
    server.on("/api/status", HTTP_OPTIONS, handleCORS);
    server.on("/api/patterns", HTTP_OPTIONS, handleCORS);
    server.on("/api/pattern", HTTP_OPTIONS, handleCORS);
    server.on("/api/pattern-config", HTTP_OPTIONS, handleCORS);
    server.on("/api/brightness", HTTP_OPTIONS, handleCORS);
    server.on("/api/power", HTTP_OPTIONS, handleCORS);
    server.on("/api/color", HTTP_OPTIONS, handleCORS);
    server.on("/api/colorwheel", HTTP_OPTIONS, handleCORS);
    server.on("/api/wifi", HTTP_OPTIONS, handleCORS);
    server.on("/api/wifi/scan", HTTP_OPTIONS, handleCORS);
    server.on("/api/gyro", HTTP_OPTIONS, handleCORS);
    server.on("/api/gyro/pattern", HTTP_OPTIONS, handleCORS);
    server.on("/api/gyro/calibrate", HTTP_OPTIONS, handleCORS);

    server.onNotFound(handleNotFound);

    server.begin();
    Serial.println("HTTP Server started on port 80");
    Serial.print("Access the lamp at: http://");
    Serial.println(WiFi.localIP());
    Serial.println("=== Web Server Ready ===\n");
}

// ==================== TOUCH SENSOR HANDLING ====================
void handleTouch() {
    // Read external touch sensor module (outputs HIGH when touched)
    bool isTouched = digitalRead(TOUCH_PIN) == HIGH;

    if (isTouched && !lastTouchState &&
        (millis() - lastTouchTime > TOUCH_DEBOUNCE)) {
        lastTouchTime = millis();

        // Cycle to next pattern
        lampState.currentPattern =
            (lampState.currentPattern + 1) % NUM_PATTERNS;
        animationStep = 0;
        hueOffset = 0;

        Serial.print("Pattern changed to: ");
        Serial.println(patternNames[lampState.currentPattern]);

        saveState();
    }

    lastTouchState = isTouched;
}

// ==================== GYRO PATTERN UPDATE ====================
void updateGyroPattern() {
    unsigned long currentTime = millis();

    // Update animation at 60fps
    if (currentTime - lastAnimationUpdate < ANIMATION_FRAME_MS) return;
    lastAnimationUpdate = currentTime;

    // Run base pattern
    switch (lampState.gyroPattern) {
        case 0:
            gyroPatternTiltColor();
            break;
        case 1:
            gyroPatternWave();
            break;
        case 2:
            gyroPatternShakeSparkle();
            break;
        case 3:
            gyroPatternFlipToggle();
            break;
        case 4:
            gyroPatternMotionRainbow();
            break;
        case 5:
            gyroPatternTiltBrightness();
            break;
        case 6:
            gyroPatternShakeRandom();
            break;
        case 7:
            gyroPatternGyroFire();
            break;
        case 8:
            gyroPatternGyroRainbow();
            break;
        case 9:
            gyroPatternShakeColor();
            break;
        default:
            gyroPatternTiltColor();
            break;
    }

    // Apply shake overlay effect if currently shaking (except for
    // shake-specific patterns)
    if ((gyroState.isShaking || gyroState.currentGesture == "shake") &&
        lampState.gyroPattern != 9) {  // Don't apply to Shake Color pattern
        applyShakeEffect();
    }

    FastLED.show();
}

// ==================== SHAKE EFFECT OVERLAY ====================
void applyShakeEffect() {
    static uint8_t shakeFrame = 0;
    static unsigned long lastShakeEffect = 0;
    unsigned long currentTime = millis();

    // Update shake effect every 50ms for visible animation
    if (currentTime - lastShakeEffect < 50) return;
    lastShakeEffect = currentTime;
    shakeFrame++;

    // Create dramatic shake visual effects
    for (int i = 0; i < NUM_LEDS; i++) {
        // Random white flashes during shake
        if (random8() < 60) {  // 60/256 chance per LED
            uint8_t flashBrightness = random8(150, 255);
            leds[i] = CRGB(flashBrightness, flashBrightness, flashBrightness);
        }

        // Add pulsing effect to some LEDs
        if ((i + shakeFrame) % 3 == 0) {
            uint8_t pulseBrightness = sin8(shakeFrame * 20 + i * 10);
            if (pulseBrightness > 100) {
                leds[i] = blend(leds[i], CRGB::White, pulseBrightness - 100);
            }
        }

        // Create spark trails
        if (random8() < 20) {                   // 20/256 chance
            uint8_t sparkHue = random8(0, 64);  // White to yellow sparks
            uint8_t sparkBrightness = random8(180, 255);
            leds[i] = CHSV(sparkHue, 50, sparkBrightness);
        }
    }

    // Special center effect during shake
    uint8_t centerPulse = sin8(shakeFrame * 30);
    if (centerPulse > 128) {
        leds[CENTER_LED] = CRGB(255, 255, 255);  // Bright white center
    }

    // Reset shake frame counter to prevent overflow
    if (shakeFrame > 255) shakeFrame = 0;
}

// Gyro Pattern 0: Fluid Tilt - Simulates water in a jar with smooth, reactive
// movement
void gyroPatternTiltColor() {
    static float smoothRoll = 0;
    static float smoothPitch = 0;
    static uint8_t waveOffset = 0;
    unsigned long currentTime = millis();

    // Smooth the sensor readings for fluid motion (like water settling)
    smoothRoll = smoothRoll * 0.8 + gyroState.roll * 0.2;
    smoothPitch = smoothPitch * 0.8 + gyroState.pitch * 0.2;

    // Create base color from tilt (water-like color shifts)
    int baseHue = map(constrain((int)smoothRoll, -60, 60), -60, 60, 160,
                      220);  // Blue to cyan range
    int saturation =
        map(constrain(abs((int)smoothPitch), 0, 45), 0, 45, 180, 255);

    // Add wave animation for fluid-like movement
    waveOffset += 2;  // Slow wave movement

    // Create fluid-like effect across all LEDs
    for (int i = 0; i < NUM_LEDS; i++) {
        // Calculate position-based wave effect (simulating water surface)
        float waveEffect = sin((float)i * 0.5 + waveOffset * 0.01) * 0.3;

        // Add tilt-based brightness variation (darker on "bottom", brighter on
        // "top")
        float tiltEffect =
            map(constrain((int)smoothRoll, -45, 45), -45, 45, -0.3, 0.3);
        float brightness = 200 + waveEffect * 50 + tiltEffect * 30;

        // Add some sparkle for water-like reflection
        if (random8() < 5) {
            brightness = min(255.0f, brightness + 50.0f);
        }

        leds[i] =
            CHSV(baseHue + i * 2, saturation, constrain(brightness, 100, 255));
    }

    // Enhanced center effect with acceleration (water ripples)
    float accelMagnitude =
        sqrt(gyroState.accX * gyroState.accX + gyroState.accY * gyroState.accY +
             gyroState.accZ * gyroState.accZ);

    // Create ripple effect when moving
    if (accelMagnitude > 1.1) {
        uint8_t rippleHue = baseHue + 64 + sin(currentTime * 0.01) * 32;
        leds[CENTER_LED] = CHSV(rippleHue, 255, 255);
    } else {
        // Calm water center
        leds[CENTER_LED] = CHSV(baseHue + 32, saturation - 50, 220);
    }

    // Add momentum trails for fluid feel
    static float lastRoll = 0;
    float rollVelocity = smoothRoll - lastRoll;
    lastRoll = smoothRoll;

    // Create trailing waves based on movement speed
    if (abs(rollVelocity) > 0.5) {
        int trailLED = CENTER_LED + (rollVelocity > 0 ? 1 : -1);
        if (trailLED >= 0 && trailLED < NUM_LEDS) {
            leds[trailLED] = CHSV(baseHue + 96, saturation, 180);
        }
    }
}

// Gyro Pattern 1: Wave - LEDs wave in tilt direction
void gyroPatternWave() {
    fadeToBlackBy(leds, NUM_LEDS, 30);

    // Calculate wave position based on tilt
    int wavePos;
    uint8_t hue;

    if (gyroState.tiltDirection == 1) {  // Left
        wavePos = map(constrain((int)gyroState.roll, -90, 0), -90, 0, 0,
                      OUTER_SPIRAL_COUNT - 1);
        hue = 160;                              // Blue
    } else if (gyroState.tiltDirection == 2) {  // Right
        wavePos = map(constrain((int)gyroState.roll, 0, 90), 0, 90, 0,
                      OUTER_SPIRAL_COUNT - 1);
        hue = 96;                               // Green
    } else if (gyroState.tiltDirection == 3) {  // Forward
        wavePos = map(constrain((int)gyroState.pitch, 0, 90), 0, 90, 0,
                      INNER_SPIRAL_COUNT);
        hue = 32;                               // Orange
    } else if (gyroState.tiltDirection == 4) {  // Back
        wavePos = map(constrain((int)gyroState.pitch, -90, 0), -90, 0, 0,
                      INNER_SPIRAL_COUNT);
        hue = 200;  // Purple
    } else {
        // No tilt - center glow
        leds[CENTER_LED] = CHSV(hueOffset++, 255, 200);
        return;
    }

    // Light up LEDs in wave pattern
    for (int i = 0; i <= wavePos && i < NUM_LEDS; i++) {
        uint8_t brightness = 255 - ((wavePos - i) * 30);
        leds[i] = CHSV(hue, 255, brightness);
    }

    // Center follows wave intensity
    leds[CENTER_LED] = CHSV(hue, 200, 255);
}

// Gyro Pattern 2: Shake Sparkle - Sparkle effect intensity based on shaking
void gyroPatternShakeSparkle() {
    fadeToBlackBy(leds, NUM_LEDS, 25);  // Slightly faster fade

    // Base calm state with subtle animation
    if (!gyroState.isShaking && gyroState.shakeCount == 0) {
        // Gentle breathing with color
        uint8_t breath = sin8(animationStep);
        animationStep += 1;
        uint8_t hue = sin8(animationStep / 4) / 4;  // Very slow color shift
        fill_solid(leds, NUM_LEDS, CHSV(hue, 50, breath / 6));
        leds[CENTER_LED] = CHSV(hue + 64, 100, breath / 3);
    } else {
        // Enhanced sparkle effects based on shake intensity
        int baseSparkleCount =
            gyroState.isShaking ? 12 : min(gyroState.shakeCount * 3, 15);

        // Add extra sparks during active shaking
        if (gyroState.isShaking) {
            baseSparkleCount += 8;
        }

        // Create multiple spark types
        for (int i = 0; i < baseSparkleCount; i++) {
            int pos = random8(NUM_LEDS);

            // Mix of different spark colors and effects
            if (i % 3 == 0) {
                // Bright white sparks
                leds[pos] = CRGB::White;
            } else if (i % 3 == 1) {
                // Colored sparks
                leds[pos] = CHSV(random8(), 150, 255);
            } else {
                // Gold/yellow sparks
                leds[pos] = CHSV(32 + random8(32), 200, 255);
            }
        }

        // Pulsing center effect
        uint8_t pulse = sin8(animationStep * 4);
        animationStep += 3;  // Faster pulsing
        leds[CENTER_LED] = CHSV(0, 0, pulse);

        // Add radial burst effect during shake
        if (gyroState.isShaking) {
            for (int i = 0; i < 3; i++) {
                int burstPos = random8(NUM_LEDS);
                leds[burstPos] = CRGB(255, 255, 255);  // Pure white bursts
            }
        }
    }
}

// Gyro Pattern 3: Flip Toggle - Color changes when flipped
static bool lastFlipState = false;
static uint8_t flipColorIndex = 0;
void gyroPatternFlipToggle() {
    // Detect flip transition
    if (gyroState.isFlipped && !lastFlipState) {
        flipColorIndex = (flipColorIndex + 1) % 6;
    }
    lastFlipState = gyroState.isFlipped;

    // Color palette
    CRGB colors[] = {CRGB::Red,    CRGB::Green, CRGB::Blue,
                     CRGB::Yellow, CRGB::Cyan,  CRGB::Magenta};
    CRGB currentColor = colors[flipColorIndex];

    if (gyroState.isFlipped) {
        // Inverted/flipped state - pulsing
        uint8_t pulse = sin8(animationStep * 2);
        animationStep++;
        fill_solid(leds, NUM_LEDS, currentColor);
        fadeToBlackBy(leds, NUM_LEDS, 255 - pulse);
    } else {
        // Normal state - solid
        fill_solid(leds, NUM_LEDS, currentColor);
    }
}

// Gyro Pattern 4: Motion Rainbow - Rainbow follows motion direction
void gyroPatternMotionRainbow() {
    // Use gyro rotation to drive hue
    hueOffset +=
        (int)(gyroState.gyroZ / 50);  // Rotation around Z affects color

    // Use pitch/roll to shift rainbow position
    int posOffset = (int)(gyroState.pitch + gyroState.roll) / 10;

    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = CHSV((hueOffset + (i * 12) + posOffset) % 256, 255, 255);
    }

    // Motion blur effect
    if (abs(gyroState.gyroX) > 50 || abs(gyroState.gyroY) > 50 ||
        abs(gyroState.gyroZ) > 50) {
        blur1d(leds, NUM_LEDS, 128);
    }
}

// Gyro Pattern 5: Tilt Brightness - Brightness changes with tilt angle
void gyroPatternTiltBrightness() {
    // Calculate brightness from tilt (more tilt = dimmer in that direction)
    int brightness = map(
        constrain(abs((int)gyroState.roll) + abs((int)gyroState.pitch), 0, 180),
        0, 180, 255, 30);

    // Use current hue from rotation
    hueOffset += (int)(gyroState.gyroZ / 100);

    fill_solid(leds, NUM_LEDS, CHSV(hueOffset, 255, brightness));

    // Show tilt direction with brighter LEDs
    if (gyroState.tiltDirection == 1) {  // Left - light left side
        for (int i = OUTER_LEFT_START; i <= OUTER_LEFT_END; i++) {
            leds[i] = CHSV(hueOffset, 255, 255);
        }
    } else if (gyroState.tiltDirection == 2) {  // Right
        for (int i = OUTER_RIGHT_START; i <= OUTER_RIGHT_END; i++) {
            leds[i] = CHSV(hueOffset, 255, 255);
        }
    } else if (gyroState.tiltDirection == 3) {  // Forward
        for (int i = OUTER_TOP_START; i <= OUTER_TOP_END; i++) {
            leds[i] = CHSV(hueOffset, 255, 255);
        }
    } else if (gyroState.tiltDirection == 4) {  // Back
        for (int i = OUTER_BOTTOM_START; i <= OUTER_BOTTOM_END; i++) {
            leds[i] = CHSV(hueOffset, 255, 255);
        }
    }
}

// Gyro Pattern 6: Shake Random - Shake to get random color
static CRGB randomColor = CRGB::White;
static unsigned long lastShakeColorChange = 0;
static uint8_t shakeFlashStage = 0;
static unsigned long shakeFlashTimer = 0;
void gyroPatternShakeRandom() {
    unsigned long currentTime = millis();

    // Enhanced color change on shake with dramatic flash (non-blocking)
    if (gyroState.shakeCount >= SHAKE_COUNT_THRESHOLD &&
        currentTime - lastShakeColorChange > GESTURE_COOLDOWN &&
        shakeFlashStage == 0) {
        randomColor = CHSV(random8(), 255, 255);
        lastShakeColorChange = currentTime;
        shakeFlashStage = 1;  // Start flash sequence
        shakeFlashTimer = currentTime;
    }

    // Non-blocking multi-stage flash effect
    if (shakeFlashStage > 0) {
        unsigned long elapsed = currentTime - shakeFlashTimer;

        if (shakeFlashStage == 1 && elapsed < SHAKE_FLASH_STAGE_MS) {
            // Stage 1: White flash
            fill_solid(leds, NUM_LEDS, CRGB::White);
            return;
        } else if (shakeFlashStage == 1) {
            shakeFlashStage = 2;
            shakeFlashTimer = currentTime;
        }

        if (shakeFlashStage == 2 && elapsed < SHAKE_FLASH_STAGE_MS) {
            // Stage 2: Color flash
            fill_solid(leds, NUM_LEDS, randomColor);
            return;
        } else if (shakeFlashStage == 2) {
            shakeFlashStage = 3;
            shakeFlashTimer = currentTime;
        }

        if (shakeFlashStage == 3 && elapsed < SHAKE_FLASH_STAGE_MS) {
            // Stage 3: White flash
            fill_solid(leds, NUM_LEDS, CRGB::White);
            return;
        } else if (shakeFlashStage == 3) {
            shakeFlashStage = 0;  // End flash sequence
        }
    }

    // Display current color with enhanced breathing and sparkle
    uint8_t breath = sin8(animationStep);
    animationStep += 3;  // Faster breathing

    fill_solid(leds, NUM_LEDS, randomColor);
    fadeToBlackBy(leds, NUM_LEDS, 255 - (180 + breath / 8));

    // Brighter center with sparkle
    leds[CENTER_LED] = randomColor;

    // Add random sparkles even when not shaking
    if (random8() < 30) {  // 30/256 chance
        int sparklePos = random8(NUM_LEDS);
        leds[sparklePos] = CRGB::White;
    }

    // Extra sparkle during shake detection
    if (gyroState.isShaking) {
        for (int i = 0; i < 3; i++) {
            int sparklePos = random8(NUM_LEDS);
            leds[sparklePos] = CHSV(random8(), 100, 255);
        }
    }
}

// Gyro Pattern 7: Gyro Fire - Fire intensity based on motion
void gyroPatternGyroFire() {
    // Calculate motion intensity
    float motionIntensity =
        abs(gyroState.gyroX) + abs(gyroState.gyroY) + abs(gyroState.gyroZ);
    motionIntensity =
        constrain(motionIntensity, 0, 300) / 300.0f;  // Normalize to 0-1

    // Add acceleration intensity
    float accelIntensity =
        abs(gyroState.accX - 1.0f) + abs(gyroState.accY) + abs(gyroState.accZ);
    accelIntensity = constrain(accelIntensity, 0, 3) / 3.0f;

    float totalIntensity = (motionIntensity + accelIntensity) / 2.0f;

    // Cool down rate based on motion (less motion = faster cooldown)
    uint8_t cooldown = 50 - (uint8_t)(totalIntensity * 40);
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i].fadeToBlackBy(cooldown);
    }

    // Spark probability based on motion
    uint8_t sparkChance = 50 + (uint8_t)(totalIntensity * 200);

    // Center is hottest
    if (random8() < sparkChance) {
        uint8_t heat = 200 + (uint8_t)(totalIntensity * 55);
        leds[CENTER_LED] = CRGB(255, random8(heat, 255), random8(50, 150));
    }

    // Inner spiral - orange flames
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        if (random8() < sparkChance * 0.75f) {
            uint8_t orangeVal = 80 + (uint8_t)(totalIntensity * 175);
            leds[i] += CRGB(random8(180, 255), random8(orangeVal, 150), 0);
        }
    }

    // Outer spiral - red edges
    for (int i = OUTER_SPIRAL_START; i <= OUTER_SPIRAL_END; i++) {
        if (random8() < sparkChance * 0.5f) {
            uint8_t redVal = 150 + (uint8_t)(totalIntensity * 70);
            leds[i] += CRGB(random8(redVal, 220), random8(20, 80), 0);
        }
    }
}

// Gyro Pattern 8: Gyro Rainbow - Color based on tilt direction
void gyroPatternGyroRainbow() {
    // Map pitch and roll to hue
    // Pitch: -90 to +90 -> 0 to 180 (half the color wheel)
    // Roll: -180 to +180 -> adds offset

    float normalizedPitch = constrain(gyroState.pitch, -90, 90);
    float normalizedRoll = constrain(gyroState.roll, -180, 180);

    // Calculate base hue from tilt direction
    uint8_t pitchHue = map(normalizedPitch, -90, 90, 0, 128);
    uint8_t rollOffset = map(normalizedRoll, -180, 180, 0, 127);
    uint8_t baseHue = (pitchHue + rollOffset) % 256;

    // Calculate tilt magnitude for saturation
    float tiltMag = sqrt(normalizedPitch * normalizedPitch +
                         normalizedRoll * normalizedRoll);
    uint8_t saturation = map(constrain(tiltMag, 0, 90), 0, 90, 100, 255);

    // Apply rainbow based on tilt
    for (int i = 0; i < NUM_LEDS; i++) {
        // Add slight variation per LED for interest
        uint8_t hue = (baseHue + i * 3) % 256;
        leds[i] = CHSV(hue, saturation, 255);
    }

    // Center shows the "pure" tilt color
    leds[CENTER_LED] = CHSV(baseHue, 255, 255);
}

// Gyro Pattern 9: Shake Color - Randomizes color on shake
static uint8_t shakeColorHue = 0;
static uint8_t shakeColorSat = 255;
static uint8_t shakeColorTransition = 0;
static uint8_t targetShakeHue = 0;

void gyroPatternShakeColor() {
    // Detect shake
    if (gyroState.isShaking) {
        // Pick new random color on shake
        targetShakeHue = random8();
        shakeColorTransition = 255;  // Start transition
    }

    // Smooth transition to target color
    if (shakeColorTransition > 0) {
        shakeColorHue = lerp8by8(shakeColorHue, targetShakeHue, 20);
        shakeColorTransition -= 5;
        if (shakeColorTransition < 5) {
            shakeColorHue = targetShakeHue;
            shakeColorTransition = 0;
        }
    }

    // Fill with current color
    fill_solid(leds, NUM_LEDS, CHSV(shakeColorHue, shakeColorSat, 255));

    // Add subtle breathing effect
    static uint8_t breathPhase = 0;
    breathPhase += 2;
    uint8_t breathVal = sin8(breathPhase);
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i].nscale8(220 + breathVal / 8);
    }

    // Flash effect during shake
    if (gyroState.isShaking) {
        for (int i = 0; i < NUM_LEDS; i++) {
            leds[i] = CRGB(255, 255, 255);  // White flash
        }
    }
}

// ==================== LED UPDATE ====================
void updateLEDs() {
    unsigned long currentTime = millis();

    // Update animation at 60fps
    if (currentTime - lastAnimationUpdate < ANIMATION_FRAME_MS) return;
    lastAnimationUpdate = currentTime;

    switch (lampState.currentPattern) {
        case 0:
            patternYellowNight();
            break;
        case 1:
            patternBlueOceanic();
            break;
        case 2:
            patternRainbowSpiral();
            break;
        case 3:
            patternFireEffect();
            break;
        case 4:
            patternStarryNight();
            break;
        case 5:
            patternBreathingWhite();
            break;
        case 6:
            patternColorCycle();
            break;
        case 7:
            patternSpiralChase();
            break;
        case 8:
            patternSunsetGradient();
            break;
        case 9:
            patternPulseFromCenter();
            break;
        case 10:
            patternSnowflake();
            break;
        case 11:
            patternNightLight();
            break;
        case 12:
            patternCandleFlicker();
            break;
        case 13:
            patternAuroraBorealis();
            break;
        case 14:
            patternOceanWaves();
            break;
        case 15:
            patternSunsetFade();
            break;
        case 16:
            patternMeteorShower();
            break;
        case 17:
            patternLightningStorm();
            break;
        case 18:
            patternRipple();
            break;
        case 19:
            patternKaleidoscope();
            break;
        case 20:
            patternDNAHelix();
            break;
        case 21:
            patternForestBreeze();
            break;
        case 22:
            patternFireflyGlow();
            break;
        case 23:
            patternDreamyClouds();
            break;
        case 24:
            patternLavaLamp();
            break;
        case 25:
            patternCustomColor();
            break;
        default:
            patternYellowNight();
            break;
    }

    FastLED.show();
}

// ==================== LIGHTING PATTERNS ====================

// Night Reading configuration
uint8_t nightReadingWarmth = 50;       // 0=cool white, 100=very warm orange
uint8_t nightReadingYellowness = 70;   // 0=white, 100=saturated yellow
uint8_t nightReadingBrightness = 200;  // Overall brightness

// Pattern 0: Yellow Night Reading Light with adjustable warmth and yellowness
void patternYellowNight() {
    // Map warmth level (0-100) to color temperature
    // Map yellowness (0-100) to saturation level
    uint8_t warmth = nightReadingWarmth;

    // Calculate RGB values based on warmth and yellowness
    // Base: warm white to orange spectrum
    // Warmth 0: Cool white (255, 250, 240)
    // Warmth 50: Warm yellow (255, 200, 80)
    // Warmth 100: Deep orange (255, 120, 20)

    uint8_t red = 255;
    uint8_t green, blue;

    if (warmth < 50) {
        // Cool to warm yellow range
        green = map(warmth, 0, 50, 250, 200);
        blue = map(warmth, 0, 50, 240, 80);
    } else {
        // Warm yellow to orange range
        green = map(warmth, 50, 100, 200, 120);
        blue = map(warmth, 50, 100, 80, 20);
    }

    // Apply yellowness - reduces blue more for saturated yellow
    blue = (blue * (100 - nightReadingYellowness / 2)) / 100;

    // Apply brightness
    uint8_t brightScale = nightReadingBrightness;
    red = (red * brightScale) / 255;
    green = (green * brightScale) / 255;
    blue = (blue * brightScale) / 255;

    CRGB readingColor = CRGB(red, green, blue);

    // Smooth fill with slight warmth gradient from center
    for (int i = 0; i < NUM_LEDS; i++) {
        // Center is slightly warmer
        if (i == CENTER_LED) {
            leds[i] = CRGB(min(255, red + 10), green, max(0, blue - 10));
        } else if (i >= INNER_SPIRAL_START && i <= INNER_SPIRAL_END) {
            leds[i] = CRGB(min(255, red + 5), green, max(0, blue - 5));
        } else {
            leds[i] = readingColor;
        }
    }
}

// Pattern 1: Blue Oceanic Theme (optimized for spiral)
void patternBlueOceanic() {
    hueOffset += 1;

    // Outer spiral - ocean waves flowing around
    for (int i = OUTER_SPIRAL_START; i <= OUTER_SPIRAL_END; i++) {
        uint8_t wave = sin8(i * 25 + hueOffset);
        leds[i] = CHSV(160 + (wave / 20), 255, 120 + (wave / 2));
    }

    // Inner spiral - deeper blue
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        uint8_t wave = sin8(i * 40 + hueOffset * 2);
        leds[i] = CHSV(155, 255, 100 + (wave / 3));
    }

    // Center - bright foam/splash
    uint8_t centerPulse = sin8(hueOffset * 3);
    leds[CENTER_LED] = CHSV(160, 150, 150 + (centerPulse / 3));
}

// Pattern 2: Rainbow Spiral (optimized for spiral layout)
void patternRainbowSpiral() {
    hueOffset += 2;

    // Outer spiral gets rainbow flowing around
    for (int i = OUTER_SPIRAL_START; i <= OUTER_SPIRAL_END; i++) {
        leds[i] = CHSV((hueOffset + (i * 16)) % 256, 255, 255);
    }

    // Inner spiral continues the rainbow
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        uint8_t innerHue = hueOffset + 256 + ((i - INNER_SPIRAL_START) * 32);
        leds[i] = CHSV(innerHue % 256, 255, 255);
    }

    // Center LED pulses with complement color
    leds[CENTER_LED] = CHSV((hueOffset + 128) % 256, 255, 255);
}

// Pattern 3: Fire Effect (spiral - fire emanates from center)
// Fire configuration - calmness controls how wild the fire is
uint8_t fireCalmness = 50;   // 0=wild chaotic fire, 100=calm gentle flames
uint8_t fireIntensity = 80;  // Overall brightness/intensity
uint8_t fireSpread = 50;     // How much fire spreads outward

void patternFireEffect() {
    // Calmness affects fade rate and flicker probability
    // Low calmness = fast flickering, wild movement
    // High calmness = slow, gentle flames
    uint8_t fadeRate = map(fireCalmness, 0, 100, 80, 20);  // Wild fades faster
    uint8_t centerProb =
        map(fireCalmness, 0, 100, 250, 150);  // Core flicker rate
    uint8_t innerProb = map(fireCalmness, 0, 100, 200, 100);  // Inner flicker
    uint8_t outerProb = map(fireCalmness, 0, 100, 150, 50);   // Outer flicker

    // Cool down all LEDs based on calmness
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i].fadeToBlackBy(fadeRate);
    }

    // Center is hottest (white-yellow core)
    if (random8() < centerProb) {
        uint8_t coreWhite = map(fireCalmness, 0, 100, 50, 150);
        uint8_t intensityScale = map(fireIntensity, 0, 100, 100, 255);
        leds[CENTER_LED] = CRGB(
            intensityScale, random8(200 * intensityScale / 255, intensityScale),
            random8(coreWhite * intensityScale / 255,
                    (coreWhite + 50) * intensityScale / 255));
    }

    // Inner spiral - orange flames
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        if (random8() < innerProb) {
            uint8_t flameG = map(fireCalmness, 0, 100, 80, 140);
            uint8_t intensityScale = map(fireIntensity, 0, 100, 100, 200);
            leds[i] += CRGB(
                random8(180 * intensityScale / 200, 255 * intensityScale / 200),
                random8(flameG * intensityScale / 200,
                        (flameG + 40) * intensityScale / 200),
                0);
        }
    }

    // Outer spiral - red flickering edges (spread control)
    uint8_t outerIntensity = map(fireSpread, 0, 100, 50, 150);
    for (int i = OUTER_SPIRAL_START; i <= OUTER_SPIRAL_END; i++) {
        if (random8() < outerProb) {
            leds[i] += CRGB(random8(outerIntensity, outerIntensity + 70),
                            random8(20, 80), 0);
        }
    }

    // Heat diffusion from center outward - smoother for calm fire
    uint8_t blendAmount = map(fireCalmness, 0, 100, 20, 50);
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        leds[i] = blend(leds[i], leds[CENTER_LED], blendAmount);
    }

    // For calm fire, add gentle overall warmth
    if (fireCalmness > 60) {
        for (int i = 0; i < NUM_LEDS; i++) {
            leds[i] += CRGB(10, 3, 0);
        }
    }
}

// Pattern 4: Starry Night (center moon, spiral stars)
uint8_t starrySparkleRate = 50;  // 0-100: how often stars twinkle
uint8_t starryDensity = 50;      // 0-100: number of stars visible

// Pattern 5: Breathing White
uint8_t breathingSpeed = 50;  // 10-100: breathing speed

// Pattern 6: Color Cycle
uint8_t colorCycleSpeed = 10;  // 0-20: cycle speed

// Pattern 9: Pulse From Center
uint8_t pulseSpeed = 75;  // 20-150: pulse speed

// Pattern 12: Candle Flicker
uint8_t candleFlickerRate = 70;  // 0-100: flicker randomness
uint8_t candleMinBright = 100;   // 0-200: minimum brightness

void patternStarryNight() {
    // Dim all LEDs slightly (create twinkling effect)
    fadeToBlackBy(leds, NUM_LEDS, 15);

    // Center LED is the moon (warm white, softly pulsing)
    uint8_t moonPulse = sin8(animationStep / 2);
    animationStep++;
    leds[CENTER_LED] = CRGB(200 + (moonPulse / 5), 200 + (moonPulse / 6),
                            150 + (moonPulse / 4));

    // Base dark blue background for outer and inner spirals
    for (int i = OUTER_SPIRAL_START; i <= OUTER_SPIRAL_END; i++) {
        if (leds[i].r < 5 && leds[i].g < 5 && leds[i].b < 25) {
            leds[i] = CRGB(0, 0, 20);
        }
    }
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        if (leds[i].r < 5 && leds[i].g < 5 && leds[i].b < 35) {
            leds[i] =
                CRGB(0, 0, 30);  // Inner is slightly brighter from moonlight
        }
    }

    // Random twinkling stars on outer spiral (use starrySparkleRate)
    uint8_t outerProb = map(starrySparkleRate, 0, 100, 30, 120);
    if (random8() < outerProb) {
        int pos = random8(OUTER_SPIRAL_START, OUTER_SPIRAL_END + 1);
        leds[pos] = CRGB(255, 255, 255);
    }

    // Occasional star on inner spiral (use starryDensity)
    uint8_t innerProb = map(starryDensity, 0, 100, 10, 60);
    if (random8() < innerProb) {
        int pos = random8(INNER_SPIRAL_START, INNER_SPIRAL_END + 1);
        leds[pos] = CRGB(255, 255, 200);
    }
}

// Pattern 5: Breathing White
void patternBreathingWhite() {
    // Sine wave breathing effect with configurable speed
    uint8_t breath = sin8(animationStep);
    animationStep += map(breathingSpeed, 10, 100, 1,
                         5);  // Use breathingSpeed (10-100 -> 1-5 steps)

    fill_solid(leds, NUM_LEDS, CRGB(breath, breath, breath));
}

// Pattern 6: Color Cycle (smooth transition through all colors)
void patternColorCycle() {
    // Use colorCycleSpeed (1-20) directly as increment
    hueOffset +=
        colorCycleSpeed / 4;  // Divide by 4 to slow it down appropriately
    fill_solid(leds, NUM_LEDS, CHSV(hueOffset, 255, 255));
}

// Pattern 7: Spiral Chase
uint8_t chaseSpeed = 60;       // 10-100: chase speed
uint8_t chaseTrailLength = 3;  // 1-6: trail length

void patternSpiralChase() {
    // Fade all LEDs
    fadeToBlackBy(leds, NUM_LEDS, 40);

    // Calculate position in the spiral (0-20) using chaseSpeed
    uint8_t speedDivisor = map(chaseSpeed, 10, 100, 8, 1);
    uint8_t pos = (animationStep / speedDivisor) % NUM_LEDS;
    animationStep++;

    // Main bright LED
    leds[pos] = CHSV(hueOffset, 255, 255);

    // Trailing LEDs (dimmer) using chaseTrailLength
    for (int i = 1; i <= chaseTrailLength && pos >= i; i++) {
        uint8_t brightness = map(i, 1, chaseTrailLength, 180, 30);
        leds[pos - i] = CHSV(hueOffset, 255, brightness);
    }

    // Slowly shift color
    hueOffset++;
}

// Pattern 8: Sunset Gradient (spiral creates horizon effect)
uint8_t sunsetShimmer = 40;  // 0-100: sparkle intensity
uint8_t sunsetWarmth = 70;   // 0-100: orange to purple gradient shift

void patternSunsetGradient() {
    // Center is the sun (bright yellow-orange)
    leds[CENTER_LED] = CRGB(255, 180, 50);

    // Inner spiral - orange glow around sun
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        leds[i] = CHSV(25, 255, 255);  // Orange
    }

    // Outer spiral - gradient from orange to purple (use sunsetWarmth)
    for (int i = OUTER_SPIRAL_START; i <= OUTER_SPIRAL_END; i++) {
        // Map position using sunsetWarmth (more warmth = more orange, less =
        // more purple)
        uint8_t hueStart = map(sunsetWarmth, 0, 100, 0, 30);   // 0-30
        uint8_t hueEnd = map(sunsetWarmth, 0, 100, 220, 180);  // 220-180
        uint8_t hue =
            map(i, OUTER_SPIRAL_START, OUTER_SPIRAL_END, hueStart, hueEnd);
        leds[i] = CHSV(hue, 255, 220);
    }

    // Shimmer on outer edges using sunsetShimmer
    animationStep++;
    uint8_t shimmerProb = map(sunsetShimmer, 0, 100, 5, 40);
    if (random8() < shimmerProb) {
        int shimmerPos = random8(OUTER_SPIRAL_START, OUTER_SPIRAL_END + 1);
        uint8_t shimmerBright = map(sunsetShimmer, 0, 100, 10, 50);
        leds[shimmerPos] +=
            CRGB(shimmerBright, shimmerBright * 2 / 3, shimmerBright / 3);
    }
}

// Pattern 9: Pulse From Center (radiates outward from center LED)
void patternPulseFromCenter() {
    // Use pulseSpeed (20-150) to control animation speed
    animationStep +=
        map(pulseSpeed, 20, 150, 1, 8);  // Convert to animation step increment
    uint8_t wave = sin8(animationStep);

    // Center LED is brightest
    leds[CENTER_LED] = CHSV(hueOffset, 255, 255);

    // Inner spiral slightly dimmer, delayed phase
    uint8_t innerWave =
        sin8(animationStep - 60);  // Increased delay for slower wave
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        leds[i] = CHSV(hueOffset, 255, innerWave);
    }

    // Outer spiral dimmest, more delayed
    uint8_t outerWave =
        sin8(animationStep - 120);  // Increased delay for slower wave
    for (int i = OUTER_SPIRAL_START; i <= OUTER_SPIRAL_END; i++) {
        leds[i] = CHSV(hueOffset, 255, outerWave);
    }

    // Slowly shift color (less frequent)
    if (animationStep % 10 == 0) hueOffset++;
}

// Pattern 10: Snowflake - Cool white twinkling like snow
uint8_t snowflakeSparkleRate = 60;  // 0-100: how often sparkles appear
uint8_t snowflakeCoolness = 50;     // 0-100: blue tint intensity

void patternSnowflake() {
    // Base cool white/blue using snowflakeCoolness
    uint8_t baseR = map(snowflakeCoolness, 0, 100, 230, 180);
    uint8_t baseG = map(snowflakeCoolness, 0, 100, 240, 200);
    uint8_t baseB = 255;  // Always max blue
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = CRGB(baseR, baseG, baseB);
    }

    // Add random sparkles like snowflakes using snowflakeSparkleRate
    animationStep++;
    uint8_t sparkleProb = map(snowflakeSparkleRate, 0, 100, 10, 80);
    if (random8() < sparkleProb) {
        // Add bright white sparkles
        int numSparkles = map(snowflakeSparkleRate, 0, 100, 1, 6);
        for (int s = 0; s < numSparkles; s++) {
            int pos = random8(NUM_LEDS);
            leds[pos] = CRGB(255, 255, 255);  // Pure white sparkle
        }
    }

    // Fade sparkles
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i].fadeToBlackBy(20);
        // Keep minimum brightness
        if (leds[i].r < 100) leds[i].r = 100;
        if (leds[i].g < 110) leds[i].g = 110;
        if (leds[i].b < 130) leds[i].b = 130;
    }
}

// Pattern 11: Night Light - Dim warm amber for sleeping
uint8_t nightLightDimLevel = 30;       // 0-100: overall brightness
uint8_t nightLightWarmth = 80;         // 0-100: color warmth
uint8_t nightLightBreatheAmount = 20;  // 0-100: breathing intensity

void patternNightLight() {
    // Create night color using warmth setting
    uint8_t baseR = map(nightLightWarmth, 0, 100, 20, 60);
    uint8_t baseG = map(nightLightWarmth, 0, 100, 15, 30);
    uint8_t baseB = map(nightLightWarmth, 0, 100, 10, 3);
    CRGB nightColor = CRGB(baseR, baseG, baseB);

    // Gentle breathing effect using breathe amount
    animationStep++;
    uint8_t breath = sin8(animationStep / 2);
    uint8_t minBright = map(nightLightDimLevel, 0, 100, 5, 40);
    uint8_t breathRange = map(nightLightBreatheAmount, 0, 100, 5, 35);
    uint8_t brightness =
        map(breath, 0, 255, minBright, minBright + breathRange);

    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = nightColor;
        leds[i].nscale8(brightness);
    }
}

// Pattern 12: Candle Flicker - Realistic candle flame
void patternCandleFlicker() {
    animationStep++;

    // Create flickering candle effect with configurable parameters
    // candleFlickerRate: 10-100 (how much it flickers)
    // candleMinBright: 50-200 (minimum brightness)
    for (int i = 0; i < NUM_LEDS; i++) {
        // Random flicker intensity based on candleFlickerRate
        uint8_t flicker = random8(candleMinBright, 255);

        // Candle colors: warm orange/yellow
        uint8_t r = flicker;
        uint8_t g = flicker * 0.4;  // Less green
        uint8_t b = flicker * 0.1;  // Almost no blue

        // Add extra randomness based on flicker rate
        if (random8() < candleFlickerRate) {
            r = random8(candleMinBright, 255);
            g = random8(80, 150);
            b = random8(0, 30);
        }

        leds[i] = CRGB(r, g, b);
    }

    // Occasional brighter flare (rate controlled by candleFlickerRate)
    if (random8() < candleFlickerRate / 5) {
        int pos = random8(NUM_LEDS);
        leds[pos] = CRGB(255, 200, 50);
    }
}

// Pattern 13: Aurora Borealis - Stunning Northern Lights effect
// Multiple layered waves with rich colors and shimmer

// Aurora configuration parameters (can be set via API)
uint8_t auroraSpeed = 15;        // Wave movement speed (lower = slower)
uint8_t auroraBrightness = 220;  // Overall brightness
uint8_t auroraComplexity = 3;    // Number of wave layers (1-4)
uint8_t auroraPaletteIndex = 0;  // 0: Classic, 1: Mystical, 2: Full Spectrum
bool auroraShimmer = true;       // Enable sparkle effect
uint8_t auroraWaveDensity = 50;  // Wave spread (0-100)

// Aurora color palettes
DEFINE_GRADIENT_PALETTE(auroraPalette_classic){
    0,   0,   100, 50,   // Deep green
    64,  0,   200, 150,  // Teal
    128, 50,  150, 255,  // Cyan-blue
    192, 100, 80,  200,  // Purple
    255, 150, 50,  150   // Magenta
};

DEFINE_GRADIENT_PALETTE(auroraPalette_mystical){
    0,   100, 0,   200,  // Purple
    64,  200, 50,  150,  // Magenta
    128, 255, 100, 150,  // Pink
    192, 100, 50,  255,  // Blue-violet
    255, 150, 0,   255   // Bright purple
};

DEFINE_GRADIENT_PALETTE(auroraPalette_spectrum){
    0,   0,   255, 100,  // Green
    51,  0,   200, 200,  // Cyan
    102, 0,   100, 255,  // Blue
    153, 100, 0,   200,  // Purple
    204, 200, 50,  150,  // Magenta
    255, 0,   255, 100   // Back to green
};

CRGBPalette16 auroraPalettes[3] = {
    auroraPalette_classic, auroraPalette_mystical, auroraPalette_spectrum};

void patternAuroraBorealis() {
    static uint16_t auroraTime = 0;
    auroraTime += auroraSpeed;

    // Select the current palette
    CRGBPalette16 currentPalette = auroraPalettes[auroraPaletteIndex % 3];

    // Create aurora effect with multiple wave layers
    for (int i = 0; i < NUM_LEDS; i++) {
        // Position-based offset for wave spread
        uint16_t posOffset = i * (200 + auroraWaveDensity * 3);

        // Layer 1: Primary slow wave (dominant color movement)
        uint16_t wave1 = beatsin16(auroraSpeed, 0, 255, 0, posOffset / 10);

        // Layer 2: Secondary medium wave (adds depth)
        uint16_t wave2 = 0;
        if (auroraComplexity >= 2) {
            wave2 =
                beatsin16(auroraSpeed * 13 / 10, 0, 255, 16384, posOffset / 15);
        }

        // Layer 3: Tertiary faster wave (accent colors)
        uint16_t wave3 = 0;
        if (auroraComplexity >= 3) {
            wave3 =
                beatsin16(auroraSpeed * 17 / 10, 0, 255, 32768, posOffset / 8);
        }

        // Layer 4: Fast shimmer overlay
        uint16_t wave4 = 0;
        if (auroraComplexity >= 4) {
            wave4 =
                beatsin16(auroraSpeed * 25 / 10, 0, 100, 49152, posOffset / 20);
        }

        // Combine waves with weighted blending for depth
        uint8_t colorIndex;
        switch (auroraComplexity) {
            case 1:
                colorIndex = wave1 >> 8;
                break;
            case 2:
                colorIndex = (wave1 / 2 + wave2 / 2) >> 8;
                break;
            case 3:
                colorIndex = (wave1 / 2 + wave2 / 3 + wave3 / 6) >> 8;
                break;
            default:
                colorIndex = (wave1 * 4 / 10 + wave2 * 3 / 10 + wave3 * 2 / 10 +
                              wave4 / 10) >>
                             8;
                break;
        }

        // Get color from aurora palette
        CRGB color = ColorFromPalette(
            currentPalette, colorIndex + (auroraTime >> 8), 255, LINEARBLEND);

        // Add shimmer sparkles
        if (auroraShimmer && random8() < 20) {
            uint8_t shimmerBrightness = random8(50, 150);
            color += CRGB(shimmerBrightness / 2, shimmerBrightness,
                          shimmerBrightness / 2);
        }

        // Apply dynamic brightness pulsing (aurora intensity variation)
        uint8_t dynamicBrightness = auroraBrightness;
        dynamicBrightness =
            qadd8(dynamicBrightness, beatsin8(auroraSpeed / 2, 0, 35));

        leds[i] = color;
        leds[i].nscale8(dynamicBrightness);
    }

    // Special center LED effect - brighter aurora core
    uint8_t centerPulse = beatsin8(auroraSpeed, 200, 255);
    leds[CENTER_LED].nscale8(centerPulse);

    // Add occasional bright streaks (aurora curtains)
    if (random8() < 15) {
        int streakStart = random8(NUM_LEDS);
        int streakLen = random8(2, 5);
        CRGB streakColor =
            ColorFromPalette(currentPalette, random8(), 255, LINEARBLEND);
        for (int j = 0; j < streakLen && (streakStart + j) < NUM_LEDS; j++) {
            leds[streakStart + j] =
                blend(leds[streakStart + j], streakColor, 100);
        }
    }
}

// ==================== NEW PATTERNS ====================

// Pattern 14: Ocean Waves - Very relaxing, popular
uint8_t oceanWaveSpeed = 30;
uint8_t oceanDepth = 70;  // 0=shallow light blue, 100=deep dark blue

void patternOceanWaves() {
    static uint16_t oceanTime = 0;
    oceanTime += oceanWaveSpeed / 5;

    // Create multiple wave layers for realistic ocean effect
    for (int i = 0; i < NUM_LEDS; i++) {
        // Calculate spiral position for wave propagation
        float spiralPos = (float)i / NUM_LEDS;

        // Primary wave - slow rolling
        uint8_t wave1 = sin8(i * 20 + oceanTime);
        // Secondary wave - faster ripples
        uint8_t wave2 = sin8(i * 35 - oceanTime * 2);
        // Tertiary wave - subtle variation
        uint8_t wave3 = sin8(i * 50 + oceanTime / 2);

        // Combine waves
        uint8_t combined = (wave1 / 2 + wave2 / 3 + wave3 / 6);

        // Calculate color based on depth and wave height
        uint8_t hue = 160 + (combined / 20);  // Blue to cyan range
        uint8_t sat = 200 + (oceanDepth / 4);
        uint8_t val = map(combined, 0, 255, 80, 220);

        // Deeper = darker base
        val = val * (100 - oceanDepth / 3) / 100;

        leds[i] = CHSV(hue, sat, val);
    }

    // Center LED - occasional foam/sparkle
    if (random8() < 30) {
        leds[CENTER_LED] = CRGB(200, 230, 255);  // White foam
    }

    // Random white caps on waves
    if (random8() < 15) {
        int pos = random8(NUM_LEDS);
        leds[pos] = blend(leds[pos], CRGB(180, 200, 220), 150);
    }
}

// Pattern 15: Sunset Fade - Beautiful for evening
uint8_t sunsetPhase = 0;  // 0-255 sunset progression
uint8_t sunsetSpeed = 20;

void patternSunsetFade() {
    static uint16_t sunsetTime = 0;
    sunsetTime += sunsetSpeed / 10;

    // Sunset color palette progression
    // Early: Orange/Yellow -> Mid: Pink/Purple -> Late: Deep Purple/Blue
    uint8_t phase = (sunsetTime / 4) % 256;

    for (int i = 0; i < NUM_LEDS; i++) {
        // Create horizon gradient effect with spiral
        float position = (float)i / NUM_LEDS;

        // Base sunset hue shifts through orange -> pink -> purple
        uint8_t baseHue;
        if (phase < 85) {
            baseHue = map(phase, 0, 85, 32, 0);  // Yellow to Orange
        } else if (phase < 170) {
            baseHue = map(phase, 85, 170, 0, 240);  // Orange to Pink/Magenta
        } else {
            baseHue = map(phase, 170, 255, 240, 200);  // Pink to Purple
        }

        // Gradient from center (sun) outward (sky)
        uint8_t hueOffset;
        if (i == CENTER_LED) {
            hueOffset = 0;  // Sun color
        } else if (i >= INNER_SPIRAL_START && i <= INNER_SPIRAL_END) {
            hueOffset = 10;  // Near sun glow
        } else {
            hueOffset = 20 + (i % 4) * 5;  // Sky gradient
        }

        uint8_t hue = (baseHue + hueOffset) % 256;
        uint8_t sat = 220 - (i * 2);
        uint8_t val = 200 - (phase / 4);  // Dims as sun sets

        leds[i] = CHSV(hue, sat, val);
    }

    // Center sun - always brightest
    leds[CENTER_LED] = CHSV((phase < 85) ? 32 : 16, 255, 255);
}

// Meteor shower configurable parameters
uint8_t meteorSpawnRate = 20;  // 0-100: frequency of new meteors
uint8_t meteorTailLength = 4;  // 2-8: length of meteor tail

// Pattern 16: Meteor Shower - Exciting and dynamic
void patternMeteorShower() {
    static uint8_t meteorPos[3] = {255, 255, 255};  // Track 3 meteors
    static uint8_t meteorHue[3] = {0, 0, 0};

    // Fade all LEDs
    fadeToBlackBy(leds, NUM_LEDS, 60);

    // Update and draw meteors
    for (int m = 0; m < 3; m++) {
        if (meteorPos[m] < NUM_LEDS) {
            // Draw meteor with tail (using configurable tail length)
            for (int t = 0; t < meteorTailLength; t++) {
                int pos = meteorPos[m] - t;
                if (pos >= 0 && pos < NUM_LEDS) {
                    uint8_t brightness = 255 - (t * (200 / meteorTailLength));
                    leds[pos] = CHSV(meteorHue[m], 180, brightness);
                }
            }
            meteorPos[m]++;
        } else if (random8() < meteorSpawnRate) {
            // Spawn new meteor (using configurable spawn rate)
            meteorPos[m] = 0;
            meteorHue[m] = random8();
        }
    }

    // Background stars
    for (int i = 0; i < NUM_LEDS; i++) {
        if (leds[i].r < 5 && leds[i].g < 5 && leds[i].b < 10) {
            leds[i] = CRGB(0, 0, random8(5, 20));  // Dim background
        }
    }

    // Random twinkle
    if (random8() < 40) {
        leds[random8(NUM_LEDS)] = CRGB(255, 255, 255);
    }
}

// Pattern 17: Lightning Storm - Dramatic and cool
uint8_t stormIntensity = 70;  // 0=calm, 100=intense

void patternLightningStorm() {
    static uint8_t flashState = 0;
    static uint8_t flashCount = 0;
    static unsigned long lastFlash = 0;

    // Dark stormy background
    for (int i = 0; i < NUM_LEDS; i++) {
        // Deep blue-gray storm clouds
        uint8_t cloudMove = sin8(i * 15 + millis() / 50);
        leds[i] = CRGB(cloudMove / 20, cloudMove / 15, cloudMove / 8 + 20);
    }

    // Lightning flash logic
    if (flashState > 0) {
        // During flash
        uint8_t flashBright = (flashState > 200) ? 255 : flashState;

        // Main bolt (random path through spiral)
        for (int i = 0; i < NUM_LEDS; i++) {
            if (random8() < 100) {
                leds[i] = CRGB(flashBright, flashBright, flashBright + 50);
            }
        }

        // Intense center flash
        leds[CENTER_LED] = CRGB(255, 255, 255);

        flashState -= 40;
        if (flashState < 40) {
            flashState = 0;
            if (flashCount > 0) {
                flashCount--;
                flashState = random8(150, 255);  // Secondary flash
            }
        }
    } else {
        // Check for new lightning
        uint8_t triggerChance = map(stormIntensity, 0, 100, 2, 15);
        if (random8() < triggerChance) {
            flashState = 255;
            flashCount = random8(0, 3);  // 0-2 additional flashes
        }
    }
}

// Pattern 18: Ripple - Circular waves from center point
uint8_t rippleSpeed = 40;
uint8_t rippleDecay = 80;

void patternRipple() {
    static uint8_t ripplePhase = 0;
    static uint8_t rippleHue = 0;
    ripplePhase += rippleSpeed / 10;

    // Fade existing
    fadeToBlackBy(leds, NUM_LEDS, rippleDecay / 4);

    // Calculate distance from center for each LED
    // In our spiral: center=20, inner=16-19, outer=0-15

    // Center always has ripple source
    uint8_t centerBright = sin8(ripplePhase * 4);
    leds[CENTER_LED] = CHSV(rippleHue, 255, centerBright);

    // Inner spiral - first ripple ring
    uint8_t innerPhase = ripplePhase - 30;
    uint8_t innerBright = sin8(innerPhase * 4);
    for (int i = INNER_SPIRAL_START; i <= INNER_SPIRAL_END; i++) {
        leds[i] = blend(leds[i], CHSV(rippleHue + 20, 255, innerBright), 180);
    }

    // Outer spiral - second ripple ring
    uint8_t outerPhase = ripplePhase - 60;
    uint8_t outerBright = sin8(outerPhase * 4);
    for (int i = OUTER_SPIRAL_START; i <= OUTER_SPIRAL_END; i++) {
        // Vary by position in outer ring
        uint8_t posPhase = outerPhase - (i % 4) * 8;
        uint8_t posBright = sin8(posPhase * 4);
        leds[i] = blend(leds[i], CHSV(rippleHue + 40, 255, posBright), 150);
    }

    // Slowly shift hue
    if (random8() < 5) rippleHue++;
}

// Pattern 19: Kaleidoscope - Symmetrical color patterns
uint8_t kaleidoscopeSpeed = 30;

void patternKaleidoscope() {
    static uint16_t kTime = 0;
    kTime += kaleidoscopeSpeed / 5;

    // Create symmetrical patterns based on spiral quadrants
    // Outer spiral has 4 sides of 4 LEDs each

    for (int side = 0; side < 4; side++) {
        int startIdx = side * 4;
        for (int i = 0; i < 4; i++) {
            // Create mirrored pattern
            uint8_t patternVal = sin8(kTime + i * 40 + side * 64);
            uint8_t hue = (kTime / 4 + side * 64 + patternVal / 4) % 256;
            uint8_t sat = 200 + sin8(kTime / 2 + i * 30) / 4;
            uint8_t val = 150 + patternVal / 3;

            leds[startIdx + i] = CHSV(hue, sat, val);
        }
    }

    // Inner spiral mirrors as 2x2
    for (int i = 0; i < 4; i++) {
        uint8_t patternVal = sin8(kTime * 2 + i * 64);
        uint8_t hue = (kTime / 3 + patternVal / 2) % 256;
        leds[INNER_SPIRAL_START + i] = CHSV(hue, 255, 180 + patternVal / 4);
    }

    // Center pulses
    uint8_t centerPulse = sin8(kTime * 3);
    leds[CENTER_LED] = CHSV(kTime / 2, 255, 200 + centerPulse / 5);
}

// Pattern 20: DNA Helix - Two intertwined spirals
uint8_t dnaSpeed = 35;

void patternDNAHelix() {
    static uint16_t dnaPhase = 0;
    dnaPhase += dnaSpeed / 5;

    // Fade background
    fadeToBlackBy(leds, NUM_LEDS, 30);

    // Two helixes traveling through the spiral
    // Helix 1: Blue/Cyan
    // Helix 2: Pink/Magenta (offset by 180 degrees)

    for (int i = 0; i < NUM_LEDS; i++) {
        // Calculate position in helix
        float pos = (float)i / NUM_LEDS * 2 * PI;

        // Helix 1 wave
        float helix1 = sin(pos * 3 + dnaPhase / 50.0);
        // Helix 2 wave (180 degree offset)
        float helix2 = sin(pos * 3 + dnaPhase / 50.0 + PI);

        // Only light up when helix "passes through" this LED
        if (helix1 > 0.7) {
            uint8_t bright = map(helix1 * 100, 70, 100, 100, 255);
            leds[i] = blend(leds[i], CHSV(160, 255, bright), 200);  // Cyan
        }
        if (helix2 > 0.7) {
            uint8_t bright = map(helix2 * 100, 70, 100, 100, 255);
            leds[i] = blend(leds[i], CHSV(220, 255, bright), 200);  // Pink
        }

        // "Rungs" connecting helixes at certain points
        if (i % 5 == 0 && abs(helix1 - helix2) < 0.5) {
            leds[i] = blend(leds[i], CRGB(100, 100, 100), 100);
        }
    }

    // Center is the "core"
    leds[CENTER_LED] = CHSV(dnaPhase / 4, 200, 180);
}

// Pattern 21: Forest Breeze - Green tones with gentle movement
uint8_t forestBreeze = 40;  // Breeze intensity

void patternForestBreeze() {
    static uint16_t forestTime = 0;
    forestTime += forestBreeze / 8;

    for (int i = 0; i < NUM_LEDS; i++) {
        // Multiple green layers
        uint8_t wave1 = sin8(i * 20 + forestTime);
        uint8_t wave2 = sin8(i * 30 - forestTime / 2);

        // Vary between different greens
        uint8_t hue = 85 + (wave1 / 16) - (wave2 / 32);  // 80-95 green range
        uint8_t sat = 200 + wave2 / 8;
        uint8_t val = 120 + wave1 / 3;

        // Add subtle yellows (sunlight filtering through)
        if ((i + forestTime / 30) % 7 == 0) {
            hue = 64;  // Yellow-green
            val += 30;
        }

        leds[i] = CHSV(hue, sat, val);
    }

    // Center - occasional "sunbeam"
    if (random8() < 10) {
        leds[CENTER_LED] = CHSV(45, 180, 255);  // Warm sunlight
    } else {
        leds[CENTER_LED] = CHSV(90, 255, 180);  // Deep forest green
    }

    // Random leaf flutter (brief brightness)
    if (random8() < 20) {
        int pos = random8(NUM_LEDS);
        leds[pos] = CHSV(80, 255, 255);
    }
}

// Pattern 22: Firefly Glow - Gentle fireflies
uint8_t fireflyCount = 5;
uint8_t fireflySpeed = 30;

void patternFireflyGlow() {
    static uint8_t fireflyPos[6] = {0};
    static uint8_t fireflyBright[6] = {0};
    static uint8_t fireflyPhase[6] = {0};

    // Dark forest background
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = CRGB(0, random8(3, 8), random8(0, 5));  // Very dim green
    }

    // Update each firefly
    for (int f = 0; f < fireflyCount; f++) {
        fireflyPhase[f] += random8(1, 4);

        // Firefly glow cycle: fade in, bright, fade out, off
        if (fireflyPhase[f] < 60) {
            fireflyBright[f] = map(fireflyPhase[f], 0, 60, 0, 200);
        } else if (fireflyPhase[f] < 100) {
            fireflyBright[f] = 200 + random8(0, 55);  // Flickering bright
        } else if (fireflyPhase[f] < 160) {
            fireflyBright[f] = map(fireflyPhase[f], 100, 160, 200, 0);
        } else {
            fireflyBright[f] = 0;
            if (random8() < 30) {
                // Move to new position
                fireflyPos[f] = random8(NUM_LEDS);
                fireflyPhase[f] = 0;
            }
        }

        // Draw firefly
        if (fireflyBright[f] > 0) {
            leds[fireflyPos[f]] =
                CHSV(55, 255, fireflyBright[f]);  // Yellow-green glow
            // Subtle halo on neighbors
            if (fireflyPos[f] > 0)
                leds[fireflyPos[f] - 1] =
                    blend(leds[fireflyPos[f] - 1],
                          CHSV(55, 255, fireflyBright[f] / 3), 100);
            if (fireflyPos[f] < NUM_LEDS - 1)
                leds[fireflyPos[f] + 1] =
                    blend(leds[fireflyPos[f] + 1],
                          CHSV(55, 255, fireflyBright[f] / 3), 100);
        }
    }
}

// Pattern 23: Dreamy Clouds - Soft cloud movement
uint8_t cloudSpeed = 25;
uint8_t cloudDensity = 60;

void patternDreamyClouds() {
    static uint16_t cloudTime = 0;
    cloudTime += cloudSpeed / 8;

    for (int i = 0; i < NUM_LEDS; i++) {
        // Multiple noise layers for cloud effect
        uint8_t noise1 = inoise8(i * 50, cloudTime);
        uint8_t noise2 = inoise8(i * 30 + 1000, cloudTime / 2);
        uint8_t combined = (noise1 + noise2) / 2;

        // Cloud colors: white/light blue/light purple
        uint8_t hue, sat, val;

        if (combined > 200) {
            // Bright cloud
            hue = 170;  // Light blue
            sat = 50;
            val = 200 + (combined - 200);
        } else if (combined > 140) {
            // Mid cloud
            hue = 180 + (combined - 140) / 4;
            sat = 80;
            val = 150 + (combined - 140);
        } else {
            // Background sky
            hue = 160 + random8(0, 20);
            sat = 150;
            val = 80 + combined / 3;
        }

        leds[i] = CHSV(hue, sat, val);
    }

    // Dreamy sparkles
    if (random8() < cloudDensity / 10) {
        leds[random8(NUM_LEDS)] = CRGB(255, 240, 255);  // Soft white sparkle
    }

    // Center - soft glow
    leds[CENTER_LED] = CHSV(190, 60, 220);
}

// Pattern 24: Lava Lamp - Slow-moving blobs of warm colors
uint8_t lavaSpeed = 20;     // Slower = more lava lamp like
uint8_t lavaBlobSize = 50;  // Size of blobs 20-100

void patternLavaLamp() {
    static uint16_t lavaTime = 0;
    lavaTime += lavaSpeed / 10;

    // Create slow-moving blobs using multiple sine waves
    for (int i = 0; i < NUM_LEDS; i++) {
        // Very slow, organic movement
        float pos = (float)i / NUM_LEDS;

        // Multiple overlapping "blobs" - size affects frequency
        uint8_t blobFreq = map(lavaBlobSize, 20, 100, 50, 20);
        uint8_t blob1 = sin8(i * blobFreq + lavaTime);
        uint8_t blob2 = sin8(i * (blobFreq + 15) - lavaTime * 0.7);
        uint8_t blob3 = sin8(i * (blobFreq - 10) + lavaTime * 0.4 + 128);

        // Combine blobs
        uint8_t combined = (blob1 / 2 + blob2 / 3 + blob3 / 6);

        // Warm color palette: deep red -> orange -> yellow
        uint8_t hue, sat, val;

        if (combined > 180) {
            // Bright blob (yellow-orange)
            hue = map(combined, 180, 255, 32, 48);
            sat = 255;
            val = 200 + (combined - 180);
        } else if (combined > 100) {
            // Mid blob (orange-red)
            hue = map(combined, 100, 180, 16, 32);
            sat = 255;
            val = 150 + (combined - 100);
        } else {
            // Background (deep red/maroon)
            hue = random8(0, 16);
            sat = 255;
            val = 50 + combined / 2;
        }

        leds[i] = CHSV(hue, sat, val);
    }

    // Very slow color shift for variety
    static uint8_t lavaHueShift = 0;
    if (random8() < 2) lavaHueShift++;

    // Apply subtle hue shift
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i].r = qadd8(leds[i].r, sin8(lavaHueShift) / 16);
    }

    // Center - the "heat source"
    uint8_t centerGlow = sin8(lavaTime * 2);
    leds[CENTER_LED] = CHSV(32, 255, 200 + centerGlow / 5);
}

// Pattern 25: Custom Color (set via API)
void patternCustomColor() {
    if (lampState.customHue > 0 || lampState.customSaturation > 0) {
        // Use HSV values from color wheel
        fill_solid(
            leds, NUM_LEDS,
            CHSV(lampState.customHue % 256, lampState.customSaturation, 255));
    } else {
        // Use RGB values
        fill_solid(leds, NUM_LEDS,
                   CRGB(lampState.customRed, lampState.customGreen,
                        lampState.customBlue));
    }
}

// ==================== STATE PERSISTENCE ====================
void saveState() {
    preferences.begin("lampState", false);
    preferences.putBool("isOn", lampState.isOn);
    preferences.putUChar("brightness", lampState.brightness);
    preferences.putUChar("pattern", lampState.currentPattern);
    preferences.putUChar("customR", lampState.customRed);
    preferences.putUChar("customG", lampState.customGreen);
    preferences.putUChar("customB", lampState.customBlue);
    preferences.putUChar("readingWarmth", lampState.readingWarmth);
    preferences.putUShort("customHue", lampState.customHue);
    preferences.putUChar("customSat", lampState.customSaturation);
    preferences.putString("wifiSSID", lampState.wifiSSID);
    preferences.putString("wifiPass", lampState.wifiPassword);
    preferences.putBool("gyroEnabled", lampState.gyroEnabled);
    preferences.putUChar("gyroPattern", lampState.gyroPattern);
    preferences.end();
}

void loadState() {
    preferences.begin("lampState", true);
    lampState.isOn = preferences.getBool("isOn", true);
    lampState.brightness = preferences.getUChar("brightness", 128);
    lampState.currentPattern = preferences.getUChar("pattern", 0);
    lampState.customRed = preferences.getUChar("customR", 255);
    lampState.customGreen = preferences.getUChar("customG", 255);
    lampState.customBlue = preferences.getUChar("customB", 255);
    lampState.readingWarmth =
        preferences.getUChar("readingWarmth", 50);  // Default to medium warmth
    lampState.customHue = preferences.getUShort("customHue", 0);
    lampState.customSaturation = preferences.getUChar("customSat", 255);
    lampState.wifiSSID = preferences.getString("wifiSSID", "");
    lampState.wifiPassword = preferences.getString("wifiPass", "");
    lampState.gyroEnabled = preferences.getBool("gyroEnabled", false);
    lampState.gyroPattern = preferences.getUChar("gyroPattern", 0);
    preferences.end();

    Serial.println("State loaded from memory");
}

// Calibration persistence
void loadCalibrationData() {
    preferences.begin("lampCal", true);
    calibration.valid = preferences.getBool("valid", false);
    calibration.pitchOffset = preferences.getFloat("pitchOffset", 0.0f);
    calibration.rollOffset = preferences.getFloat("rollOffset", 0.0f);
    calibration.pitchScale = preferences.getFloat("pitchScale", 1.0f);
    calibration.rollScale = preferences.getFloat("rollScale", 1.0f);
    preferences.end();

    if (calibration.pitchScale == 0) calibration.pitchScale = 1.0f;
    if (calibration.rollScale == 0) calibration.rollScale = 1.0f;

    Serial.print("Calibration loaded: valid=");
    Serial.print(calibration.valid);
    Serial.print(" pitchOffset=");
    Serial.print(calibration.pitchOffset);
    Serial.print(" rollOffset=");
    Serial.print(calibration.rollOffset);
    Serial.print(" pitchScale=");
    Serial.print(calibration.pitchScale);
    Serial.print(" rollScale=");
    Serial.println(calibration.rollScale);
}

void saveCalibrationData() {
    preferences.begin("lampCal", false);
    preferences.putBool("valid", calibration.valid);
    preferences.putFloat("pitchOffset", calibration.pitchOffset);
    preferences.putFloat("rollOffset", calibration.rollOffset);
    preferences.putFloat("pitchScale", calibration.pitchScale);
    preferences.putFloat("rollScale", calibration.rollScale);
    preferences.end();
    Serial.println("Calibration saved to NVS");
}

void resetCalibrationCapture() {
    calCapture = {false, false, false, false, false, 0, 0, 0, 0, 0, 0};
}

void computeCalibration() {
    // Require all directions captured
    if (!(calCapture.centerSet && calCapture.leftSet && calCapture.rightSet &&
          calCapture.frontSet && calCapture.backSet)) {
        calibration.valid = false;
        return;
    }

    calibration.pitchOffset = calCapture.centerPitch;
    calibration.rollOffset = calCapture.centerRoll;

    float rollSpan = (abs(calCapture.rightRoll - calCapture.centerRoll) +
                      abs(calCapture.leftRoll - calCapture.centerRoll)) /
                     2.0f;
    float pitchSpan = (abs(calCapture.frontPitch - calCapture.centerPitch) +
                       abs(calCapture.backPitch - calCapture.centerPitch)) /
                      2.0f;

    calibration.rollScale = (rollSpan > 1.0f) ? (90.0f / rollSpan) : 1.0f;
    calibration.pitchScale = (pitchSpan > 1.0f) ? (90.0f / pitchSpan) : 1.0f;

    calibration.valid = true;
    saveCalibrationData();

    Serial.println("Calibration computed and applied:");
    Serial.print(" pitchOffset=");
    Serial.print(calibration.pitchOffset);
    Serial.print(" rollOffset=");
    Serial.print(calibration.rollOffset);
    Serial.print(" pitchScale=");
    Serial.print(calibration.pitchScale);
    Serial.print(" rollScale=");
    Serial.println(calibration.rollScale);
}

// ==================== AUTHENTICATION ====================
String generateToken() {
    String token = "";
    for (int i = 0; i < 32; i++) {
        token += String(random(0, 16), HEX);
    }
    return token;
}

bool validateAuth() {
    if (!server.hasHeader("Authorization")) {
        return false;
    }

    String authHeader = server.header("Authorization");
    if (!authHeader.startsWith("Bearer ")) {
        return false;
    }

    String token = authHeader.substring(7);
    return (token == currentAuthToken && millis() < tokenExpiry);
}

// ==================== API HANDLERS ====================

void handleCORS() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    server.sendHeader("Access-Control-Allow-Headers",
                      "Content-Type, Authorization");
    server.send(204);
}

void sendJSONResponse(int code, JsonDocument& doc) {
    String response;
    serializeJson(doc, response);
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(code, "application/json", response);
}

void sendErrorResponse(int code, const char* message) {
    StaticJsonDocument<200> doc;
    doc["success"] = false;
    doc["error"] = message;
    sendJSONResponse(code, doc);
}

void sendSuccessResponse(const char* message) {
    StaticJsonDocument<200> doc;
    doc["success"] = true;
    doc["message"] = message;
    sendJSONResponse(200, doc);
}

// Root endpoint - API documentation
void handleRoot() {
    StaticJsonDocument<2048> doc;  // Increased size for more endpoints
    doc["name"] = "ESP32-C3 Smart Lamp API";
    doc["version"] = FIRMWARE_VERSION;
    doc["lampId"] = LAMP_ID;
    doc["deviceType"] = DEVICE_TYPE;
    doc["numLeds"] = NUM_LEDS;
    doc["gyroAvailable"] = mpuInitialized;

    JsonArray endpoints = doc.createNestedArray("endpoints");

    // Discovery endpoints (no auth required)
    JsonObject info = endpoints.createNestedObject();
    info["path"] = "/info";
    info["method"] = "GET";
    info["description"] = "Device discovery info (no auth)";
    info["auth"] = false;

    JsonObject apiInfo = endpoints.createNestedObject();
    apiInfo["path"] = "/api/info";
    apiInfo["method"] = "GET";
    apiInfo["description"] = "Device discovery info (no auth)";
    apiInfo["auth"] = false;

    JsonObject auth = endpoints.createNestedObject();
    auth["path"] = "/api/auth";
    auth["method"] = "POST";
    auth["description"] = "Authenticate with lamp password";
    auth["auth"] = false;

    JsonObject status = endpoints.createNestedObject();
    status["path"] = "/api/status";
    status["method"] = "GET";
    status["description"] = "Get lamp status (requires auth)";
    status["auth"] = true;

    JsonObject patterns = endpoints.createNestedObject();
    patterns["path"] = "/api/patterns";
    patterns["method"] = "GET";
    patterns["description"] = "Get list of available patterns";
    patterns["auth"] = true;

    JsonObject pattern = endpoints.createNestedObject();
    pattern["path"] = "/api/pattern";
    pattern["method"] = "POST";
    pattern["description"] = "Set lighting pattern";
    pattern["auth"] = true;

    JsonObject brightness = endpoints.createNestedObject();
    brightness["path"] = "/api/brightness";
    brightness["method"] = "POST";
    brightness["description"] = "Set brightness (0-255)";
    brightness["auth"] = true;

    JsonObject power = endpoints.createNestedObject();
    power["path"] = "/api/power";
    power["method"] = "POST";
    power["description"] = "Turn lamp on/off";
    power["auth"] = true;

    JsonObject color = endpoints.createNestedObject();
    color["path"] = "/api/color";
    color["method"] = "POST";
    color["description"] = "Set custom RGB color";
    color["auth"] = true;

    JsonObject colorwheel = endpoints.createNestedObject();
    colorwheel["path"] = "/api/colorwheel";
    colorwheel["method"] = "POST";
    colorwheel["description"] = "Set color via HSV wheel";
    colorwheel["auth"] = true;

    JsonObject wifi = endpoints.createNestedObject();
    wifi["path"] = "/api/wifi";
    wifi["method"] = "POST";
    wifi["description"] = "Configure WiFi credentials";
    wifi["auth"] = true;

    JsonObject wifiScan = endpoints.createNestedObject();
    wifiScan["path"] = "/api/wifi/scan";
    wifiScan["method"] = "GET";
    wifiScan["description"] = "Scan available WiFi networks";
    wifiScan["auth"] = true;

    // Gyro endpoints
    JsonObject gyroGet = endpoints.createNestedObject();
    gyroGet["path"] = "/api/gyro";
    gyroGet["method"] = "GET";
    gyroGet["description"] = "Get gyro status and sensor data";
    gyroGet["auth"] = true;

    JsonObject gyroSet = endpoints.createNestedObject();
    gyroSet["path"] = "/api/gyro";
    gyroSet["method"] = "POST";
    gyroSet["description"] = "Enable/disable gyro mode and set pattern";
    gyroSet["auth"] = true;

    JsonObject gyroPattern = endpoints.createNestedObject();
    gyroPattern["path"] = "/api/gyro/pattern";
    gyroPattern["method"] = "POST";
    gyroPattern["description"] = "Set gyro pattern";
    gyroPattern["auth"] = true;

    sendJSONResponse(200, doc);
}

// Info endpoint for device discovery (no auth required)
void handleInfo() {
    Serial.println("\n=== /info endpoint called ===");
    Serial.print("Client IP: ");
    Serial.println(server.client().remoteIP());

    StaticJsonDocument<512> doc;
    doc["success"] = true;
    doc["id"] = LAMP_ID;
    doc["name"] = "Smart Lamp";
    doc["type"] = DEVICE_TYPE;
    doc["version"] = FIRMWARE_VERSION;
    doc["numLeds"] = NUM_LEDS;
    doc["ip"] = WiFi.localIP().toString();
    doc["mac"] = WiFi.macAddress();
    doc["requiresAuth"] = true;
    doc["gyroAvailable"] = mpuInitialized;

    JsonObject capabilities = doc.createNestedObject("capabilities");
    capabilities["patterns"] = NUM_PATTERNS;
    capabilities["gyroPatterns"] = NUM_GYRO_PATTERNS;
    capabilities["brightness"] = true;
    capabilities["color"] = true;
    capabilities["colorWheel"] = true;
    capabilities["gyro"] = mpuInitialized;

    Serial.println("Sending response:");
    serializeJsonPretty(doc, Serial);
    Serial.println("\n=== /info response sent ===");

    sendJSONResponse(200, doc);
}

// Get available patterns endpoint
void handleGetPatterns() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    StaticJsonDocument<1024> doc;
    doc["success"] = true;
    doc["numPatterns"] = NUM_PATTERNS;
    doc["currentPattern"] = lampState.currentPattern;

    JsonArray patterns = doc.createNestedArray("patterns");
    for (int i = 0; i < NUM_PATTERNS; i++) {
        JsonObject p = patterns.createNestedObject();
        p["id"] = i;
        p["name"] = patternNames[i];
        p["active"] = (i == lampState.currentPattern);
    }

    sendJSONResponse(200, doc);
}

// Authentication endpoint
void handleAuth() {
    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<200> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    const char* password = requestDoc["password"];
    if (!password || strcmp(password, LAMP_PASSWORD) != 0) {
        sendErrorResponse(401, "Invalid password");
        return;
    }

    // Generate new token
    currentAuthToken = generateToken();
    tokenExpiry = millis() + TOKEN_LIFETIME;

    StaticJsonDocument<300> responseDoc;
    responseDoc["success"] = true;
    responseDoc["token"] = currentAuthToken;
    responseDoc["expiresIn"] = TOKEN_LIFETIME / 1000;
    responseDoc["lampId"] = LAMP_ID;

    sendJSONResponse(200, responseDoc);
}

// Status endpoint
void handleStatus() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    StaticJsonDocument<1536> doc;
    doc["success"] = true;
    doc["lampId"] = LAMP_ID;
    doc["deviceType"] = DEVICE_TYPE;
    doc["firmwareVersion"] = FIRMWARE_VERSION;
    doc["isOn"] = lampState.isOn;
    doc["brightness"] = lampState.brightness;
    doc["brightnessPercent"] = (lampState.brightness * 100) / 255;
    doc["readingWarmth"] = lampState.readingWarmth;
    doc["currentPattern"] = lampState.currentPattern;
    doc["patternName"] = patternNames[lampState.currentPattern];
    doc["numPatterns"] = NUM_PATTERNS;
    doc["numLeds"] = NUM_LEDS;
    doc["uptime"] = millis() / 1000;  // Uptime in seconds

    JsonObject customColor = doc.createNestedObject("customColor");
    customColor["r"] = lampState.customRed;
    customColor["g"] = lampState.customGreen;
    customColor["b"] = lampState.customBlue;
    customColor["hue"] = lampState.customHue;
    customColor["saturation"] = lampState.customSaturation;

    JsonObject network = doc.createNestedObject("network");
    network["ssid"] = WiFi.SSID();
    network["ip"] = WiFi.localIP().toString();
    network["rssi"] = WiFi.RSSI();
    network["mac"] = WiFi.macAddress();

    // Gyro information
    JsonObject gyro = doc.createNestedObject("gyro");
    gyro["enabled"] = lampState.gyroEnabled;
    gyro["available"] = mpuInitialized;
    gyro["pattern"] = lampState.gyroPattern;
    gyro["patternName"] = gyroPatternNames[lampState.gyroPattern];
    gyro["numPatterns"] = NUM_GYRO_PATTERNS;

    if (mpuInitialized && lampState.gyroEnabled) {
        gyro["pitch"] = gyroState.pitch;
        gyro["roll"] = gyroState.roll;
        gyro["accX"] = gyroState.accX;
        gyro["accY"] = gyroState.accY;
        gyro["accZ"] = gyroState.accZ;
        gyro["gesture"] = gyroState.currentGesture;
        gyro["isShaking"] = gyroState.isShaking;
        gyro["isTilted"] = gyroState.isTilted;
        gyro["isFlipped"] = gyroState.isFlipped;
        gyro["tiltDirection"] = gyroState.tiltDirection;
    }

    // List all patterns
    JsonArray patterns = doc.createNestedArray("patterns");
    for (int i = 0; i < NUM_PATTERNS; i++) {
        JsonObject p = patterns.createNestedObject();
        p["id"] = i;
        p["name"] = patternNames[i];
    }

    // List gyro patterns
    JsonArray gPatterns = doc.createNestedArray("gyroPatterns");
    for (int i = 0; i < NUM_GYRO_PATTERNS; i++) {
        JsonObject gp = gPatterns.createNestedObject();
        gp["id"] = i;
        gp["name"] = gyroPatternNames[i];
    }

    sendJSONResponse(200, doc);
}

// Set pattern endpoint
void handleSetPattern() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<200> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!requestDoc.containsKey("pattern")) {
        sendErrorResponse(400, "Missing 'pattern' field");
        return;
    }

    int pattern = requestDoc["pattern"];
    if (pattern < 0 || pattern >= NUM_PATTERNS) {
        sendErrorResponse(400, "Pattern out of range");
        return;
    }

    lampState.currentPattern = pattern;
    animationStep = 0;
    hueOffset = 0;
    saveState();

    StaticJsonDocument<200> responseDoc;
    responseDoc["success"] = true;
    responseDoc["pattern"] = pattern;
    responseDoc["patternName"] = patternNames[pattern];

    sendJSONResponse(200, responseDoc);
}

// ==================== PATTERN CONFIG ENDPOINTS ====================

// Configuration variables for each pattern (declared near each pattern
// function)
extern uint8_t auroraSpeed;
extern uint8_t auroraBrightness;
extern uint8_t auroraComplexity;
extern uint8_t auroraPaletteIndex;
extern bool auroraShimmer;
extern uint8_t auroraWaveDensity;

// Note: Fire pattern uses fireCalmness, fireIntensity, fireSpread
// declared near the pattern function (lines 1493-1495)

// Rainbow pattern config
uint8_t rainbowSpeed = 10;
bool rainbowReverse = false;

// Breathing pattern config (breathingSpeed declared at line 1594)
uint8_t breathingHue = 0;

// Pulse pattern config (pulseSpeed declared at line 1600)
uint8_t pulseHue = 0;

// Note: Fire pattern uses fireCalmness, fireIntensity, fireSpread
// declared near the pattern function (lines 1493-1495)
// Note: candleFlickerRate, candleMinBright declared at lines 1603-1604
// Note: colorCycleSpeed declared at line 1597

// Get pattern config endpoint
void handleGetPatternConfig() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    int pattern = lampState.currentPattern;
    if (server.hasArg("pattern")) {
        pattern = server.arg("pattern").toInt();
    }

    StaticJsonDocument<512> doc;
    doc["success"] = true;
    doc["pattern"] = pattern;
    doc["patternName"] = patternNames[pattern];

    JsonObject config = doc.createNestedObject("config");

    // Return configuration for the specified pattern
    switch (pattern) {
        case 0:  // Night Reading
            config["warmth"] = nightReadingWarmth;
            config["yellowness"] = nightReadingYellowness;
            config["brightness"] = nightReadingBrightness;
            break;
        case 2:  // Rainbow Spiral
            config["speed"] = rainbowSpeed;
            config["reverse"] = rainbowReverse;
            break;
        case 3:  // Fire Effect
            config["calmness"] = fireCalmness;
            config["intensity"] = fireIntensity;
            config["spread"] = fireSpread;
            break;
        case 5:  // Breathing White
            config["speed"] = breathingSpeed;
            config["hue"] = breathingHue;
            break;
        case 6:  // Color Cycle
            config["speed"] = colorCycleSpeed;
            break;
        case 9:  // Pulse From Center
            config["speed"] = pulseSpeed;
            config["hue"] = pulseHue;
            break;
        case 12:  // Candle Flicker
            config["flickerRate"] = candleFlickerRate;
            config["minBrightness"] = candleMinBright;
            break;
        case 13:  // Aurora Borealis
            config["speed"] = auroraSpeed;
            config["brightness"] = auroraBrightness;
            config["complexity"] = auroraComplexity;
            config["paletteIndex"] = auroraPaletteIndex;
            config["shimmer"] = auroraShimmer;
            config["waveDensity"] = auroraWaveDensity;
            break;
        default:
            // Pattern has no configurable parameters
            break;
    }

    sendJSONResponse(200, doc);
}

// Set pattern config endpoint
void handleSetPatternConfig() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<512> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!requestDoc.containsKey("pattern")) {
        sendErrorResponse(400, "Missing 'pattern' field");
        return;
    }

    int pattern = requestDoc["pattern"];
    if (pattern < 0 || pattern >= NUM_PATTERNS) {
        sendErrorResponse(400, "Pattern out of range");
        return;
    }

    // Apply configuration based on pattern
    switch (pattern) {
        case 0:  // Night Reading
            if (requestDoc.containsKey("warmth")) {
                nightReadingWarmth =
                    constrain(requestDoc["warmth"].as<int>(), 0, 100);
                lampState.readingWarmth = nightReadingWarmth;
            }
            if (requestDoc.containsKey("yellowness")) {
                nightReadingYellowness =
                    constrain(requestDoc["yellowness"].as<int>(), 0, 100);
            }
            if (requestDoc.containsKey("brightness")) {
                nightReadingBrightness =
                    constrain(requestDoc["brightness"].as<int>(), 0, 255);
            }
            break;

        case 2:  // Rainbow
            if (requestDoc.containsKey("speed")) {
                rainbowSpeed = constrain(requestDoc["speed"].as<int>(), 1, 50);
            }
            if (requestDoc.containsKey("reverse")) {
                rainbowReverse = requestDoc["reverse"].as<bool>();
            }
            break;

        case 3:  // Fire Effect
            if (requestDoc.containsKey("calmness")) {
                fireCalmness =
                    constrain(requestDoc["calmness"].as<int>(), 0, 100);
            }
            if (requestDoc.containsKey("intensity")) {
                fireIntensity =
                    constrain(requestDoc["intensity"].as<int>(), 0, 100);
            }
            if (requestDoc.containsKey("spread")) {
                fireSpread = constrain(requestDoc["spread"].as<int>(), 0, 100);
            }
            break;

        case 4:  // Starry Night
            if (requestDoc.containsKey("sparkleRate")) {
                starrySparkleRate =
                    constrain(requestDoc["sparkleRate"].as<int>(), 0, 100);
            }
            if (requestDoc.containsKey("density")) {
                starryDensity =
                    constrain(requestDoc["density"].as<int>(), 0, 100);
            }
            break;

        case 5:  // Breathing White
            if (requestDoc.containsKey("speed")) {
                breathingSpeed =
                    constrain(requestDoc["speed"].as<int>(), 10, 100);
            }
            if (requestDoc.containsKey("hue")) {
                breathingHue = constrain(requestDoc["hue"].as<int>(), 0, 255);
            }
            break;

        case 6:  // Color Cycle
            if (requestDoc.containsKey("speed")) {
                colorCycleSpeed =
                    constrain(requestDoc["speed"].as<int>(), 1, 20);
            }
            break;

        case 7:  // Spiral Chase
            if (requestDoc.containsKey("speed")) {
                chaseSpeed = constrain(requestDoc["speed"].as<int>(), 10, 100);
            }
            if (requestDoc.containsKey("trailLength")) {
                chaseTrailLength =
                    constrain(requestDoc["trailLength"].as<int>(), 1, 6);
            }
            break;

        case 8:  // Sunset Gradient
            if (requestDoc.containsKey("shimmer")) {
                sunsetShimmer =
                    constrain(requestDoc["shimmer"].as<int>(), 0, 100);
            }
            if (requestDoc.containsKey("warmth")) {
                sunsetWarmth =
                    constrain(requestDoc["warmth"].as<int>(), 0, 100);
            }
            break;

        case 9:  // Pulse From Center
            if (requestDoc.containsKey("speed")) {
                pulseSpeed = constrain(requestDoc["speed"].as<int>(), 20, 150);
            }
            if (requestDoc.containsKey("hue")) {
                pulseHue = constrain(requestDoc["hue"].as<int>(), 0, 255);
            }
            break;

        case 10:  // Snowflake
            if (requestDoc.containsKey("sparkleRate")) {
                snowflakeSparkleRate =
                    constrain(requestDoc["sparkleRate"].as<int>(), 0, 100);
            }
            if (requestDoc.containsKey("coolness")) {
                snowflakeCoolness =
                    constrain(requestDoc["coolness"].as<int>(), 0, 100);
            }
            break;

        case 11:  // Night Light
            if (requestDoc.containsKey("dimLevel")) {
                nightLightDimLevel =
                    constrain(requestDoc["dimLevel"].as<int>(), 0, 100);
            }
            if (requestDoc.containsKey("warmth")) {
                nightLightWarmth =
                    constrain(requestDoc["warmth"].as<int>(), 0, 100);
            }
            if (requestDoc.containsKey("breathe")) {
                nightLightBreatheAmount =
                    constrain(requestDoc["breathe"].as<int>(), 0, 100);
            }
            break;

        case 12:  // Candle Flicker
            if (requestDoc.containsKey("flickerRate")) {
                candleFlickerRate =
                    constrain(requestDoc["flickerRate"].as<int>(), 10, 100);
            }
            if (requestDoc.containsKey("minBrightness")) {
                candleMinBright =
                    constrain(requestDoc["minBrightness"].as<int>(), 50, 200);
            }
            break;

        case 13:  // Aurora Borealis
            if (requestDoc.containsKey("speed")) {
                auroraSpeed = constrain(requestDoc["speed"].as<int>(), 5, 50);
            }
            if (requestDoc.containsKey("brightness")) {
                auroraBrightness =
                    constrain(requestDoc["brightness"].as<int>(), 100, 255);
            }
            if (requestDoc.containsKey("complexity")) {
                auroraComplexity =
                    constrain(requestDoc["complexity"].as<int>(), 1, 4);
            }
            if (requestDoc.containsKey("paletteIndex")) {
                auroraPaletteIndex =
                    constrain(requestDoc["paletteIndex"].as<int>(), 0, 2);
            }
            if (requestDoc.containsKey("shimmer")) {
                auroraShimmer = requestDoc["shimmer"].as<bool>();
            }
            if (requestDoc.containsKey("waveDensity")) {
                auroraWaveDensity =
                    constrain(requestDoc["waveDensity"].as<int>(), 0, 100);
            }
            break;

        case 14:  // Ocean Waves
            if (requestDoc.containsKey("speed")) {
                oceanWaveSpeed =
                    constrain(requestDoc["speed"].as<int>(), 10, 100);
            }
            if (requestDoc.containsKey("depth")) {
                oceanDepth = constrain(requestDoc["depth"].as<int>(), 0, 100);
            }
            break;

        case 15:  // Sunset Fade
            if (requestDoc.containsKey("speed")) {
                sunsetSpeed = constrain(requestDoc["speed"].as<int>(), 5, 100);
            }
            break;

        case 16:  // Meteor Shower
            if (requestDoc.containsKey("frequency")) {
                meteorSpawnRate =
                    constrain(requestDoc["frequency"].as<int>(), 5, 100);
            }
            if (requestDoc.containsKey("tailLength")) {
                meteorTailLength = constrain(
                    requestDoc["tailLength"].as<int>() / 12 + 2, 2, 8);
            }
            break;

        case 17:  // Lightning Storm
            if (requestDoc.containsKey("intensity")) {
                stormIntensity =
                    constrain(requestDoc["intensity"].as<int>(), 0, 100);
            }
            break;

        case 18:  // Ripple
            if (requestDoc.containsKey("speed")) {
                rippleSpeed = constrain(requestDoc["speed"].as<int>(), 10, 100);
            }
            if (requestDoc.containsKey("decay")) {
                rippleDecay = constrain(requestDoc["decay"].as<int>(), 20, 150);
            }
            break;

        case 19:  // Kaleidoscope
            if (requestDoc.containsKey("speed")) {
                kaleidoscopeSpeed =
                    constrain(requestDoc["speed"].as<int>(), 10, 100);
            }
            break;

        case 20:  // DNA Helix
            if (requestDoc.containsKey("speed")) {
                dnaSpeed = constrain(requestDoc["speed"].as<int>(), 10, 100);
            }
            break;

        case 21:  // Forest Breeze
            if (requestDoc.containsKey("sway")) {
                forestBreeze = constrain(requestDoc["sway"].as<int>(), 10, 100);
            }
            break;

        case 22:  // Firefly Glow
            if (requestDoc.containsKey("density")) {
                fireflyCount =
                    constrain(requestDoc["density"].as<int>() / 20 + 1, 1, 6);
            }
            if (requestDoc.containsKey("speed")) {
                fireflySpeed =
                    constrain(requestDoc["speed"].as<int>(), 10, 100);
            }
            break;

        case 23:  // Dreamy Clouds
            if (requestDoc.containsKey("speed")) {
                cloudSpeed = constrain(requestDoc["speed"].as<int>(), 5, 80);
            }
            if (requestDoc.containsKey("density")) {
                cloudDensity =
                    constrain(requestDoc["density"].as<int>(), 20, 100);
            }
            break;

        case 24:  // Lava Lamp
            if (requestDoc.containsKey("speed")) {
                lavaSpeed = constrain(requestDoc["speed"].as<int>(), 5, 60);
            }
            if (requestDoc.containsKey("blobSize")) {
                lavaBlobSize =
                    constrain(requestDoc["blobSize"].as<int>(), 20, 100);
            }
            break;

        default:
            // All other patterns don't have configurable parameters currently,
            // but we still allow switching to them
            break;
    }

    // Also switch to this pattern
    lampState.currentPattern = pattern;
    animationStep = 0;
    saveState();

    StaticJsonDocument<200> responseDoc;
    responseDoc["success"] = true;
    responseDoc["pattern"] = pattern;
    responseDoc["patternName"] = patternNames[pattern];
    responseDoc["message"] = "Pattern configuration updated";

    sendJSONResponse(200, responseDoc);
}

// Set brightness endpoint
void handleSetBrightness() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<200> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    int brightness;
    if (requestDoc.containsKey("brightnessPercent")) {
        // Accept 0-100 percentage
        int percent = requestDoc["brightnessPercent"];
        percent = constrain(percent, 0, 100);
        brightness = (percent * 255) / 100;
    } else if (requestDoc.containsKey("brightness")) {
        // Accept 0-255 raw value
        brightness = requestDoc["brightness"];
        brightness = constrain(brightness, 0, 255);
    } else {
        sendErrorResponse(400,
                          "Missing 'brightness' or 'brightnessPercent' field");
        return;
    }

    lampState.brightness = brightness;
    FastLED.setBrightness(brightness);
    saveState();

    StaticJsonDocument<200> responseDoc;
    responseDoc["success"] = true;
    responseDoc["brightness"] = brightness;
    responseDoc["brightnessPercent"] = (brightness * 100) / 255;

    sendJSONResponse(200, responseDoc);
}

// Set reading light warmth endpoint
void handleSetReadingWarmth() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<200> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!requestDoc.containsKey("warmth")) {
        sendErrorResponse(400, "Missing 'warmth' field");
        return;
    }

    int warmth = requestDoc["warmth"];
    warmth = constrain(warmth, 0, 100);

    lampState.readingWarmth = warmth;
    saveState();

    StaticJsonDocument<200> responseDoc;
    responseDoc["success"] = true;
    responseDoc["warmth"] = warmth;

    sendJSONResponse(200, responseDoc);
}

// Power on/off endpoint
void handleSetPower() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<200> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!requestDoc.containsKey("on")) {
        sendErrorResponse(400, "Missing 'on' field");
        return;
    }

    lampState.isOn = requestDoc["on"];
    saveState();

    StaticJsonDocument<200> responseDoc;
    responseDoc["success"] = true;
    responseDoc["isOn"] = lampState.isOn;

    sendJSONResponse(200, responseDoc);
}

// Set custom RGB color endpoint
void handleSetCustomColor() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<200> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!requestDoc.containsKey("r") || !requestDoc.containsKey("g") ||
        !requestDoc.containsKey("b")) {
        sendErrorResponse(400, "Missing RGB values");
        return;
    }

    lampState.customRed = constrain((int)requestDoc["r"], 0, 255);
    lampState.customGreen = constrain((int)requestDoc["g"], 0, 255);
    lampState.customBlue = constrain((int)requestDoc["b"], 0, 255);
    lampState.customHue = 0;
    lampState.customSaturation = 0;

    // Switch to custom color pattern
    lampState.currentPattern = 14;
    saveState();

    StaticJsonDocument<200> responseDoc;
    responseDoc["success"] = true;
    responseDoc["r"] = lampState.customRed;
    responseDoc["g"] = lampState.customGreen;
    responseDoc["b"] = lampState.customBlue;
    responseDoc["pattern"] = "Custom Color";

    sendJSONResponse(200, responseDoc);
}

// Set color via color wheel (HSV) endpoint
void handleSetColorWheel() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<200> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    // Accept hue (0-360 degrees) and saturation (0-100%)
    if (!requestDoc.containsKey("hue")) {
        sendErrorResponse(400, "Missing 'hue' field");
        return;
    }

    // Convert from degrees (0-360) to byte (0-255)
    int hueDegrees = requestDoc["hue"];
    hueDegrees = constrain(hueDegrees, 0, 360);
    lampState.customHue = (hueDegrees * 255) / 360;

    // Saturation: 0-100% to 0-255
    if (requestDoc.containsKey("saturation")) {
        int satPercent = requestDoc["saturation"];
        satPercent = constrain(satPercent, 0, 100);
        lampState.customSaturation = (satPercent * 255) / 100;
    } else {
        lampState.customSaturation = 255;
    }

    // Reset RGB values when using wheel
    lampState.customRed = 0;
    lampState.customGreen = 0;
    lampState.customBlue = 0;

    // Switch to custom color pattern
    lampState.currentPattern = 14;
    saveState();

    StaticJsonDocument<200> responseDoc;
    responseDoc["success"] = true;
    responseDoc["hue"] = hueDegrees;
    responseDoc["saturation"] = requestDoc.containsKey("saturation")
                                    ? (int)requestDoc["saturation"]
                                    : 100;
    responseDoc["pattern"] = "Custom Color";

    sendJSONResponse(200, responseDoc);
}

// Configure WiFi credentials endpoint
void handleSetWiFi() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<300> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!requestDoc.containsKey("ssid") ||
        !requestDoc.containsKey("password")) {
        sendErrorResponse(400, "Missing 'ssid' or 'password' field");
        return;
    }

    lampState.wifiSSID = requestDoc["ssid"].as<String>();
    lampState.wifiPassword = requestDoc["password"].as<String>();
    saveState();

    StaticJsonDocument<200> responseDoc;
    responseDoc["success"] = true;
    responseDoc["message"] = "WiFi credentials saved. Restarting...";
    responseDoc["newSSID"] = lampState.wifiSSID;

    sendJSONResponse(200, responseDoc);

    // Restart after sending response
    delay(1000);
    ESP.restart();
}

// Scan WiFi networks endpoint
void handleScanWiFi() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    Serial.println("Scanning WiFi networks...");
    int numNetworks = WiFi.scanNetworks();

    StaticJsonDocument<2048> doc;
    doc["success"] = true;
    doc["count"] = numNetworks;

    JsonArray networks = doc.createNestedArray("networks");

    for (int i = 0; i < numNetworks && i < 20; i++) {
        JsonObject net = networks.createNestedObject();
        net["ssid"] = WiFi.SSID(i);
        net["rssi"] = WiFi.RSSI(i);
        net["secure"] = WiFi.encryptionType(i) != WIFI_AUTH_OPEN;
        net["channel"] = WiFi.channel(i);
    }

    WiFi.scanDelete();

    sendJSONResponse(200, doc);
}

// Set Gyro mode endpoint
void handleSetGyro() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "No body provided");
        return;
    }

    StaticJsonDocument<200> requestDoc;
    DeserializationError error =
        deserializeJson(requestDoc, server.arg("plain"));

    if (error) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    // Check if MPU6050 is available
    if (!mpuInitialized) {
        sendErrorResponse(503, "MPU6050 not available");
        return;
    }

    // Handle enable/disable
    if (requestDoc.containsKey("enabled")) {
        lampState.gyroEnabled = requestDoc["enabled"];
    }

    // Handle pattern change
    if (requestDoc.containsKey("pattern")) {
        int pattern = requestDoc["pattern"];
        if (pattern >= 0 && pattern < NUM_GYRO_PATTERNS) {
            lampState.gyroPattern = pattern;
        } else {
            sendErrorResponse(400, "Gyro pattern out of range");
            return;
        }
    }

    saveState();

    StaticJsonDocument<512> responseDoc;
    responseDoc["success"] = true;
    responseDoc["gyroEnabled"] = lampState.gyroEnabled;
    responseDoc["gyroPattern"] = lampState.gyroPattern;
    responseDoc["gyroPatternName"] = gyroPatternNames[lampState.gyroPattern];
    responseDoc["mpuAvailable"] = mpuInitialized;

    // Include current sensor data if enabled
    if (lampState.gyroEnabled && mpuInitialized) {
        JsonObject sensor = responseDoc.createNestedObject("sensor");
        sensor["pitch"] = gyroState.pitch;
        sensor["roll"] = gyroState.roll;
        sensor["gesture"] = gyroState.currentGesture;
    }

    sendJSONResponse(200, responseDoc);
}

// Get Gyro status endpoint
void handleGetGyroStatus() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    StaticJsonDocument<768> doc;
    doc["success"] = true;
    doc["mpuAvailable"] = mpuInitialized;
    doc["gyroEnabled"] = lampState.gyroEnabled;
    doc["gyroPattern"] = lampState.gyroPattern;
    doc["gyroPatternName"] = gyroPatternNames[lampState.gyroPattern];
    doc["numGyroPatterns"] = NUM_GYRO_PATTERNS;

    // Sensor data
    if (mpuInitialized) {
        JsonObject sensor = doc.createNestedObject("sensor");
        sensor["pitch"] = gyroState.pitch;
        sensor["roll"] = gyroState.roll;
        sensor["accX"] = gyroState.accX;
        sensor["accY"] = gyroState.accY;
        sensor["accZ"] = gyroState.accZ;
        sensor["gyroX"] = gyroState.gyroX;
        sensor["gyroY"] = gyroState.gyroY;
        sensor["gyroZ"] = gyroState.gyroZ;
    }

    // Gesture state
    JsonObject gesture = doc.createNestedObject("gesture");
    gesture["current"] = gyroState.currentGesture;
    gesture["isShaking"] = gyroState.isShaking;
    gesture["isTilted"] = gyroState.isTilted;
    gesture["isFlipped"] = gyroState.isFlipped;
    gesture["tiltDirection"] = gyroState.tiltDirection;
    gesture["shakeCount"] = gyroState.shakeCount;

    JsonObject cal = doc.createNestedObject("calibration");
    cal["valid"] = calibration.valid;
    cal["pitchOffset"] = calibration.pitchOffset;
    cal["rollOffset"] = calibration.rollOffset;
    cal["pitchScale"] = calibration.pitchScale;
    cal["rollScale"] = calibration.rollScale;

    // List gyro patterns
    JsonArray patterns = doc.createNestedArray("patterns");
    for (int i = 0; i < NUM_GYRO_PATTERNS; i++) {
        JsonObject p = patterns.createNestedObject();
        p["id"] = i;
        p["name"] = gyroPatternNames[i];
        p["active"] = (i == lampState.gyroPattern);
    }

    sendJSONResponse(200, doc);
}

// Guided calibration endpoint
void handleGyroCalibration() {
    if (!validateAuth()) {
        sendErrorResponse(401, "Unauthorized");
        return;
    }

    if (!mpuInitialized) {
        sendErrorResponse(503, "MPU6050 not available");
        return;
    }

    // Always refresh a reading for latest pose
    mpu.update();
    float rawPitch = mpu.getAngleX();
    float rawRoll = mpu.getAngleY();

    // Handle GET as status query
    if (server.method() == HTTP_GET) {
        StaticJsonDocument<512> doc;
        doc["success"] = true;
        JsonObject cal = doc.createNestedObject("calibration");
        cal["valid"] = calibration.valid;
        cal["pitchOffset"] = calibration.pitchOffset;
        cal["rollOffset"] = calibration.rollOffset;
        cal["pitchScale"] = calibration.pitchScale;
        cal["rollScale"] = calibration.rollScale;

        JsonObject capture = doc.createNestedObject("capture");
        capture["center"] = calCapture.centerSet;
        capture["left"] = calCapture.leftSet;
        capture["right"] = calCapture.rightSet;
        capture["front"] = calCapture.frontSet;
        capture["back"] = calCapture.backSet;
        capture["next"] = (!calCapture.centerSet)  ? "center"
                          : (!calCapture.leftSet)  ? "left"
                          : (!calCapture.rightSet) ? "right"
                          : (!calCapture.frontSet) ? "front"
                          : (!calCapture.backSet)  ? "back"
                                                   : "done";

        JsonObject sensor = doc.createNestedObject("sensor");
        sensor["rawPitch"] = rawPitch;
        sensor["rawRoll"] = rawRoll;

        sendJSONResponse(200, doc);
        return;
    }

    if (!server.hasArg("plain")) {
        sendErrorResponse(400, "Missing body");
        return;
    }

    StaticJsonDocument<256> req;
    DeserializationError err = deserializeJson(req, server.arg("plain"));
    if (err) {
        sendErrorResponse(400, "Invalid JSON");
        return;
    }

    if (!req.containsKey("step")) {
        sendErrorResponse(400, "Missing step");
        return;
    }

    String step = req["step"].as<String>();
    step.toLowerCase();

    if (step == "reset") {
        resetCalibrationCapture();
        calibration.valid = false;
        calibration.pitchOffset = 0;
        calibration.rollOffset = 0;
        calibration.pitchScale = 1;
        calibration.rollScale = 1;
        saveCalibrationData();

        StaticJsonDocument<192> doc;
        doc["success"] = true;
        doc["message"] = "Calibration reset";
        sendJSONResponse(200, doc);
        return;
    }

    // Record the current pose for the requested step
    if (step == "center") {
        calCapture.centerSet = true;
        calCapture.centerPitch = rawPitch;
        calCapture.centerRoll = rawRoll;
    } else if (step == "left") {
        calCapture.leftSet = true;
        calCapture.leftRoll = rawRoll;
    } else if (step == "right") {
        calCapture.rightSet = true;
        calCapture.rightRoll = rawRoll;
    } else if (step == "front") {
        calCapture.frontSet = true;
        calCapture.frontPitch = rawPitch;
    } else if (step == "back") {
        calCapture.backSet = true;
        calCapture.backPitch = rawPitch;
    } else {
        sendErrorResponse(400, "Unknown step");
        return;
    }

    // If all steps captured, compute calibration
    String next = (!calCapture.centerSet)  ? "center"
                  : (!calCapture.leftSet)  ? "left"
                  : (!calCapture.rightSet) ? "right"
                  : (!calCapture.frontSet) ? "front"
                  : (!calCapture.backSet)  ? "back"
                                           : "done";

    if (next == "done") {
        computeCalibration();
    }

    StaticJsonDocument<512> resp;
    resp["success"] = true;
    resp["capturedStep"] = step;
    resp["nextStep"] = next;
    resp["calibrationValid"] = calibration.valid;
    resp["pitchOffset"] = calibration.pitchOffset;
    resp["rollOffset"] = calibration.rollOffset;
    resp["pitchScale"] = calibration.pitchScale;
    resp["rollScale"] = calibration.rollScale;

    JsonObject capture = resp.createNestedObject("capture");
    capture["center"] = calCapture.centerSet;
    capture["left"] = calCapture.leftSet;
    capture["right"] = calCapture.rightSet;
    capture["front"] = calCapture.frontSet;
    capture["back"] = calCapture.backSet;

    sendJSONResponse(200, resp);
}

// 404 handler
void handleNotFound() { sendErrorResponse(404, "Endpoint not found"); }

