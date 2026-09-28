#include <Arduino.h>
#include <WiFi.h>
#include <AsyncUDP.h>
#include <esp_camera.h>
#include <esp_http_server.h>
#include <ArduinoJson.h>
#include <mbedtls/base64.h>

#include "config.h"

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
static const uint16_t UDP_PORT          = 4210;
static const uint16_t HTTP_PORT         = 80;
static const uint32_t LED_INTERVAL_MS  = 500;
static const uint8_t  LEDC_RESOLUTION  = 8;    // 0-255
static const uint32_t LEDC_FREQ        = 5000;
static const uint8_t  LEDC_CH_ENA      = 0;
static const uint8_t  LEDC_CH_ENB      = 1;

// Motors stop if no UDP command arrives within this window. Senders must
// repeat commands faster than this (motor_node sends at 20 Hz).
static const uint32_t CMD_TIMEOUT_MS   = 300;
// Upper bound for the serial MOTOR test command's duration.
static const uint32_t SERIAL_MOTOR_MAX_MS = 5000;

#ifndef WIFI_AP_SSID
#define WIFI_AP_SSID "trashcan-bot"
#endif
#ifndef WIFI_AP_PASS
#define WIFI_AP_PASS "trashcan123"
#endif
#ifndef WIFI_CONNECT_TIMEOUT_MS
#define WIFI_CONNECT_TIMEOUT_MS 15000
#endif

// ---------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------
AsyncUDP udp;

// Latest command and the time it expires. Written by the UDP callback and
// the serial handler, read by motorTask; guarded by cmdMux.
static int16_t  cmdLeft       = 0;
static int16_t  cmdRight      = 0;
static uint32_t cmdDeadlineMs = 0;
static portMUX_TYPE cmdMux    = portMUX_INITIALIZER_UNLOCKED;

httpd_handle_t streamHttpd = NULL;

// ---------------------------------------------------------------------------
// Motor control
// ---------------------------------------------------------------------------
void setMotor(uint8_t in1, uint8_t in2, uint8_t ledcCh, int16_t speed) {
    speed = constrain(speed, -255, 255);
    if (speed > 0) {
        digitalWrite(in1, HIGH);
        digitalWrite(in2, LOW);
        ledcWrite(ledcCh, (uint8_t)speed);
    } else if (speed < 0) {
        digitalWrite(in1, LOW);
        digitalWrite(in2, HIGH);
        ledcWrite(ledcCh, (uint8_t)(-speed));
    } else {
        digitalWrite(in1, LOW);
        digitalWrite(in2, LOW);
        ledcWrite(ledcCh, 0);
    }
}

void applyMotors(int16_t left, int16_t right) {
    setMotor(PIN_IN1, PIN_IN2, LEDC_CH_ENA, left);
    setMotor(PIN_IN3, PIN_IN4, LEDC_CH_ENB, right);
}

void setCommand(int16_t left, int16_t right, uint32_t holdMs) {
    portENTER_CRITICAL(&cmdMux);
    cmdLeft       = constrain(left, -255, 255);
    cmdRight      = constrain(right, -255, 255);
    cmdDeadlineMs = millis() + holdMs;
    portEXIT_CRITICAL(&cmdMux);
}

// Sole owner of the motor pins. Applies the latest command, or stops the
// motors once it expires, so a dropped link or dead laptop can't leave the
// robot driving on its last command.
void motorTask(void *pvParameters) {
    (void)pvParameters;
    int16_t appliedL = 0, appliedR = 0;
    bool timedOut = true;
    for (;;) {
        portENTER_CRITICAL(&cmdMux);
        int16_t  l        = cmdLeft;
        int16_t  r        = cmdRight;
        uint32_t deadline = cmdDeadlineMs;
        portEXIT_CRITICAL(&cmdMux);

        bool expired = (int32_t)(millis() - deadline) >= 0;
        if (expired) { l = 0; r = 0; }
        if (expired && !timedOut && (appliedL || appliedR)) {
            Serial.println("FAILSAFE: command timeout, motors stopped");
        }
        timedOut = expired;

        if (l != appliedL || r != appliedR) {
            applyMotors(l, r);
            appliedL = l;
            appliedR = r;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

// ---------------------------------------------------------------------------
// Camera init
// ---------------------------------------------------------------------------
bool initCamera() {
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_2;
    config.ledc_timer   = LEDC_TIMER_1;
    config.pin_d0       = PIN_CAM_D0;
    config.pin_d1       = PIN_CAM_D1;
    config.pin_d2       = PIN_CAM_D2;
    config.pin_d3       = PIN_CAM_D3;
    config.pin_d4       = PIN_CAM_D4;
    config.pin_d5       = PIN_CAM_D5;
    config.pin_d6       = PIN_CAM_D6;
    config.pin_d7       = PIN_CAM_D7;
    config.pin_xclk     = PIN_CAM_XCLK;
    config.pin_pclk     = PIN_CAM_PCLK;
    config.pin_vsync    = PIN_CAM_VSYNC;
    config.pin_href     = PIN_CAM_HREF;
    config.pin_sccb_sda = PIN_CAM_SIOD;
    config.pin_sccb_scl = PIN_CAM_SIOC;
    config.pin_pwdn     = PIN_CAM_PWDN;
    config.pin_reset    = PIN_CAM_RESET;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;
    config.frame_size   = FRAMESIZE_VGA;
    config.jpeg_quality = 12;
    config.fb_count     = 2;
    config.fb_location  = CAMERA_FB_IN_PSRAM;
    config.grab_mode    = CAMERA_GRAB_LATEST;

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("Camera init failed: 0x%x\n", err);
        return false;
    }
    return true;
}

// ---------------------------------------------------------------------------
// MJPEG stream handler
// ---------------------------------------------------------------------------
#define PART_BOUNDARY "123456789000000000000987654321"
static const char *STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char *STREAM_BOUNDARY     = "\r\n--" PART_BOUNDARY "\r\n";
static const char *STREAM_PART         = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

static esp_err_t streamHandler(httpd_req_t *req) {
    camera_fb_t *fb = NULL;
    esp_err_t res = ESP_OK;
    char partBuf[64];

    httpd_resp_set_type(req, STREAM_CONTENT_TYPE);
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");

    while (true) {
        fb = esp_camera_fb_get();
        if (!fb) {
            Serial.println("Camera capture failed");
            res = ESP_FAIL;
            break;
        }

        size_t hlen = snprintf(partBuf, sizeof(partBuf), STREAM_PART, fb->len);
        res = httpd_resp_send_chunk(req, STREAM_BOUNDARY, strlen(STREAM_BOUNDARY));
        if (res == ESP_OK)
            res = httpd_resp_send_chunk(req, partBuf, hlen);
        if (res == ESP_OK)
            res = httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);

        esp_camera_fb_return(fb);
        fb = NULL;

        if (res != ESP_OK) break;
    }
    return res;
}

void startStreamServer() {
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = HTTP_PORT;
    config.ctrl_port   = 32768;

    httpd_uri_t streamUri = {
        .uri      = "/stream",
        .method   = HTTP_GET,
        .handler  = streamHandler,
        .user_ctx = NULL
    };

    if (httpd_start(&streamHttpd, &config) == ESP_OK) {
        httpd_register_uri_handler(streamHttpd, &streamUri);
        Serial.println("Stream server started on /stream");
    }
}

// ---------------------------------------------------------------------------
// FreeRTOS task: LED heartbeat
// ---------------------------------------------------------------------------
void heartbeatTask(void *pvParameters) {
    (void)pvParameters;
    pinMode(PIN_LED, OUTPUT);
    for (;;) {
        digitalWrite(PIN_LED, !digitalRead(PIN_LED));
        vTaskDelay(pdMS_TO_TICKS(LED_INTERVAL_MS));
    }
}

// ---------------------------------------------------------------------------
// UDP command handler
// ---------------------------------------------------------------------------
void onUdpPacket(AsyncUDPPacket &packet) {
    // Parse JSON: {"l": <int>, "r": <int>}
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, packet.data(), packet.length());
    if (err) return;

    setCommand(doc["l"] | 0, doc["r"] | 0, CMD_TIMEOUT_MS);
}

// ---------------------------------------------------------------------------
// WiFi: join WIFI_SSID, or host our own AP if that doesn't work (e.g. guest
// networks with client isolation, which block UDP/HTTP between devices).
// ---------------------------------------------------------------------------
void startWifi() {
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    Serial.printf("Connecting to %s", WIFI_SSID);
    uint32_t start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_CONNECT_TIMEOUT_MS) {
        delay(500);
        Serial.print(".");
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\nConnected! IP: %s\n", WiFi.localIP().toString().c_str());
        return;
    }

    Serial.printf("\nCould not join %s, starting AP \"%s\"\n", WIFI_SSID, WIFI_AP_SSID);
    WiFi.disconnect(true);
    WiFi.mode(WIFI_AP);
    if (WiFi.softAP(WIFI_AP_SSID, WIFI_AP_PASS)) {
        Serial.printf("AP up. IP: %s\n", WiFi.softAPIP().toString().c_str());
    } else {
        Serial.println("AP start failed (password must be 8+ chars)");
    }
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------
void setup() {
    Serial.begin(115200);
    Serial.println("Trash Can Robot starting...");

    // Motor pins
    pinMode(PIN_IN1, OUTPUT);
    pinMode(PIN_IN2, OUTPUT);
    pinMode(PIN_IN3, OUTPUT);
    pinMode(PIN_IN4, OUTPUT);

    // LEDC PWM for motor enable pins
    ledcSetup(LEDC_CH_ENA, LEDC_FREQ, LEDC_RESOLUTION);
    ledcAttachPin(PIN_ENA, LEDC_CH_ENA);
    ledcSetup(LEDC_CH_ENB, LEDC_FREQ, LEDC_RESOLUTION);
    ledcAttachPin(PIN_ENB, LEDC_CH_ENB);

    applyMotors(0, 0);
    xTaskCreatePinnedToCore(motorTask, "motors", 3072, NULL, 3, NULL, 1);

    startWifi();

    // Camera
    if (!initCamera()) {
        Serial.println("FATAL: Camera init failed. Halting.");
        while (true) delay(1000);
    }

    // HTTP stream server
    startStreamServer();

    // UDP listener
    if (udp.listen(UDP_PORT)) {
        Serial.printf("UDP listening on port %d\n", UDP_PORT);
        udp.onPacket(onUdpPacket);
    }

    // FreeRTOS tasks
    xTaskCreatePinnedToCore(heartbeatTask, "heartbeat", 2048, NULL, 1, NULL, 1);

    Serial.println("Setup complete");
}

// ---------------------------------------------------------------------------
// Serial commands:
//   CAPTURE            — dumps one JPEG frame as base64 over serial
//   MOTOR <l> <r> [ms] — drives the motors (-255..255) for ms (default 1000,
//                        max 5000), then the failsafe stops them
//   STOP               — stops the motors immediately
// ---------------------------------------------------------------------------
static String serialBuf;

void handleMotorCommand(const String &args) {
    int l = 0, r = 0, ms = 1000;
    int n = sscanf(args.c_str(), "%d %d %d", &l, &r, &ms);
    if (n < 2) {
        Serial.println("MOTOR_ERR: usage MOTOR <l> <r> [ms]");
        return;
    }
    ms = constrain(ms, 0, (int)SERIAL_MOTOR_MAX_MS);
    setCommand(l, r, ms);
    Serial.printf("MOTOR_OK l=%d r=%d ms=%d\n", constrain(l, -255, 255),
                  constrain(r, -255, 255), ms);
}

void handleSerial() {
    while (Serial.available()) {
        char c = (char)Serial.read();
        if (c == '\n' || c == '\r') {
            serialBuf.trim();
            String upper = serialBuf;
            upper.toUpperCase();
            if (upper.startsWith("MOTOR ")) {
                handleMotorCommand(serialBuf.substring(6));
            } else if (upper == "STOP") {
                setCommand(0, 0, 0);
                Serial.println("STOP_OK");
            } else if (upper == "CAPTURE") {
                camera_fb_t *fb = esp_camera_fb_get();
                if (!fb) {
                    Serial.println("CAPTURE_ERR: camera frame failed");
                } else {
                    size_t maxLen = ((fb->len + 2) / 3) * 4 + 1;
                    uint8_t *b64buf = (uint8_t *)malloc(maxLen);
                    if (!b64buf) {
                        Serial.println("CAPTURE_ERR: malloc failed");
                    } else {
                        size_t outLen = 0;
                        mbedtls_base64_encode(b64buf, maxLen, &outLen, fb->buf, fb->len);
                        Serial.println("FRAME_START");
                        // Send in 76-char chunks so serial buffers don't choke
                        for (size_t i = 0; i < outLen; i += 76) {
                            size_t chunkLen = min((size_t)76, outLen - i);
                            Serial.write(b64buf + i, chunkLen);
                            Serial.println();
                        }
                        Serial.println("FRAME_END");
                        free(b64buf);
                    }
                    esp_camera_fb_return(fb);
                }
            }
            serialBuf = "";
        } else {
            serialBuf += c;
        }
    }
}

// ---------------------------------------------------------------------------
// Loop (idle -- work is in FreeRTOS tasks and callbacks)
// ---------------------------------------------------------------------------
void loop() {
    handleSerial();
    vTaskDelay(pdMS_TO_TICKS(10));
}
