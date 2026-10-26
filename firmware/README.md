# Firmware Documentation

This folder contains firmware for ESP32-based IoT devices.

## Directory Structure

```
firmware/
├── smart_lamp/
│   └── smart_lamp.ino       # Smart lamp firmware with 25+ patterns
└── smart_lock/
    └── smart_lock.ino       # Smart RFID lock firmware
```

## Required Libraries

Install these libraries via Arduino IDE Library Manager:

### Common Libraries (Both Devices)

- **ArduinoJson** (v6+) - JSON parsing for API
- **Adafruit NeoPixel** - WS2812B LED control
- **WiFi** (built-in) - Network connectivity
- **ESPmDNS** (built-in) - Device discovery
- **WebServer** (built-in) - HTTP API server
- **Preferences** (built-in) - Persistent storage

### Smart Lamp Only

- **FastLED** - High-performance LED effects
- **MPU6050_light** - Gyroscope control (optional)

### Smart Lock Only

- **MFRC522** - RFID reader support
- **SPI** (built-in) - RFID communication

## Configuration

### Before Upload - IMPORTANT!

**⚠️ You MUST change these values in the firmware:**

#### Smart Lamp (`smart_lamp.ino`, lines 136-140)

```cpp
const char* DEFAULT_SSID = "Your_WiFi_SSID";          // Change this!
const char* DEFAULT_PASSWORD = "Your_WiFi_Password";  // Change this!
const char* LAMP_PASSWORD = "your_secure_password";   // Change this!
const char* LAMP_ID = "SmartLamp001";                 // Give it a unique name
```

#### Smart Lock (`smart_lock.ino`, lines 65-73)

```cpp
const char* DEFAULT_SSID = "Your_WiFi_SSID";          // Change this!
const char* DEFAULT_PASSWORD = "Your_WiFi_Password";  // Change this!
const char* LOCK_PASSWORD = "your_secure_password";   // Change this!

// Get UIDs by scanning cards first (see Quick Start guide)
const String INITIAL_CARDS[] = {"CARD_UID_1", "CARD_UID_2"};
const int NUM_INITIAL_CARDS = 2;
```

### LED Configuration

To change the number of LEDs in the lamp:

**`smart_lamp.ino`, line 67:**

```cpp
#define NUM_LEDS 21  // Change to your LED count
```

### Pin Configuration

Pins are defined at the top of each firmware file:

**Smart Lamp:**

```cpp
#define LED_PIN 6     // WS2812B data pin
#define MPU_SDA 8     // Gyroscope SDA (optional)
#define MPU_SCL 9     // Gyroscope SCL (optional)
#define TOUCH_PIN A3  // Touch sensor (optional)
```

**Smart Lock:**

```cpp
#define SS_PIN 7      // RFID SDA
#define RST_PIN 10    // RFID RST
#define SCK_PIN 4     // RFID SCK
#define MISO_PIN 5    // RFID MISO
#define MOSI_PIN 6    // RFID MOSI
#define SWITCH_PIN 2  // Relay control
#define LED_PIN 3     // Status LED
```

## Upload Instructions

### Arduino IDE Setup

1. Install ESP32 board support:
   - File → Preferences → Additional Boards Manager URLs:
   - Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Tools → Board → Boards Manager → Search "ESP32" → Install

2. Select board:
   - Tools → Board → ESP32 Arduino → **ESP32C3 Dev Module**

3. Upload settings:
   - **CPU Frequency**: 160MHz
   - **Flash Size**: 4MB
   - **Flash Mode**: QIO
   - **Partition Scheme**: Default 4MB with spiffs
   - **Upload Speed**: 921600

4. Connect ESP32 via USB and upload (Ctrl+U)

### OTA Updates (After Initial Upload)

Once WiFi is configured, you can update wirelessly:

1. Sketch → Export Compiled Binary
2. Tools → Port → `smartlamp-001 at 192.168.1.100` (Network port)
3. Upload

## Features

### Smart Lamp

#### Lighting Patterns (26 total)

1. **Night Reading** - Adjustable warm reading light
2. **Blue Oceanic** - Calming ocean waves
3. **Rainbow Spiral** - Color cycling
4. **Fire Effect** - Realistic flickering flames
5. **Starry Night** - Twinkling stars with moon
6. **Breathing White** - Gentle pulsing
7. **Color Cycle** - Smooth color transitions
8. **Spiral Chase** - Animated chase effect
9. **Sunset Gradient** - Warm evening colors
10. **Pulse From Center** - Radiating waves
11. **Snowflake** - Cool white sparkles
12. **Night Light** - Dim amber for sleeping
13. **Candle Flicker** - Realistic candle flame
14. **Aurora Borealis** - Northern lights (most complex!)
15. **Ocean Waves** - Relaxing wave motion
16. **Sunset Fade** - Evening progression
17. **Meteor Shower** - Dynamic shooting stars
18. **Lightning Storm** - Dramatic lightning
19. **Ripple** - Water ripple effect
20. **Kaleidoscope** - Symmetrical patterns
21. **DNA Helix** - Intertwined spirals
22. **Forest Breeze** - Green tones
23. **Firefly Glow** - Gentle firefly simulation
24. **Dreamy Clouds** - Soft cloud movement
25. **Lava Lamp** - Warm blob motion
26. **Custom Color** - Set any RGB/HSV color

#### Gyroscope Patterns (10 total - MPU6050 required)

1. **Fluid Tilt** - Water-like movement
2. **Gyro Wave** - Wave follows tilt
3. **Shake Sparkle** - Sparkles on shake
4. **Flip Toggle** - Color changes when flipped
5. **Motion Rainbow** - Rainbow tracks movement
6. **Tilt Brightness** - Tilt to dim/brighten
7. **Shake Random** - Random color on shake
8. **Gyro Fire** - Fire intensity from motion
9. **Gyro Rainbow** - Color from tilt direction
10. **Shake Color** - Shake to randomize

#### HTTP API Endpoints

- `GET /info` - Device info (no auth)
- `POST /api/auth` - Get authentication token
- `GET /api/status` - Device status
- `POST /api/power` - Turn on/off
- `POST /api/pattern` - Set pattern (0-25)
- `POST /api/brightness` - Set brightness (0-255)
- `POST /api/color` - Set RGB color
- `POST /api/colorwheel` - Set HSV color
- `POST /api/gyro` - Enable/configure gyro
- `GET /api/patterns` - List all patterns
- `POST /api/wifi` - Update WiFi credentials
- `GET /api/wifi/scan` - Scan networks

### Smart Lock

#### Features

- RFID card authentication
- Remote unlock via HTTP API
- Entry logging with timestamps
- Add/remove authorized cards
- LED status indicator
- 5-second auto-lock timer
- Offline RFID operation (no WiFi needed)

#### HTTP API Endpoints

- `GET /info` - Device info (no auth)
- `GET /api/status` - Lock status & logs
- `POST /api/unlock` - Unlock for 5 seconds
- `POST /api/lock` - Force lock
- `POST /api/add-card` - Add authorized card
- `POST /api/remove-card` - Remove card
- `GET /api/cards` - List cards (masked)
- `POST /api/led-color` - Set status LED color
- `POST /api/logs/clear` - Clear entry logs
- `GET /api/logs/csv` - Export logs as CSV
- `GET /api/logs/pdf` - Export logs as PDF

## mDNS Discovery

Both devices advertise via mDNS for automatic discovery:

**Smart Lamp:**

- Hostname: `smartlamp-XXX.local`
- Service: `_iot-lamp._tcp`
- Port: 80

**Smart Lock:**

- Hostname: `smartlock-XXX.local`
- Service: `_iot-lock._tcp`
- Port: 80

## Security

### Authentication

All API endpoints (except `/info`) require authentication:

```http
POST /api/auth
{
  "password": "your_password"
}

Response:
{
  "token": "abc123...",
  "expiresIn": 3600
}
```

Use token in subsequent requests:

```http
GET /api/status
Authorization: Bearer abc123...
```

### Best Practices

- ✅ Change default passwords before deployment
- ✅ Use strong passwords (8+ characters)
- ✅ Keep firmware updated
- ✅ Use WPA2/WPA3 WiFi encryption
- ⚠️ Tokens expire after 1 hour

## Troubleshooting

### Compile Errors

**"FastLED.h: No such file"**
→ Install FastLED library

**"MPU6050_light.h: No such file"**
→ Install MPU6050_light library or comment out gyro code

**"MFRC522.h: No such file"**
→ Install MFRC522 library

### Upload Errors

**"Serial port not found"**
→ Check USB cable, install ESP32 drivers

**"Timed out waiting for packet header"**
→ Hold BOOT button while uploading

**"Upload failed: espcomm_upload_mem failed"**
→ Select correct board (ESP32C3 Dev Module)

### Runtime Issues

**LEDs don't light**
→ Check power supply (5V, sufficient current)
→ Verify data pin connection
→ Test with simple FastLED example

**WiFi won't connect**
→ Check SSID/password (case-sensitive)
→ ESP32 only supports 2.4GHz WiFi
→ Device creates AP mode if connection fails

**RFID not reading**
→ MFRC522 requires 3.3V (not 5V!)
→ Check all SPI connections
→ Hold card within 2-3cm

**Gyro not working**
→ Check I2C connections (SDA/SCL)
→ Verify MPU6050 power (3.3V or 5V)
→ Run calibration via app

## Customization

### Adding New Patterns

1. Add pattern name to array:

```cpp
const char* patternNames[] = {
    "...",
    "My Custom Pattern"  // Add here
};
const uint8_t NUM_PATTERNS = 27;  // Increment
```

2. Create pattern function:

```cpp
void patternMyCustom() {
    for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = CHSV(i * 10, 255, 255);
    }
    FastLED.show();
}
```

3. Add to switch statement:

```cpp
switch (lampState.currentPattern) {
    // ... existing cases
    case 26:
        patternMyCustom();
        break;
}
```

### Changing LED Layout

The firmware assumes a 21-LED spiral layout. For different layouts:

1. Update LED count:

```cpp
#define NUM_LEDS 30  // Your LED count
```

2. Modify layout indices (lines 105-133)
3. Update pattern functions to use your layout

### Adjusting Timing

```cpp
#define ANIMATION_FRAME_MS 16        // Frame rate (60 FPS)
#define SWITCH_ON_TIME 5000          // Lock timeout (ms)
#define RFID_DEBOUNCE_TIME 500       // Card scan debounce
#define WIFI_CONNECT_TIMEOUT 10000   // WiFi connection timeout
```

## Serial Monitor Output

Set baud rate to **115200** to see debug messages:

### Smart Lamp

```
ESP32-C3 Mini Smart Lamp Starting
Firmware Version: 1.1.0
WiFi Connected!
IP Address: 192.168.1.100
MPU6050: Connected
Smart Lamp Ready
```

### Smart Lock

```
ESP32-C3 Smart RFID Lock
Lock ID: A3B2C1
RFID reader initialized
WiFi Connected!
IP: 192.168.1.101
Authorized Cards:
  1. F9FA8E14
  2. A1653B1D
Smart Lock Ready!
```

## Advanced Topics

### Power Consumption

**Smart Lamp:**

- ESP32: ~150mA
- WS2812B LEDs: ~60mA each at full white
- MPU6050: ~5mA
- **Total (21 LEDs)**: ~1.4A at full brightness

Use external 5V supply for >10 LEDs!

**Smart Lock:**

- ESP32: ~150mA
- MFRC522: ~13mA (idle), ~100mA (active)
- Relay: ~70mA
- **Total**: ~300mA typical

### WiFi Range

ESP32-C3 typical range:

- Indoor: 50-100 meters
- Outdoor: 200-300 meters
- Through walls: 20-30 meters per wall

Improve range:

- Use external antenna
- Position away from metal objects
- Reduce interference (move away from 2.4GHz devices)

## Support

For firmware issues:

- Check Serial Monitor (115200 baud)
- Review pin connections
- Verify library versions
- See main README troubleshooting section
