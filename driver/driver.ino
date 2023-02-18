#include <NeoPixelBus.h>

const uint16_t PIXEL_COUNT = 43;
const uint8_t PIXEL_PIN = 10;
const uint8_t SELECT_BTN_PIN = 2;
const uint8_t X_AXIS_PIN = A0;
const uint8_t Y_AXIS_PIN = A1;

const int OFFSET = 1024 / 2;
const int BUCKET_COUNT = 10;
const int BUCKET_WIDTH = 1024 / BUCKET_COUNT;
const int MULTIPLIER = 1<<2;

const NeoPixelBus<NeoGrbwFeature, Neo800KbpsMethod> strip(PIXEL_COUNT, PIXEL_PIN);

const RgbwColor color;
uint8_t* const color_components[] = {&color.R, &color.G, &color.B, &color.W};
const int COLOR_COMPONENT_COUNT = sizeof(color_components) / sizeof(color_components[0]);
int color_component_index = 0;
volatile int should_set_next_rgbw = false;

void setup() {
  pinMode(PIXEL_PIN, OUTPUT);
  pinMode(X_AXIS_PIN, INPUT);
  pinMode(Y_AXIS_PIN, INPUT);
  pinMode(SELECT_BTN_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(SELECT_BTN_PIN), set_next_rgbw_ISR, CHANGE);
}

void set_next_rgbw_ISR() {
  while (digitalRead(SELECT_BTN_PIN) == LOW);
  should_set_next_rgbw = true;
}

void clear_ISRs() {
  should_set_next_rgbw = false;
}

void set_next_rgbw() {
  color_component_index = (color_component_index + 1) % COLOR_COMPONENT_COUNT;
}

void update_color_component() {
  const int value_delta = MULTIPLIER * ((analogRead(X_AXIS_PIN) - OFFSET) / BUCKET_WIDTH);
  const int new_value = *color_components[color_component_index] + value_delta;
  *color_components[color_component_index] = min(max(new_value, 0), color.Max);
}

void update_strip() {
  for (int i = 0; i < PIXEL_COUNT; i++) {
    strip.SetPixelColor(i, color);
  }

  strip.Show();
}

void loop() {
  if (should_set_next_rgbw) {
    set_next_rgbw();
  }

  update_color_component();
  update_strip();

  clear_ISRs();
  delay(50);
}