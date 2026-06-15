/*
 * Smart Plant Monitor — ESP32 Firmware
 *
 * Hardware:
 *  - Soil Moisture Sensor → GPIO34 (ADC)
 *  - DHT11               → GPIO4
 *  - BH1750 (I2C)        → SDA=GPIO21, SCL=GPIO22
 *  - HC-SR04             → TRIG=GPIO5, ECHO=GPIO18
 *  - DS18B20 (1-Wire)    → GPIO15 (4.7kΩ pullup to 3.3V)
 *  - Relay (pump)        → GPIO2 (LOW = pump ON for active-low relay)
 *  - I2C LCD 16x2        → SDA=GPIO21, SCL=GPIO22 (addr 0x27)
 *
 * Libraries required (install via Arduino Library Manager):
 *  - ArduinoJson         (Benoit Blanchon)
 *  - DHT sensor library  (Adafruit)
 *  - BH1750              (Christopher Laws)
 *  - OneWire             (Paul Stoffregen)
 *  - DallasTemperature   (Miles Burton)
 *  - LiquidCrystal_I2C   (Frank de Brabander)
 *  - Firebase ESP Client (Mobizt) — for RTDB + FCM
 */

#include <WiFi.h>
#include <FirebaseESP32.h>
#include <DHT.h>
#include <BH1750.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <LiquidCrystal_I2C.h>

// ─── WiFi + Firebase Config ────────────────────────────────────────────────
#define WIFI_SSID       "YOUR_WIFI_SSID"
#define WIFI_PASSWORD   "YOUR_WIFI_PASSWORD"
#define FIREBASE_HOST   "YOUR-PROJECT.firebaseio.com"
#define FIREBASE_AUTH   "YOUR_DATABASE_SECRET_OR_SERVICE_ACCOUNT_TOKEN"
#define USER_UID        "USER_UID_FROM_FIREBASE_AUTH"   // set after login

// ─── Pin Definitions ───────────────────────────────────────────────────────
#define SOIL_MOISTURE_PIN   34    // ADC1 channel 6
#define DHT_PIN             4
#define DHT_TYPE            DHT11
#define TRIG_PIN            5
#define ECHO_PIN            18
#define DS18B20_PIN         15
#define RELAY_PIN           2     // LOW = pump ON

// ─── Thresholds (defaults; overridden from Firebase /users/{uid}/settings/thresholds) ──
float SOIL_DRY_THRESHOLD  = 30.0;
float WATER_LOW_THRESHOLD =  5.0;
float TEMP_HIGH_THRESHOLD = 35.0;

// ─── Intervals ─────────────────────────────────────────────────────────────
#define SENSOR_INTERVAL_MS    30000  // upload every 30 sec
#define PUMP_CHECK_MS          5000  // check pump command every 5 sec
#define SCHEDULE_CHECK_MS     60000  // check schedules every 60 sec
#define LCD_REFRESH_MS         3000  // rotate LCD display every 3 sec

// ─── Objects ───────────────────────────────────────────────────────────────
FirebaseData   fbData;
FirebaseConfig fbConfig;
FirebaseAuth   fbAuth;

DHT           dht(DHT_PIN, DHT_TYPE);
BH1750        lightMeter;
OneWire       oneWire(DS18B20_PIN);
DallasTemperature ds18b20(&oneWire);
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ─── State ─────────────────────────────────────────────────────────────────
float soilMoisturePct = 0;
float airTempC        = 0;
float humidityPct     = 0;
float lightLux        = 0;
float waterLevelCm    = 0;
float soilTempC       = 0;
float tankHeightCm    = 25.0;  // overwritten after calibration
bool  pumpRunning     = false;
String pumpCommand    = "auto";

unsigned long lastSensorUpload  = 0;
unsigned long lastPumpCheck     = 0;
unsigned long lastScheduleCheck = 0;
unsigned long lastLcdRefresh    = 0;
unsigned long lastSettingsCheck = 0;
#define SETTINGS_CHECK_MS  30000
int           lcdPage           = 0;

// ─── Prototypes ────────────────────────────────────────────────────────────
void     readSensors();
void     uploadSensors();
void     checkPumpCommand();
void     checkSchedules();
void     checkSettingsAndCalibration();
void     setPump(bool on);
void     updateLCD();
float    measureWaterLevel();
float    readSoilMoisture();
void     sendFirebaseAlert(const String& type, const String& msg);
unsigned long epochTime();

// ═══════════════════════════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);

  // Outputs
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH); // relay off (active LOW)

  // Sensors
  dht.begin();
  Wire.begin(21, 22);
  lightMeter.begin();
  ds18b20.begin();

  // LCD
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0); lcd.print("Smart Plant");
  lcd.setCursor(0, 1); lcd.print("Connecting WiFi");

  // WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print('.');
  }
  Serial.println("\nWiFi connected: " + WiFi.localIP().toString());

  // Firebase
  fbConfig.host           = FIREBASE_HOST;
  fbConfig.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);
  fbData.setResponseSize(4096);

  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("Firebase OK");
  lcd.setCursor(0, 1); lcd.print(WiFi.localIP().toString());
  delay(2000);
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

// ─── Sensor Reading ────────────────────────────────────────────────────────
void readSensors() {
  // DHT11
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (!isnan(h)) humidityPct = h;
  if (!isnan(t)) airTempC    = t;

  // BH1750
  lightLux = lightMeter.readLightLevel();

  // Soil moisture (raw ADC → %)
  soilMoisturePct = readSoilMoisture();

  // HC-SR04 water level
  waterLevelCm = measureWaterLevel();

  // DS18B20 soil temp
  ds18b20.requestTemperatures();
  float st = ds18b20.getTempCByIndex(0);
  if (st != DEVICE_DISCONNECTED_C) soilTempC = st;

  Serial.printf(
    "Soil:%.1f%% AirT:%.1fC Hum:%.1f%% Lux:%.0f Water:%.1fcm SoilT:%.1fC\n",
    soilMoisturePct, airTempC, humidityPct, lightLux, waterLevelCm, soilTempC
  );
}

float readSoilMoisture() {
  // ADC range: ~4095 (dry) → ~1500 (wet) — calibrate for your sensor
  const int DRY_VAL = 3500;
  const int WET_VAL = 1200;
  int raw = analogRead(SOIL_MOISTURE_PIN);
  float pct = map(raw, DRY_VAL, WET_VAL, 0, 100);
  return constrain(pct, 0.0f, 100.0f);
}

float measureWaterLevel() {
  // HC-SR04 mounted at top of tank; distance to water surface measured.
  // tankHeightCm set by calibration (empty tank = full distance to bottom).
  digitalWrite(TRIG_PIN, LOW);  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  float distanceCm = duration * 0.0343f / 2.0f;
  if (distanceCm <= 0 || distanceCm > tankHeightCm) return 0;
  return constrain(tankHeightCm - distanceCm, 0.0f, tankHeightCm);
}

// ─── Firebase Upload ───────────────────────────────────────────────────────
void uploadSensors() {
  if (!Firebase.ready()) return;

  String path = "/sensors/" + String(USER_UID) + "/latest";

  FirebaseJson json;
  json.set("soilMoisture", soilMoisturePct);
  json.set("airTemp",      airTempC);
  json.set("humidity",     humidityPct);
  json.set("lightLux",     lightLux);
  json.set("waterLevelCm", waterLevelCm);
  json.set("soilTemp",     soilTempC);
  json.set("pumpStatus",   pumpRunning);
  json.set("lastUpdated",  (int)(epochTime() * 1000LL));

  if (Firebase.setJSON(fbData, path, json)) {
    Serial.println("Sensor data uploaded");

    // Also push to history
    String histPath = "/sensors/" + String(USER_UID) + "/history";
    Firebase.pushJSON(fbData, histPath, json);
  } else {
    Serial.println("Upload failed: " + fbData.errorReason());
  }
}

// ─── Pump Command ──────────────────────────────────────────────────────────
void checkPumpCommand() {
  if (!Firebase.ready()) return;

  String path = "/pump/" + String(USER_UID) + "/command";
  if (Firebase.getString(fbData, path)) {
    pumpCommand = fbData.stringData();

    if (pumpCommand == "on") {
      setPump(true);
    } else if (pumpCommand == "off") {
      setPump(false);
    }
    // "auto" = controlled by schedules / soil moisture threshold
    else if (pumpCommand == "auto") {
      // Auto-irrigate if soil too dry
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
  digitalWrite(RELAY_PIN, on ? LOW : HIGH); // active-low relay

  // Update pump status in Firebase
  String path = "/sensors/" + String(USER_UID) + "/latest/pumpStatus";
  Firebase.setBool(fbData, path, pumpRunning);

  Serial.println(String("Pump ") + (on ? "ON" : "OFF"));
  sendFirebaseAlert(
    on ? "pumpOn" : "pumpOff",
    on ? "💧 Water pump turned ON" : "🔴 Water pump turned OFF"
  );
}

// ─── Schedule Checker ─────────────────────────────────────────────────────
void checkSchedules() {
  if (!Firebase.ready()) return;

  // Fetch all schedules for this user
  String path = "/schedules/" + String(USER_UID);
  if (!Firebase.getJSON(fbData, path)) return;

  FirebaseJson schedJson;
  schedJson.setJsonData(fbData.jsonString());
  FirebaseJsonData result;
  size_t count = schedJson.iteratorBegin();

  // Get current time (hour/minute)
  unsigned long t = epochTime();
  int currentHour   = (t % 86400) / 3600;
  int currentMinute = (t % 3600)  / 60;
  int currentDow    = ((t / 86400) + 4) % 7 + 1; // 1=Mon…7=Sun (ISO)

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

    // Check day of week
    bool dayMatch = false;
    FirebaseJsonArray daysArr;
    days.get<FirebaseJsonArray>(daysArr);
    for (size_t d = 0; d < daysArr.size(); d++) {
      FirebaseJsonData dayVal;
      daysArr.get(dayVal, d);
      if (dayVal.intValue == currentDow) { dayMatch = true; break; }
    }
    if (!dayMatch) continue;

    // Fire the schedule
    Serial.println("Schedule triggered! Duration: " + String(duration.intValue) + "s");
    setPump(true);
    delay(duration.intValue * 1000UL);
    setPump(false);
    break; // only one schedule per minute
  }

  schedJson.iteratorEnd();
}

// ─── Alert Conditions ─────────────────────────────────────────────────────
void checkAlertConditions() {
  static bool prevDrySoil  = false;
  static bool prevLowWater = false;
  static bool prevHighTemp = false;

  bool drySoil  = soilMoisturePct < SOIL_DRY_THRESHOLD;
  bool lowWater = waterLevelCm    < WATER_LOW_THRESHOLD;
  bool highTemp = airTempC        > TEMP_HIGH_THRESHOLD;

  if (drySoil && !prevDrySoil)
    sendFirebaseAlert("drysoil",  "🌱 Soil moisture low (" + String(soilMoisturePct, 1) + "%)");
  if (lowWater && !prevLowWater)
    sendFirebaseAlert("lowWater", "💧 Water tank low (" + String(waterLevelCm, 1) + " cm)");
  if (highTemp && !prevHighTemp)
    sendFirebaseAlert("highTemp", "🌡️ High temperature alert (" + String(airTempC, 1) + "°C)");

  prevDrySoil  = drySoil;
  prevLowWater = lowWater;
  prevHighTemp = highTemp;
}

void sendFirebaseAlert(const String& type, const String& msg) {
  if (!Firebase.ready()) return;

  FirebaseJson alertJson;
  alertJson.set("type",      type);
  alertJson.set("message",   msg);
  alertJson.set("timestamp", (int)(epochTime() * 1000LL));
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
      lcd.setCursor(0, 1); lcd.print("Water:" + String(waterLevelCm, 1) + "cm");
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
      lcd.setCursor(0, 1); lcd.print(WiFi.isConnected() ? "WiFi: OK" : "WiFi: --");
      break;
  }
  lcdPage = (lcdPage + 1) % 4;
}

// ─── Settings + Calibration ───────────────────────────────────────────────
void checkSettingsAndCalibration() {
  if (!Firebase.ready()) return;

  // Read thresholds from Firebase (set by app)
  String tPath = "/users/" + String(USER_UID) + "/settings/thresholds";
  FirebaseJson tJson;
  if (Firebase.getJSON(fbData, tPath)) {
    tJson.setJsonData(fbData.jsonString());
    FirebaseJsonData val;
    if (tJson.get(val, "soilDry"))  SOIL_DRY_THRESHOLD  = val.floatValue;
    if (tJson.get(val, "waterLow")) WATER_LOW_THRESHOLD = val.floatValue;
    if (tJson.get(val, "tempHigh")) TEMP_HIGH_THRESHOLD = val.floatValue;
  }

  // Check calibration trigger
  String calPath = "/calibration/" + String(USER_UID) + "/calibrateNow";
  if (Firebase.getBool(fbData, calPath) && fbData.boolData()) {
    Serial.println("Calibration triggered — measuring empty tank...");

    // Take 5 readings and average for accuracy
    float total = 0;
    int valid   = 0;
    for (int i = 0; i < 5; i++) {
      digitalWrite(TRIG_PIN, LOW);  delayMicroseconds(2);
      digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
      digitalWrite(TRIG_PIN, LOW);
      long dur = pulseIn(ECHO_PIN, HIGH, 30000);
      float d  = dur * 0.0343f / 2.0f;
      if (d > 1.0f && d < 400.0f) { total += d; valid++; }
      delay(200);
    }

    if (valid > 0) {
      tankHeightCm = total / valid;
      Serial.printf("Calibrated tank height: %.1f cm\n", tankHeightCm);

      // Save result to Firebase and clear the trigger
      String basePath = "/calibration/" + String(USER_UID);
      Firebase.setFloat(fbData, basePath + "/tankHeightCm", tankHeightCm);
      Firebase.setBool(fbData,  basePath + "/calibrateNow", false);
      Firebase.setInt(fbData,   basePath + "/calibratedAt",
                      (int)(epochTime() * 1000LL));

      lcd.clear();
      lcd.setCursor(0, 0); lcd.print("Tank calibrated!");
      lcd.setCursor(0, 1); lcd.print(String(tankHeightCm, 1) + " cm");
      delay(3000);
    } else {
      Serial.println("Calibration failed — no valid readings");
      Firebase.setBool(fbData,
        "/calibration/" + String(USER_UID) + "/calibrateNow", false);
    }
  }

  // Load saved tank height if available (persists across reboots)
  String heightPath = "/calibration/" + String(USER_UID) + "/tankHeightCm";
  if (Firebase.getFloat(fbData, heightPath) && fbData.floatData() > 0) {
    tankHeightCm = fbData.floatData();
  }
}

// ─── NTP Time ─────────────────────────────────────────────────────────────
unsigned long epochTime() {
  // Firebase ESP library provides epoch via SSL; fall back to millis/1000
  return (unsigned long)(Firebase.getCurrentTime());
}
