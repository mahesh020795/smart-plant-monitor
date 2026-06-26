
/*
 * Smart Plant Monitor — ESP32 Firmware WITH OTA
 *
 * OTA Update Flow:
 *  1. Compile firmware in Arduino IDE → Sketch → Export Compiled Binary → .bin file
 *  2. Create a GitHub Release and attach the .bin file
 *  3. Update version.txt in your repo root to the new version (e.g. "1.0.2")
 *  4. ESP32 checks version.txt on every boot and every hour
 *  5. If new version found → LCD shows progress → downloads .bin → flashes → reboots
 *
 * GitHub setup:
 *  - Repo:        github.com/YOUR_USERNAME/smart-plant-esp32
 *  - version.txt: raw URL = https://raw.githubusercontent.com/YOUR_USERNAME/smart-plant-esp32/main/version.txt
 *  - .bin URL:    https://github.com/YOUR_USERNAME/smart-plant-esp32/releases/latest/download/smart_plant_esp32.bin
 *
 * Hardware:
 *  - Soil Moisture Sensor → GPIO34 (ADC)
 *  - DHT11               → GPIO4
 *  - BH1750 (I2C)        → SDA=GPIO21, SCL=GPIO22
 *  - HC-SR04             → TRIG=GPIO5, ECHO=GPIO18
 *  - DS18B20 (1-Wire)    → GPIO15 (4.7kΩ pullup to 3.3V)
 *  - Relay (pump)        → GPIO2 (HIGH = pump ON for active-high relay)
 *  - I2C LCD 16x2        → SDA=GPIO21, SCL=GPIO22 (addr 0x27)
 *
 * Libraries (Arduino Library Manager):
 *  - DHT sensor library  (Adafruit)
 *  - BH1750              (Christopher Laws)
 *  - OneWire             (Paul Stoffregen)
 *  - DallasTemperature   (Miles Burton)
 *  - LiquidCrystal_I2C   (Frank de Brabander)
 *  - Firebase ESP Client (Mobizt)
 *  All OTA libraries (HTTPClient, HTTPUpdate, Update) are built into ESP32 Arduino core.
 */

#include <WiFi.h>
#include <FirebaseESP32.h>
#include <Wire.h>
#include <DHT.h>
#include <BH1750.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <LiquidCrystal_I2C.h>
#include <time.h>
#include <HTTPClient.h>
#include <HTTPUpdate.h>

// ─── Firmware Version ─────────────────────────────────────────────────────
// !! IMPORTANT: Update this every time you flash a new version !!
#define FIRMWARE_VERSION  "1.0.2"

// ─── GitHub OTA URLs ──────────────────────────────────────────────────────
#define GITHUB_USERNAME   "mahesh020795"
#define GITHUB_REPO       "smart-plant-monitor"

// version.txt in repo root — update this on GitHub to trigger OTA
#define OTA_VERSION_URL   "https://raw.githubusercontent.com/" GITHUB_USERNAME "/" GITHUB_REPO "/master/version.txt"

// firmware.bin attached to the latest GitHub Release
#define OTA_BIN_URL       "https://github.com/" GITHUB_USERNAME "/" GITHUB_REPO "/releases/latest/download/firmware.bin"

// ─── WiFi + Firebase Config ───────────────────────────────────────────────
#define WIFI_SSID       "project123"
#define WIFI_PASSWORD   "01126502500"
#define FIREBASE_HOST   "smart-plant-monitor-fdddf-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH   "Ph8QVKdtDnMzHKLWuPOwR5rH9uhWiTB67JdLkNbc"
#define USER_UID        "b44mjHqSSeX7ayrZ68H08rPJ0bU2"

// ─── Pin Definitions ──────────────────────────────────────────────────────
#define SOIL_MOISTURE_PIN   34
#define DHT_PIN             4
#define DHT_TYPE            DHT11
#define TRIG_PIN            5
#define ECHO_PIN            18
#define DS18B20_PIN         15
#define RELAY_PIN           2     // HIGH = pump ON

// Soil calibration
const int SOIL_DRY = 4095;
const int SOIL_WET = 2100;

// ─── Thresholds ───────────────────────────────────────────────────────────
float SOIL_DRY_THRESHOLD  = 30.0;
float WATER_LOW_THRESHOLD = 20.0;
float TEMP_HIGH_THRESHOLD = 35.0;

// ─── Intervals ────────────────────────────────────────────────────────────
#define SENSOR_INTERVAL_MS    10000
#define PUMP_CHECK_MS          5000
#define SCHEDULE_CHECK_MS     60000
#define LCD_REFRESH_MS         3000
#define SETTINGS_CHECK_MS     30000
// OTA only checks on boot (setup), not in loop

// ─── Objects ──────────────────────────────────────────────────────────────
FirebaseData   fbData;
FirebaseConfig fbConfig;
FirebaseAuth   fbAuth;

DHT           dht(DHT_PIN, DHT_TYPE);
BH1750        lightMeter;
OneWire       oneWire(DS18B20_PIN);
DallasTemperature ds18b20(&oneWire);
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ─── State ────────────────────────────────────────────────────────────────
float soilMoisturePct = 0;
float airTempC        = 0;
float humidityPct     = 0;
float lightLux        = 0;
float waterLevelPct   = 0;
float soilTempC       = 0;
float tankHeightCm    = 25.0;
bool  pumpRunning     = false;
String pumpCommand    = "auto";

unsigned long lastSensorUpload  = 0;
unsigned long lastPumpCheck     = 0;
unsigned long lastScheduleCheck = 0;
unsigned long lastLcdRefresh    = 0;
unsigned long lastSettingsCheck = 0;
int           lcdPage           = 0;

// ─── Prototypes ───────────────────────────────────────────────────────────
void     readSensors();
void     uploadSensors();
void     checkPumpCommand();
void     checkSchedules();
void     checkSettingsAndCalibration();
void     checkAlertConditions();
void     setPump(bool on);
void     updateLCD();
float    measureWaterLevelPct();
float    readSoilMoisture();
void     sendFirebaseAlert(const String& type, const String& msg);
void     checkOTA();   // called once in setup()
unsigned long epochTime();
unsigned long localEpochTime();
unsigned long long epochMillis();

// ═══════════════════════════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW); // relay off (active HIGH)

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  Wire.begin(21, 22);
  dht.begin();
  ds18b20.begin();

  if (lightMeter.begin()) {
    Serial.println("[BH1750] OK");
  } else {
    Serial.println("[BH1750] FAIL");
  }

  int dsCount = ds18b20.getDeviceCount();
  Serial.println(dsCount > 0
    ? "[DS18B20] OK - " + String(dsCount) + " device(s)"
    : "[DS18B20] FAIL");

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0); lcd.print("Smart Plant");
  lcd.setCursor(0, 1); lcd.print("v" FIRMWARE_VERSION);
  delay(1500);

  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("Smart Plant");
  lcd.setCursor(0, 1); lcd.print("Connecting WiFi");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print('.');
  }
  Serial.println("\nWiFi: " + WiFi.localIP().toString());

  // NTP time sync
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("Syncing time...");
  struct tm ti;
  int retry = 0;
  while (!getLocalTime(&ti) && retry < 20) { delay(500); retry++; }
  Serial.println(retry < 20 ? "[NTP] Synced" : "[NTP] Failed");

  // OTA check on boot
  checkOTA();

  // Firebase
  fbConfig.host = FIREBASE_HOST;
  fbConfig.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);
  fbData.setResponseSize(4096);

  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("Firebase OK");
  lcd.setCursor(0, 1); lcd.print(WiFi.localIP().toString());
  delay(2000);

  // Read sensors immediately on boot
  readSensors();
  uploadSensors();
  checkAlertConditions();
}

// ═══════════════════════════════════════════════════════════════════════════
void loop() {
  unsigned long now = millis();

  if (now - lastSensorUpload >= SENSOR_INTERVAL_MS) {
    lastSensorUpload = now;
    readSensors();
    uploadSensors();
    checkAlertConditions();
  }

  if (now - lastPumpCheck >= PUMP_CHECK_MS) {
    lastPumpCheck = now;
    checkPumpCommand();
  }

  if (now - lastScheduleCheck >= SCHEDULE_CHECK_MS) {
    lastScheduleCheck = now;
    checkSchedules();
  }

  if (now - lastLcdRefresh >= LCD_REFRESH_MS) {
    lastLcdRefresh = now;
    updateLCD();
  }

  if (now - lastSettingsCheck >= SETTINGS_CHECK_MS) {
    lastSettingsCheck = now;
    checkSettingsAndCalibration();
  }

}

// ─── OTA Update ───────────────────────────────────────────────────────────
void checkOTA() {
  Serial.println("[OTA] Checking for update...");
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("OTA Check...");
  lcd.setCursor(0, 1); lcd.print("v" FIRMWARE_VERSION);

  HTTPClient http;
  http.begin(OTA_VERSION_URL);
  int code = http.GET();

  if (code != 200) {
    Serial.println("[OTA] Could not reach version.txt (code " + String(code) + ")");
    http.end();
    return;
  }

  String latestVersion = http.getString();
  latestVersion.trim();
  http.end();

  Serial.println("[OTA] Current: " FIRMWARE_VERSION " | Latest: " + latestVersion);

  if (latestVersion == FIRMWARE_VERSION) {
    Serial.println("[OTA] Already up to date");
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("OTA: Up to date");
    lcd.setCursor(0, 1); lcd.print("v" FIRMWARE_VERSION);
    delay(2000);
    return;
  }

  // New version available — download and flash
  Serial.println("[OTA] New version " + latestVersion + " found! Updating...");
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("New: v" + latestVersion);
  lcd.setCursor(0, 1); lcd.print("Downloading...");

  // OTA progress callback — updates LCD with percentage
  httpUpdate.onProgress([](int cur, int total) {
    if (total > 0) {
      int pct = (cur * 100) / total;
      lcd.setCursor(0, 1);
      String bar = "";
      int filled = pct / 10;
      for (int i = 0; i < 10; i++) bar += (i < filled ? '\xFF' : '-');
      lcd.print(bar + " " + String(pct) + "%");
    }
  });

  httpUpdate.onStart([]() {
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Flashing...");
  });

  httpUpdate.onEnd([]() {
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Flash OK!");
    lcd.setCursor(0, 1); lcd.print("Rebooting...");
    delay(2000);
  });

  httpUpdate.onError([](int err) {
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("OTA FAILED!");
    lcd.setCursor(0, 1); lcd.print("Err: " + String(err));
    Serial.println("[OTA] Error: " + String(err));
    delay(3000);
  });

  WiFiClient client;
  t_httpUpdate_return result = httpUpdate.update(client, OTA_BIN_URL);

  switch (result) {
    case HTTP_UPDATE_OK:
      Serial.println("[OTA] Success — rebooting");
      ESP.restart();
      break;
    case HTTP_UPDATE_NO_UPDATES:
      Serial.println("[OTA] No update needed");
      break;
    case HTTP_UPDATE_FAILED:
      Serial.println("[OTA] Failed: " + httpUpdate.getLastErrorString());
      break;
  }
}

// ─── Sensor Reading ───────────────────────────────────────────────────────
void readSensors() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (!isnan(h)) humidityPct = h;
  if (!isnan(t)) airTempC    = t;

  lightLux        = lightMeter.readLightLevel();
  soilMoisturePct = readSoilMoisture();
  waterLevelPct   = measureWaterLevelPct();

  ds18b20.requestTemperatures();
  float st = ds18b20.getTempCByIndex(0);
  if (st != DEVICE_DISCONNECTED_C) soilTempC = st;

  Serial.printf(
    "Soil:%.1f%% AirT:%.1fC Hum:%.1f%% Lux:%.0f Water:%.1f%% SoilT:%.1fC\n",
    soilMoisturePct, airTempC, humidityPct, lightLux, waterLevelPct, soilTempC
  );
}

float readSoilMoisture() {
  int raw = analogRead(SOIL_MOISTURE_PIN);
  float pct = (float)(SOIL_DRY - raw) / (float)(SOIL_DRY - SOIL_WET) * 100.0f;
  return constrain(pct, 0.0f, 100.0f);
}

float measureWaterLevelPct() {
  digitalWrite(TRIG_PIN, LOW);  delayMicroseconds(4);
  digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 100000UL);
  delay(10);
  if (duration <= 0) return 0;

  float distanceCm = duration * 0.034f / 2.0f;
  if (distanceCm <= 0 || distanceCm > tankHeightCm) return 0;

  float pct = ((tankHeightCm - distanceCm) / tankHeightCm) * 100.0f;
  return constrain(pct, 0.0f, 100.0f);
}

// ─── Firebase Upload ──────────────────────────────────────────────────────
void uploadSensors() {
  if (!Firebase.ready()) return;

  String path = "/sensors/" + String(USER_UID) + "/latest";

  FirebaseJson json;
  json.set("soilMoisture",  soilMoisturePct);
  json.set("airTemp",       airTempC);
  json.set("humidity",      humidityPct);
  json.set("lightLux",      lightLux);
  json.set("waterLevelPct", waterLevelPct);
  json.set("soilTemp",      soilTempC);
  json.set("pumpStatus",    pumpRunning);
  json.set("fwVersion",     FIRMWARE_VERSION);
  json.set("lastUpdated",   epochMillis());

  if (Firebase.setJSON(fbData, path, json)) {
    Serial.println("Uploaded OK");
    String histPath = "/sensors/" + String(USER_UID) + "/history";
    Firebase.pushJSON(fbData, histPath, json);
  } else {
    Serial.println("Upload failed: " + fbData.errorReason());
  }
}

// ─── Pump Command ─────────────────────────────────────────────────────────
void checkPumpCommand() {
  if (!Firebase.ready()) return;

  String path = "/pump/" + String(USER_UID) + "/command";
  if (Firebase.getString(fbData, path)) {
    pumpCommand = fbData.stringData();

    if (pumpCommand == "on") {
      setPump(true);
    } else if (pumpCommand == "off") {
      setPump(false);
    } else if (pumpCommand == "auto") {
      if (soilMoisturePct < SOIL_DRY_THRESHOLD && !pumpRunning) {
        setPump(true);
      } else if (soilMoisturePct >= SOIL_DRY_THRESHOLD + 5 && pumpRunning) {
        setPump(false);
      }
    }
  }
}

void setPump(bool on) {
  if (pumpRunning == on) return;
  pumpRunning = on;
  digitalWrite(RELAY_PIN, on ? HIGH : LOW);

  String path = "/sensors/" + String(USER_UID) + "/latest/pumpStatus";
  Firebase.setBool(fbData, path, pumpRunning);

  Serial.println(String("Pump ") + (on ? "ON" : "OFF"));
  sendFirebaseAlert(
    on ? "pumpOn" : "pumpOff",
    on ? "Water pump turned ON" : "Water pump turned OFF"
  );
}

// ─── Schedule Checker ─────────────────────────────────────────────────────
void checkSchedules() {
  if (!Firebase.ready()) return;

  String path = "/schedules/" + String(USER_UID);
  if (!Firebase.getJSON(fbData, path)) return;

  FirebaseJson schedJson;
  schedJson.setJsonData(fbData.jsonString());
  size_t count = schedJson.iteratorBegin();

  unsigned long t   = localEpochTime();
  int currentHour   = (t % 86400) / 3600;
  int currentMinute = (t % 3600)  / 60;
  int currentDow    = ((t / 86400) + 3) % 7 + 1;

  for (size_t i = 0; i < count; i++) {
    String key, value;
    int type;
    schedJson.iteratorGet(i, type, key, value);

    FirebaseJson sched;
    sched.setJsonData(value);

    FirebaseJsonData enabled, hour, minute, duration, days;
    sched.get(enabled,  "enabled");
    sched.get(hour,     "hour");
    sched.get(minute,   "minute");
    sched.get(duration, "durationSeconds");
    sched.get(days,     "days");

    if (!enabled.boolValue) continue;
    if (hour.intValue != currentHour) continue;
    if (minute.intValue != currentMinute) continue;

    bool dayMatch = false;
    FirebaseJsonArray daysArr;
    days.get<FirebaseJsonArray>(daysArr);
    for (size_t d = 0; d < daysArr.size(); d++) {
      FirebaseJsonData dayVal;
      daysArr.get(dayVal, d);
      if (dayVal.intValue == currentDow) { dayMatch = true; break; }
    }
    if (!dayMatch) continue;

    // Respect manual OFF — skip schedule if user manually stopped pump
    if (pumpCommand == "off") {
      Serial.println("Schedule skipped — manual OFF active");
      break;
    }

    Serial.println("Schedule triggered! " + String(duration.intValue) + "s");
    setPump(true);
    delay((unsigned long)duration.intValue * 1000UL);
    setPump(false);
    break;
  }

  schedJson.iteratorEnd();
}

// ─── Alert Conditions ─────────────────────────────────────────────────────
void checkAlertConditions() {
  static bool prevDrySoil  = false;
  static bool prevLowWater = false;
  static bool prevHighTemp = false;

  bool drySoil  = soilMoisturePct < SOIL_DRY_THRESHOLD;
  bool lowWater = waterLevelPct   < WATER_LOW_THRESHOLD;
  bool highTemp = airTempC        > TEMP_HIGH_THRESHOLD;

  if (drySoil  && !prevDrySoil)
    sendFirebaseAlert("drysoil",  "Soil moisture low (" + String(soilMoisturePct, 1) + "%)");
  if (lowWater && !prevLowWater)
    sendFirebaseAlert("lowWater", "Water tank low (" + String(waterLevelPct, 1) + "%)");
  if (highTemp && !prevHighTemp)
    sendFirebaseAlert("highTemp", "High temperature (" + String(airTempC, 1) + "C)");

  prevDrySoil  = drySoil;
  prevLowWater = lowWater;
  prevHighTemp = highTemp;
}

void sendFirebaseAlert(const String& type, const String& msg) {
  if (!Firebase.ready()) return;

  FirebaseJson alertJson;
  alertJson.set("type",      type);
  alertJson.set("message",   msg);
  alertJson.set("timestamp", epochMillis());
  alertJson.set("read",      false);

  String path = "/alerts/" + String(USER_UID);
  if (!Firebase.pushJSON(fbData, path, alertJson)) {
    Serial.println("Alert push failed: " + fbData.errorReason());
  }
}

// ─── LCD Display ──────────────────────────────────────────────────────────
void updateLCD() {
  lcd.clear();
  switch (lcdPage) {
    case 0:
      lcd.setCursor(0, 0); lcd.print("Soil: " + String(soilMoisturePct, 1) + "%");
      lcd.setCursor(0, 1); lcd.print("Water:" + String(waterLevelPct, 1) + "%");
      break;
    case 1:
      lcd.setCursor(0, 0); lcd.print("Temp: " + String(airTempC, 1) + "\xDF""C");
      lcd.setCursor(0, 1); lcd.print("Hum:  " + String(humidityPct, 1) + "%");
      break;
    case 2:
      lcd.setCursor(0, 0); lcd.print("Light:" + String((int)lightLux) + " lux");
      lcd.setCursor(0, 1); lcd.print("Pump: " + String(pumpRunning ? "ON " : "OFF"));
      break;
    case 3:
      lcd.setCursor(0, 0); lcd.print("SoilT:" + String(soilTempC, 1) + "\xDF""C");
      lcd.setCursor(0, 1); lcd.print(WiFi.isConnected() ? "FW:v" FIRMWARE_VERSION : "WiFi: --");
      break;
  }
  lcdPage = (lcdPage + 1) % 4;
}

// ─── Settings + Calibration ───────────────────────────────────────────────
void checkSettingsAndCalibration() {
  if (!Firebase.ready()) return;

  String tPath = "/users/" + String(USER_UID) + "/settings/thresholds";
  if (Firebase.getJSON(fbData, tPath)) {
    FirebaseJson tJson;
    tJson.setJsonData(fbData.jsonString());
    FirebaseJsonData val;
    if (tJson.get(val, "soilDry"))  SOIL_DRY_THRESHOLD  = val.floatValue;
    if (tJson.get(val, "waterLow")) WATER_LOW_THRESHOLD = val.floatValue;
    if (tJson.get(val, "tempHigh")) TEMP_HIGH_THRESHOLD = val.floatValue;
  }

  String calPath = "/calibration/" + String(USER_UID) + "/calibrateNow";
  if (Firebase.getBool(fbData, calPath) && fbData.boolData()) {
    Serial.println("Calibrating tank (empty)...");
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("Calibrating...");
    lcd.setCursor(0, 1); lcd.print("Keep tank empty!");

    float total = 0;
    int valid   = 0;
    for (int i = 0; i < 5; i++) {
      digitalWrite(TRIG_PIN, LOW);  delayMicroseconds(4);
      digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
      digitalWrite(TRIG_PIN, LOW);
      long dur = pulseIn(ECHO_PIN, HIGH, 100000UL);
      delay(10);
      float d = dur * 0.034f / 2.0f;
      if (d > 1.0f && d < 400.0f) { total += d; valid++; }
      delay(200);
    }

    String basePath = "/calibration/" + String(USER_UID);
    if (valid > 0) {
      tankHeightCm = total / valid;
      Serial.printf("Tank height: %.1f cm\n", tankHeightCm);
      Firebase.setFloat(fbData,  basePath + "/tankHeightCm", tankHeightCm);
      Firebase.setBool(fbData,   basePath + "/calibrateNow", false);
      Firebase.setDouble(fbData, basePath + "/calibratedAt", (double)epochMillis());
      lcd.clear();
      lcd.setCursor(0, 0); lcd.print("Calibrated!");
      lcd.setCursor(0, 1); lcd.print("Height:" + String(tankHeightCm, 1) + "cm");
      delay(3000);
    } else {
      Serial.println("Calibration failed");
      Firebase.setBool(fbData, basePath + "/calibrateNow", false);
      lcd.clear();
      lcd.setCursor(0, 0); lcd.print("Cal FAILED!");
      lcd.setCursor(0, 1); lcd.print("Check sensor");
      delay(3000);
    }
  }

  String heightPath = "/calibration/" + String(USER_UID) + "/tankHeightCm";
  if (Firebase.getFloat(fbData, heightPath) && fbData.floatData() > 0) {
    tankHeightCm = fbData.floatData();
  }
}

// ─── NTP Time ─────────────────────────────────────────────────────────────
unsigned long epochTime() {
  time_t now;
  time(&now);
  return (unsigned long)now;
}

unsigned long localEpochTime() {
  return epochTime() + (8L * 3600L);
}

unsigned long long epochMillis() {
  return (unsigned long long)epochTime() * 1000ULL;
}
