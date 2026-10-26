# 🚀 Quick Start Guide

Get your IoT devices up and running in **10 minutes**!

## What You Need

### Hardware

- ✅ ESP32-C3 (or any ESP32 board)
- ✅ USB-C cable (for programming)
- ✅ For Smart Lamp:
  - WS2812B LED strip (any length, 21 LEDs recommended)
  - MPU6050 gyroscope (optional)
  - Touch sensor module (optional)
- ✅ For Smart Lock:
  - MFRC522 RFID reader
  - Relay module (5V)
  - WS2812B LED (1 LED)
  - RFID cards/tags

### Software

- ✅ Arduino IDE 1.8.19 or newer ([Download](https://www.arduino.cc/en/software))
- ✅ ESP32 board support ([Setup Guide](https://docs.espressif.com/projects/arduino-esp32/en/latest/installing.html))
- ✅ Flutter SDK 3.10+ ([Download](https://flutter.dev/docs/get-started/install))

---

## Step 1: Install Arduino Libraries (5 minutes)

Open Arduino IDE → Tools → Manage Libraries, then install:

1. **FastLED** (by Daniel Garcia)
2. **MPU6050_light** (by rfetick) - for lamp only
3. **MFRC522** (by GithubCommunity) - for lock only
4. **ArduinoJson** (by Benoit Blanchon) - version 6+
5. **Adafruit NeoPixel** (by Adafruit)

Click "Install All" if prompted for dependencies.

---

## Step 2: Get Device UIDs (Smart Lock Only)

Before configuring the lock, you need your RFID card UIDs:

### Get Card UIDs

1. **Wire RFID reader** to ESP32 (see pin table below)
2. Open `firmware/smart_lock/smart_lock.ino`
3. **Comment out the initial cards**:
   ```cpp
   const String INITIAL_CARDS[] = {};  // Empty array
   const int NUM_INITIAL_CARDS = 0;
   ```
4. Upload to ESP32
5. Open Serial Monitor (115200 baud)
6. **Scan your RFID cards** - UIDs will appear like: `UID: A1653B1D`
7. **Write down the UIDs** - you'll need them in Step 3

---

## Step 3: Configure Firmware (3 minutes)

### Smart Lamp Configuration

Edit **`firmware/smart_lamp/smart_lamp.ino`** at lines 136-140:

```cpp
// REPLACE THESE WITH YOUR INFO:
const char* DEFAULT_SSID = "YourWiFiName";          // Your WiFi name
const char* DEFAULT_PASSWORD = "YourWiFiPassword";  // Your WiFi password
const char* LAMP_PASSWORD = "lamp123";              // Choose a password for app
const char* LAMP_ID = "BedroomLamp";                // Give it a name
```

### Smart Lock Configuration

Edit **`firmware/smart_lock/smart_lock.ino`** at lines 65-73:

```cpp
// REPLACE THESE WITH YOUR INFO:
const char* DEFAULT_SSID = "YourWiFiName";          // Your WiFi name
const char* DEFAULT_PASSWORD = "YourWiFiPassword";  // Your WiFi password
const char* LOCK_PASSWORD = "lock456";              // Choose a password for app

// USE THE UIDs FROM STEP 2:
const String INITIAL_CARDS[] = {"A1653B1D", "F9FA8E14"};  // Your card UIDs
const int NUM_INITIAL_CARDS = 2;  // Number of cards
```

---

## Step 4: Wire the Hardware (2 minutes)

### Smart Lamp Wiring

| ESP32-C3 Pin | Component              | Notes                                |
| ------------ | ---------------------- | ------------------------------------ |
| **GPIO 6**   | LED Strip Data         | Din pin on WS2812B                   |
| **GPIO 8**   | MPU6050 SDA            | Optional (gyro)                      |
| **GPIO 9**   | MPU6050 SCL            | Optional (gyro)                      |
| **GPIO A3**  | Touch Sensor           | Optional                             |
| **3.3V**     | MPU6050 VCC, Touch VCC |                                      |
| **5V**       | LED Strip Power        | Use external 5V supply for >10 LEDs! |
| **GND**      | All GND pins           | Common ground                        |

> **⚠️ Important**: For more than 10 LEDs, use an **external 5V power supply** (not USB). Each LED draws ~60mA at full brightness.

### Smart Lock Wiring

| ESP32-C3 Pin | Component            | Notes           |
| ------------ | -------------------- | --------------- |
| **GPIO 7**   | RFID SS/SDA          | SPI chip select |
| **GPIO 10**  | RFID RST             | Reset pin       |
| **GPIO 4**   | RFID SCK             | SPI clock       |
| **GPIO 5**   | RFID MISO            | SPI data (in)   |
| **GPIO 6**   | RFID MOSI            | SPI data (out)  |
| **GPIO 2**   | Relay Signal         | Controls relay  |
| **GPIO 3**   | LED Data             | Status LED      |
| **3.3V**     | RFID VCC             | **NOT 5V!**     |
| **5V**       | Relay VCC, LED Power |                 |
| **GND**      | All GND pins         | Common ground   |

> **⚠️ Warning**: MFRC522 uses **3.3V**, not 5V!

---

## Step 5: Upload Firmware (2 minutes)

1. **Connect ESP32** to computer via USB
2. **Select board**: Tools → Board → ESP32 Arduino → **ESP32C3 Dev Module**
3. **Select port**: Tools → Port → COM3 (or your ESP32 port)
4. **Click Upload** (arrow button) ▶️
5. **Wait** for "Done uploading"

### Check It Works

1. Open **Serial Monitor** (magnifying glass icon)
2. Set baud rate to **115200**
3. You should see:
   ```
   WiFi Connected!
   IP Address: 192.168.1.100
   Smart Lamp Ready!
   ```
4. **Write down the IP address** - you'll need it!

### If WiFi Fails

Device will create hotspot: **SmartLamp_Setup** / **SmartLock_Setup**

- Password: `setup1234`
- Connect to it and configure WiFi via app

---

## Step 6: Install Flutter App (2 minutes)

### Option A: Use Pre-built APK (Fastest)

1. Download `app-release.apk` from [Releases](https://github.com/yourusername/iot_devices/releases)
2. Install on Android phone
3. Open app

### Option B: Build from Source

```bash
# Clone repository
git clone https://github.com/yourusername/iot_devices.git
cd iot_devices

# Get dependencies
flutter pub get

# Connect phone via USB and run
flutter run
```

---

## Step 7: Connect Devices (1 minute)

### Automatic Discovery (Recommended)

1. Open app
2. Wait 5 seconds - devices appear automatically
3. Tap device → Enter password (from Step 3)
4. ✅ Done!

### Manual Setup

If auto-discovery doesn't work:

1. Tap "+" button
2. Select device type (Lamp/Lock)
3. Enter:
   - **Name**: "Living Room Lamp"
   - **IP**: `192.168.1.100` (from Step 5)
   - **Password**: `lamp123` (from Step 3)
4. Tap "Add"

---

## 🎉 You're Done!

### Test Smart Lamp

- ✅ Tap power button - LEDs should turn on/off
- ✅ Select a pattern - watch the colors!
- ✅ Adjust brightness slider
- ✅ Try gyro mode (if MPU6050 installed)

### Test Smart Lock

- ✅ Tap "Unlock" - relay should click for 5 seconds
- ✅ Scan RFID card - should unlock
- ✅ Check entry logs

---

## Common Issues

### "Device Not Found"

✅ Both phone and ESP32 on same WiFi  
✅ Check firewall isn't blocking port 80  
✅ Try manual add with IP address

### "WiFi Connection Failed" on ESP32

✅ Double-check SSID and password (case-sensitive!)  
✅ ESP32 only works with 2.4GHz WiFi (not 5GHz)  
✅ Move closer to router

### LEDs Don't Light Up

✅ Check 5V power supply  
✅ Verify data pin (GPIO 6)  
✅ For >10 LEDs, use external 5V power (not USB)

### RFID Doesn't Scan

✅ MFRC522 must use 3.3V (not 5V!)  
✅ Check all 6 SPI wire connections  
✅ Hold card within 2-3cm of reader

---

## Next Steps

📖 Read the [Full README](README.md) for:

- Detailed API documentation
- Advanced configuration
- Adding custom patterns
- Gyroscope calibration
- OTA updates

💡 **Have fun controlling your smart home!**
