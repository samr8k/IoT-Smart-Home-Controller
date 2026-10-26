# IoT Smart Home Controller

> **Universal Flutter Application for ESP32-based IoT Devices**  
> Control smart lamps and smart locks from anywhere with automatic device discovery

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey.svg)](https://flutter.dev/)

---

## 📱 Features

### Smart Lamp Control

- **15+ Built-in Lighting Patterns**: Fire, Rainbow, Aurora Borealis, Ocean Waves, Candle Flicker, and more
- **Gyroscope Motion Control**: 10 motion-reactive patterns using MPU6050 sensor
- **Per-Pattern Configuration**: Adjust speed, intensity, colors, and effects
- **Custom Color Control**: RGB and HSV color wheel picker
- **Brightness Control**: 0-255 levels with real-time adjustment
- **Touch Sensor Support**: Physical button to cycle patterns

### Smart Lock Control

- **RFID Card Authentication**: MFRC522 reader support
- **Remote Control**: Unlock/lock via mobile app
- **Entry Logging**: Track access attempts with timestamps
- **Card Management**: Add/remove authorized RFID cards
- **LED Status Indicator**: Visual feedback for lock status
- **Auto-lock**: Configurable 5-second timeout

### Universal Features

- **Automatic Device Discovery**: mDNS/Bonjour service discovery
- **Secure Authentication**: Token-based API authentication
- **WiFi Configuration**: Change network settings via app
- **OTA Updates**: Over-the-air firmware updates for ESP32
- **Cross-Platform**: Android, iOS, Web, Windows, macOS, Linux

---

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK** 3.10 or higher ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **ESP32-C3 Development Board** (or compatible ESP32 board)
- **Arduino IDE** or **PlatformIO** for firmware upload
- **Android Studio** / **Xcode** / **VS Code** for mobile development

### 1. Hardware Setup

#### Smart Lamp Requirements

- **ESP32-C3 Mini** (or any ESP32 board)
- **WS2812B LED Strip** (21 LEDs recommended, configurable)
- **MPU6050 Gyroscope** (optional, for motion control)
- **Touch Sensor Module** (optional)

#### Smart Lock Requirements

- **ESP32-C3** (or any ESP32 board)
- **MFRC522 RFID Reader**
- **Relay Module** (5V)
- **WS2812B LED** (1 LED for status)
- **RFID Cards/Tags**

### 2. Pin Configuration

#### Smart Lamp Wiring

```
ESP32-C3          Component
GPIO 6      →     WS2812B Data In
GPIO 8      →     MPU6050 SDA
GPIO 9      →     MPU6050 SCL
GPIO A3     →     Touch Sensor Out
3.3V        →     MPU6050 VCC, Touch Sensor VCC
5V          →     WS2812B Power (use external supply for >10 LEDs)
GND         →     All Components GND
```

#### Smart Lock Wiring

```
ESP32-C3          Component
GPIO 7      →     MFRC522 SS/SDA
GPIO 10     →     MFRC522 RST
GPIO 4      →     MFRC522 SCK
GPIO 5      →     MFRC522 MISO
GPIO 6      →     MFRC522 MOSI
GPIO 2      →     Relay Signal
GPIO 3      →     WS2812B Data In
3.3V        →     MFRC522 VCC
5V          →     Relay VCC, WS2812B Power
GND         →     All Components GND
```

### 3. Install Firmware

#### Step 1: Install Required Libraries

Open Arduino IDE and install these libraries via Library Manager:

- **FastLED** (for WS2812B LEDs)
- **MPU6050_light** (for gyroscope)
- **MFRC522** (for RFID reader)
- **ArduinoJson** (v6+)
- **Adafruit NeoPixel**
- **Preferences** (built-in)
- **WiFi** (built-in)
- **ESPmDNS** (built-in)
- **WebServer** (built-in)

#### Step 2: Configure WiFi & Authentication

Edit the firmware files before uploading:

**`firmware/smart_lamp/smart_lamp.ino`** (Lines 136-140):

```cpp
// WiFi Credentials
const char* DEFAULT_SSID = "Your_WiFi_SSID";          // Change this
const char* DEFAULT_PASSWORD = "Your_WiFi_Password";  // Change this

// Device Authentication (required for app access)
const char* LAMP_PASSWORD = "your_secure_password";   // Change this!
const char* LAMP_ID = "SmartLamp001";                 // Unique lamp ID
```

**`firmware/smart_lock/smart_lock.ino`** (Lines 65-73):

```cpp
// WiFi Credentials
const char* DEFAULT_SSID = "Your_WiFi_SSID";          // Change this
const char* DEFAULT_PASSWORD = "Your_WiFi_Password";  // Change this

// Device Authentication
const char* LOCK_PASSWORD = "your_secure_password";   // Change this!

// Initial Authorized RFID Cards (get UIDs by scanning cards first)
const String INITIAL_CARDS[] = {"CARD_UID_1", "CARD_UID_2"};
```

> **💡 Tip**: To get RFID card UIDs, upload the firmware with empty INITIAL_CARDS array, open Serial Monitor (115200 baud), and scan your cards. The UIDs will be printed.

#### Step 3: Upload Firmware

1. Connect ESP32 to computer via USB
2. Select **Board**: Tools → Board → ESP32 Arduino → **ESP32C3 Dev Module**
3. Select **Port**: Tools → Port → (your ESP32 COM port)
4. Click **Upload** button
5. Wait for "Done uploading" message
6. Open **Serial Monitor** (115200 baud) to see device IP address

### 4. Install Flutter App

#### Clone & Setup

```bash
# Clone repository
git clone https://github.com/yourusername/iot_devices.git
cd iot_devices

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

#### Build for Production

```bash
# Android APK
flutter build apk --release

# iOS (requires macOS and Xcode)
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

---

## 📖 Usage Guide

### First-Time Setup

1. **Power on your IoT device** (Lamp or Lock)
2. **Check Serial Monitor** to get the device IP address:

   ```
   WiFi Connected!
   IP Address: 192.168.1.100
   mDNS: smartlamp-001.local
   ```

3. **Launch the Flutter app** on your phone/computer
4. The app will **automatically discover** devices on your network
5. **Tap on a discovered device** to connect
6. **Enter the device password** (set in firmware)
7. Start controlling your devices!

### Manual Device Addition

If automatic discovery doesn't work:

1. Tap **"+ Add Device"**
2. Select device type (Lamp or Lock)
3. Enter device details:
   - **Name**: Friendly name (e.g., "Living Room Lamp")
   - **IP Address**: From Serial Monitor (e.g., `192.168.1.100`)
   - **Password**: Password set in firmware
4. Tap **"Add Device"**

### Smart Lamp Usage

#### Pattern Selection

- **Browse patterns**: Scroll through pattern tiles
- **Quick toggle**: Tap power button on pattern tile
- **Configure pattern**: Tap pattern tile → Adjust sliders
- **Color wheel**: Select "Custom Color" pattern → Pick color
- **Brightness**: Use brightness slider (0-100%)

#### Gyroscope Mode (MPU6050 Required)

1. **Enable Gyro**: Toggle "Motion Control" switch
2. **Select gyro pattern**:
   - **Fluid Tilt**: Water-like movement responds to tilting
   - **Shake Sparkle**: Shake lamp for dramatic sparkles
   - **Motion Rainbow**: Rainbow follows your movements
   - **Tilt Brightness**: Tilt to adjust brightness
   - And 6 more patterns!

3. **Calibrate gyro** (one-time setup):
   - Go to Settings → Gyro Calibration
   - Follow on-screen instructions (5 positions)

#### Popular Patterns

- **Night Reading**: Warm adjustable light for reading (0-100% warmth)
- **Aurora Borealis**: Stunning northern lights with shimmer
- **Fire Effect**: Realistic flames (adjustable intensity/calmness)
- **Ocean Waves**: Relaxing wave motion (adjustable speed/depth)
- **Candle Flicker**: Realistic candle simulation
- **Snowflake**: Cool white sparkles

### Smart Lock Usage

#### Unlock/Lock

- **Tap "Unlock"**: Activates relay for 5 seconds
- **Tap "Lock"**: Immediately deactivates relay
- **RFID Card**: Present authorized card to reader
- **Auto-lock**: Relay automatically turns off after 5 seconds

#### Card Management

1. **View Cards**: Go to "Authorized Cards" tab
2. **Add Card**:
   - Scan a new RFID card on the reader
   - Get UID from Serial Monitor
   - Tap "+ Add Card" in app
   - Enter UID and label
3. **Remove Card**: Tap card → "Remove"

#### Entry Logs

- **View logs**: "Entry Logs" tab shows recent accesses
- **Filter**: By date, card, or access result
- **Export**: Download as CSV or PDF
- **Clear logs**: Settings → Clear Entry Logs

---

## 🔧 Configuration

### Device Configuration

#### Change WiFi Network (via App)

1. Connect to device
2. Go to Settings → WiFi Configuration
3. Tap "Scan Networks"
4. Select network → Enter password
5. Device will restart and connect

#### OTA Updates

Firmware supports Over-The-Air updates:

```cpp
// In Arduino IDE: Sketch → Export compiled Binary
// Upload via: Tools → Port → smartlamp-001 at 192.168.1.100 (OTA)
```

### Pattern Configuration (Smart Lamp)

Each pattern has unique settings accessible in the app:

| Pattern         | Configurable Parameters                                                         |
| --------------- | ------------------------------------------------------------------------------- |
| Night Reading   | Warmth (0-100), Yellowness (0-100), Brightness                                  |
| Fire Effect     | Calmness (0-100), Intensity (0-100), Spread (0-100)                             |
| Aurora Borealis | Speed, Brightness, Complexity (1-4), Wave Density, Shimmer, Palette (3 options) |
| Ocean Waves     | Speed (10-100), Depth (0-100)                                                   |
| Rainbow Spiral  | Speed (1-50), Reverse Direction                                                 |
| Starry Night    | Sparkle Rate (0-100), Star Density (0-100)                                      |
| Candle Flicker  | Flicker Rate (10-100), Min Brightness (50-200)                                  |
| Snowflake       | Sparkle Rate (0-100), Coolness (0-100 blue tint)                                |

### API Endpoints

#### Smart Lamp API

```
Base URL: http://<device_ip>/

POST /api/auth
  Body: { "password": "your_password" }
  Returns: { "token": "..." }

GET /api/status
  Headers: Authorization: Bearer <token>
  Returns: Device status, patterns, gyro data

POST /api/pattern
  Body: { "pattern": 0-25 }
  Set lighting pattern

POST /api/brightness
  Body: { "brightness": 0-255 } or { "brightnessPercent": 0-100 }

POST /api/power
  Body: { "on": true/false }

POST /api/color
  Body: { "r": 0-255, "g": 0-255, "b": 0-255 }

POST /api/colorwheel
  Body: { "hue": 0-360, "saturation": 0-100 }

POST /api/gyro
  Body: { "enabled": true/false, "pattern": 0-9 }

GET /api/patterns
  Returns: List of all patterns
```

#### Smart Lock API

```
Base URL: http://<device_ip>/

GET /api/status
  Returns: Lock status, entry logs

POST /api/unlock
  Unlock for 5 seconds

POST /api/lock
  Force lock immediately

POST /api/add-card
  Body: { "uid": "CARD_UID" }

POST /api/remove-card
  Body: { "uid": "CARD_UID" }

GET /api/cards
  Returns: List of authorized cards (masked)

GET /api/logs/csv
  Export entry logs as CSV
```

---

## 🛠️ Troubleshooting

### Device Not Discovered

1. **Check WiFi**: Ensure ESP32 and phone are on the same network
2. **Check IP**: Use Serial Monitor to verify device got IP address
3. **Firewall**: Temporarily disable firewall/antivirus
4. **Manual Add**: Add device manually using IP address

### WiFi Connection Failed

1. **Check Credentials**: Verify SSID and password in firmware
2. **Signal Strength**: Move device closer to router
3. **2.4GHz Only**: ESP32 only supports 2.4GHz WiFi (not 5GHz)
4. **AP Mode**: Device creates "SmartLamp_Setup" WiFi if connection fails

### LEDs Not Working

1. **Power Supply**: WS2812B needs 5V, check connections
2. **Current Limit**: Use external 5V supply for >10 LEDs (1A per 20 LEDs)
3. **Data Pin**: Verify GPIO 6 connection
4. **LED Count**: Check `#define NUM_LEDS 21` matches your strip

### RFID Not Reading

1. **Wiring**: Double-check all 6 SPI connections
2. **Power**: MFRC522 needs 3.3V (not 5V!)
3. **Distance**: Hold card within 2-3cm of reader
4. **Serial Monitor**: Check for "Card Detected" messages

### Gyroscope Not Working

1. **MPU6050 Detected**: Check Serial Monitor for "MPU6050 connected successfully!"
2. **I2C Address**: Default 0x68, ensure no conflicts
3. **Calibration**: Perform gyro calibration in app
4. **Power**: MPU6050 needs 3.3V or 5V

### App Connection Issues

1. **Token Expired**: Tokens last 1 hour, re-authenticate
2. **Password**: Ensure password matches firmware
3. **Network Change**: Device IP may change, re-discover
4. **Restart**: Restart both ESP32 and app

---

## 📚 Advanced Topics

### Custom LED Layouts

To use a different number of LEDs, edit firmware:

```cpp
// In smart_lamp.ino, line 67
#define NUM_LEDS 21  // Change to your LED count
```

For different LED layouts (not spiral), modify:

```cpp
// Lines 105-133: LED layout indices
// Update pattern functions to match your layout
```

### Adding New Patterns

1. Add pattern name to `patternNames[]` array
2. Increment `NUM_PATTERNS`
3. Add function: `void patternMyPattern() { ... }`
4. Add case to `updateLEDs()` switch statement
5. Upload firmware

Example:

```cpp
void patternMyPattern() {
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = CHSV(hueOffset + i * 10, 255, 255);
    }
    hueOffset++;
}
```

### Custom RFID Card Labels

Edit `getCardLabel()` function in `smart_lock.ino`:

```cpp
String getCardLabel(const String& uid) {
    if (uid == "YOUR_UID") return "Front Door Key";
    if (uid == "ANOTHER_UID") return "Backup Card";
    return "Unknown Card";
}
```

### Flutter App Customization

#### Change Theme Colors

Edit `lib/main.dart`:

```dart
theme: ThemeData(
  primarySwatch: Colors.blue,  // Change to your color
  brightness: Brightness.dark,
),
```

#### Add Custom Device Types

1. Create model in `lib/models/`
2. Add service in `lib/services/`
3. Create screens in `lib/screens/`
4. Update discovery in `lib/services/discovery_service.dart`

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **FastLED Library** - High-performance LED control
- **ArduinoJson** - Efficient JSON parsing
- **Flutter Team** - Amazing cross-platform framework
- **ESP32 Community** - Hardware support and examples

---

