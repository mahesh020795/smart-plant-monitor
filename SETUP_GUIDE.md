# Smart Plant Monitor — Setup Guide

## Project Structure

```
smart_plant_app/
├── lib/
│   ├── main.dart                      ← App entry, Firebase init, auth gate
│   ├── firebase_options.dart          ← ⚠️ Replace with FlutterFire CLI output
│   ├── models/
│   │   ├── sensor_data.dart           ← Sensor reading model
│   │   ├── schedule.dart              ← Watering schedule model
│   │   └── alert.dart                 ← Notification/alert model
│   ├── services/
│   │   ├── auth_service.dart          ← Firebase Auth (register/login/logout)
│   │   ├── database_service.dart      ← Firebase RTDB CRUD + streams
│   │   └── notification_service.dart  ← FCM push + local notifications
│   ├── providers/
│   │   └── app_provider.dart          ← State management (Provider)
│   └── screens/
│       ├── splash_screen.dart
│       ├── auth/
│       │   ├── login_screen.dart
│       │   └── register_screen.dart
│       └── home/
│           ├── nav_shell.dart         ← Bottom navigation
│           ├── dashboard_screen.dart  ← Live sensor readings + pump control
│           ├── schedule_screen.dart   ← Add/edit/delete schedules
│           ├── history_screen.dart    ← Line charts (24h history)
│           ├── notifications_screen.dart
│           └── settings_screen.dart
├── ESP32/
│   └── smart_plant_esp32.ino          ← Arduino firmware
└── pubspec.yaml
```

---

## Step 1 — Firebase Project Setup

1. Go to https://console.firebase.google.com → Create project
2. Enable **Authentication** → Email/Password
3. Enable **Realtime Database** → Start in test mode (secure later with rules below)
4. Enable **Cloud Messaging** (for push notifications)

### Realtime Database Security Rules
```json
{
  "rules": {
    "sensors": {
      "$uid": {
        ".read":  "$uid === auth.uid",
        ".write": true
      }
    },
    "pump": {
      "$uid": {
        ".read":  "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "schedules": {
      "$uid": {
        ".read":  "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "alerts": {
      "$uid": {
        ".read":  "$uid === auth.uid",
        ".write": true
      }
    },
    "users": {
      "$uid": {
        ".read":  "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

---

## Step 2 — Flutter Firebase Config

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# In the smart_plant_app folder:
flutterfire configure
```

This replaces `lib/firebase_options.dart` automatically.

---

## Step 3 — Android Setup

Add to `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Add to `android/build.gradle` dependencies:
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

`google-services.json` is downloaded automatically by `flutterfire configure`.

**AndroidManifest.xml** — add inside `<application>`:
```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="plant_alerts" />
```

---

## Step 4 — ESP32 Arduino Setup

### Arduino IDE Library Manager — install:
| Library | Author |
|---------|--------|
| Firebase ESP Client | Mobizt |
| DHT sensor library | Adafruit |
| Adafruit Unified Sensor | Adafruit |
| BH1750 | Christopher Laws |
| OneWire | Paul Stoffregen |
| DallasTemperature | Miles Burton |
| LiquidCrystal_I2C | Frank de Brabander |

### Edit `smart_plant_esp32.ino`:
```cpp
#define WIFI_SSID     "your_wifi_name"
#define WIFI_PASSWORD "your_wifi_password"
#define FIREBASE_HOST "your-project-id-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH "your_database_secret"   // Firebase Console → Project Settings → Service Accounts → Database secrets
#define USER_UID      "paste_uid_after_first_login"
```

> **Get USER_UID:** Register in the app first → Firebase Console → Authentication → Users → copy the UID

### Wiring Summary
| Component | ESP32 Pin |
|-----------|-----------|
| Soil Moisture (AO) | GPIO34 |
| DHT11 (DATA) | GPIO4 |
| BH1750 (SDA) | GPIO21 |
| BH1750 (SCL) | GPIO22 |
| HC-SR04 TRIG | GPIO5 |
| HC-SR04 ECHO | GPIO18 |
| DS18B20 (DATA) | GPIO15 + 4.7kΩ to 3.3V |
| Relay Module (IN) | GPIO2 |
| I2C LCD (SDA) | GPIO21 |
| I2C LCD (SCL) | GPIO22 |
| 12V Pump | Via Relay NO terminal |
| ESP32 VIN | Step-down module output (5V) |
| Step-down IN | 12V2A supply |

---

## Step 5 — Run the App

```bash
cd smart_plant_app
flutter pub get
flutter run
```

---

## Firebase RTDB Data Schema

```
/sensors/{uid}/latest/
    soilMoisture: 65.5      (%)
    airTemp:      28.3      (°C)
    humidity:     72.1      (%)
    lightLux:     1250.0    (lux)
    waterLevelCm: 18.5      (cm)
    soilTemp:     24.2      (°C)
    pumpStatus:   false
    lastUpdated:  1718400000000 (ms epoch)

/sensors/{uid}/history/{pushId}/   ← same fields, archived

/pump/{uid}/
    command: "auto" | "on" | "off"

/schedules/{uid}/{scheduleId}/
    name:            "Morning watering"
    hour:            7
    minute:          0
    durationSeconds: 60
    days:            [1,2,3,4,5,6,7]   (1=Mon, 7=Sun)
    enabled:         true

/alerts/{uid}/{pushId}/
    type:      "lowWater" | "drysoil" | "highTemp" | "pumpOn" | "pumpOff"
    message:   "Water tank low (4.2 cm)"
    timestamp: 1718400000000
    read:      false
```
