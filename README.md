# Smart Plant Monitor

A full-stack IoT plant monitoring and automated irrigation system built with **ESP32**, **Firebase**, and **Flutter**.

---

## Features

- Real-time sensor dashboard (soil moisture, temperature, humidity, light, water level)
- Manual & automatic pump control via relay
- Watering schedules (day / time / duration)
- Push alerts (dry soil, low water, high temperature)
- Sensor history charts (24h)
- Configurable alert thresholds
- Water tank calibration via ultrasonic sensor
- OTA firmware updates via GitHub Releases
- Firebase Auth (persistent sign-in per device)

---

## Repository Structure

```
smart-plant-monitor/
├── lib/                          # Flutter app source
│   ├── models/                   # SensorData, Alert, Schedule
│   ├── providers/                # AppProvider (state management)
│   ├── screens/                  # Dashboard, History, Schedule, Alerts, Settings
│   ├── services/                 # Firebase, Auth, Notification
│   └── widgets/                  # SensorCard
├── android/                      # Android build config
├── firmware/
│   ├── smart_plant_esp32/        # Standard firmware
│   └── smart_plant_esp32_OTA/    # Firmware with GitHub OTA support
├── version.txt                   # Current firmware version (read by OTA)
└── pubspec.yaml
```

---

## Hardware

| Component | GPIO |
|-----------|------|
| Soil Moisture Sensor (ADC) | GPIO34 |
| DHT11 (Temp + Humidity) | GPIO4 |
| BH1750 Light Sensor (I2C) | SDA=21, SCL=22 |
| HC-SR04 Ultrasonic Water Level | TRIG=5, ECHO=18 |
| DS18B20 Soil Temp (1-Wire) | GPIO15 (4.7kΩ pullup to 3.3V) |
| Relay (Pump) | GPIO2 — HIGH=ON |
| LCD 16x2 I2C (addr 0x27) | SDA=21, SCL=22 |

> HC-SR04 ECHO: use 10kΩ + 20kΩ voltage divider to drop 5V → 3.3V

---

## Setup

### Firebase

1. Create a Firebase project
2. Enable **Realtime Database** and **Authentication** (Email/Password)
3. Copy `google-services.json` → `android/app/`
4. Run `flutterfire configure` → generates `lib/firebase_options.dart`
5. Set RTDB Rules (see below)

**RTDB Rules:**
```json
{
  "rules": {
    "sensors":     { "$uid": { ".read": "auth != null && auth.uid == $uid", ".write": "auth != null" } },
    "pump":        { "$uid": { ".read": "auth != null && auth.uid == $uid", ".write": "auth != null" } },
    "schedules":   { "$uid": { ".read": "auth != null && auth.uid == $uid", ".write": "auth != null" } },
    "alerts":      { "$uid": { ".read": "auth != null && auth.uid == $uid", ".write": "auth != null" } },
    "users":       { "$uid": { ".read": "auth != null && auth.uid == $uid", ".write": "auth != null && auth.uid == $uid" } },
    "calibration": { "$uid": { ".read": "auth != null && auth.uid == $uid", ".write": "auth != null" } }
  }
}
```

### Flutter App

```bash
flutter pub get
flutter run
```

### ESP32 Firmware

1. Open `firmware/smart_plant_esp32/smart_plant_esp32.ino` in Arduino IDE
2. Fill in your credentials:

```cpp
#define WIFI_SSID     "your_wifi_ssid"
#define WIFI_PASSWORD "your_wifi_password"
#define FIREBASE_HOST "your-project-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH "your_database_secret"
#define USER_UID      "your_firebase_auth_uid"
```

3. Install libraries via Arduino Library Manager:
   - DHT sensor library (Adafruit)
   - BH1750 (Christopher Laws)
   - OneWire (Paul Stoffregen)
   - DallasTemperature (Miles Burton)
   - LiquidCrystal_I2C (Frank de Brabander)
   - Firebase ESP Client (Mobizt)

4. Flash to ESP32

---

## OTA Firmware Updates

Use `firmware/smart_plant_esp32_OTA/` for over-the-air updates:

1. Change `#define FIRMWARE_VERSION "1.0.x"` in the `.ino`
2. Compile → Sketch → Export Compiled Binary → `firmware.bin`
3. Create a GitHub Release, attach `firmware.bin`
4. Update `version.txt` in this repo to the new version
5. ESP32 auto-detects the new version within 1 hour, downloads, flashes, reboots

---

## Soil Moisture Calibration

| Raw ADC | Moisture |
|---------|----------|
| 4095 | 0% (dry air) |
| 2100 | 100% (fully submerged) |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Hardware | ESP32, Arduino IDE |
| Cloud | Firebase RTDB, Firebase Auth, FCM |
| App | Flutter · Android · Material 3 · Provider |
| Charts | fl_chart |
| OTA | GitHub Releases + HTTPUpdate |

---

## License

MIT
