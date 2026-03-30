#include <Arduino.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>

// =======================
// Ajustes de hardware
// =======================
#define UART_TX_PIN            17
#define UART_RX_PIN            18
#define UART_BAUD_RATE         115200

#define SPEAKER_GPIO           19

#define RX_SILENCE_TIMEOUT_MS  3000
#define DEBUG_REPORT_MS        5000

// =======================
// LEDC
// =======================
#define LEDC_DUTY_RES_BITS     10
#define LEDC_MAX_DUTY          ((1 << LEDC_DUTY_RES_BITS) - 1)
#define PIANO_ATTACK_DUTY      220
#define PIANO_SUSTAIN_DUTY     90

// =======================
// Mapeamento musical
// =======================
static const char *note_names[12] = {
  "C", "C#", "D", "D#", "E", "F",
  "F#", "G", "G#", "A", "A#", "B"
};

// =======================
// Estruturas de debug
// =======================
typedef struct {
  uint32_t total_bytes;
  uint32_t valid_notes;
  uint32_t silence_cmds;
  uint32_t invalid_notes;
  uint32_t ledc_errors;
  uint32_t uart_timeouts;
  uint8_t  last_byte;
  uint32_t last_freq_hz;
  uint32_t last_rx_time_ms;
  bool     speaker_on;
} debug_stats_t;

static debug_stats_t g_stats = {0};

// =======================
// Utilitários
// =======================
static uint32_t now_ms(void)
{
  return millis();
}

static void byte_to_binary_str(uint8_t value, char *out)
{
  for (int i = 7; i >= 0; --i) {
    out[7 - i] = (value & (1 << i)) ? '1' : '0';
  }
  out[8] = '\0';
}

static double note_to_freq(uint8_t octave, uint8_t note)
{
  int midi = 12 * ((int)octave + 1) + (int)note;
  return 440.0 * pow(2.0, ((double)midi - 69.0) / 12.0);
}

static void log_decoded_byte(uint8_t rx_byte, uint8_t octave, uint8_t note)
{
  char bin_str[9];
  byte_to_binary_str(rx_byte, bin_str);

  Serial.print("RX byte=0x");
  if (rx_byte < 0x10) Serial.print("0");
  Serial.print(rx_byte, HEX);
  Serial.print(" bin=");
  Serial.print(bin_str);
  Serial.print(" | bit7=");
  Serial.print((rx_byte >> 7) & 0x01);
  Serial.print(" | oitava(bits6:4)=");
  Serial.print(octave);
  Serial.print(" | nota(bits3:0)=");
  Serial.println(note);
}

static void print_debug_report(void)
{
  Serial.println("========== DEBUG REPORT ==========");
  Serial.print("total_bytes   = ");   Serial.println(g_stats.total_bytes);
  Serial.print("valid_notes   = ");   Serial.println(g_stats.valid_notes);
  Serial.print("silence_cmds  = ");   Serial.println(g_stats.silence_cmds);
  Serial.print("invalid_notes = ");   Serial.println(g_stats.invalid_notes);
  Serial.print("ledc_errors   = ");   Serial.println(g_stats.ledc_errors);
  Serial.print("uart_timeouts = ");   Serial.println(g_stats.uart_timeouts);

  Serial.print("last_byte     = 0x");
  if (g_stats.last_byte < 0x10) Serial.print("0");
  Serial.println(g_stats.last_byte, HEX);

  Serial.print("last_freq_hz  = ");   Serial.println(g_stats.last_freq_hz);
  Serial.print("speaker_on    = ");   Serial.println(g_stats.speaker_on ? "true" : "false");
  Serial.print("last_rx_ms    = ");   Serial.println(g_stats.last_rx_time_ms);
  Serial.println("==================================");
}

// =======================
// Speaker estilo piano
// =======================
static bool set_volume(uint32_t duty)
{
  if (duty > LEDC_MAX_DUTY) duty = LEDC_MAX_DUTY;
  return ledcWrite(SPEAKER_GPIO, duty);
}

static bool speaker_init(void)
{
  bool ok = ledcAttach(SPEAKER_GPIO, 1000, LEDC_DUTY_RES_BITS);

  if (!ok) {
    Serial.print("Falha ao anexar LEDC no GPIO ");
    Serial.println(SPEAKER_GPIO);
    g_stats.ledc_errors++;
    return false;
  }

  set_volume(0);

  Serial.print("Speaker inicializado no GPIO ");
  Serial.println(SPEAKER_GPIO);
  return true;
}

static bool speaker_stop(void)
{
  for (int d = PIANO_SUSTAIN_DUTY; d >= 0; d -= 8) {
    if (!set_volume((uint32_t)d)) {
      Serial.println("Falha ao reduzir volume no release");
      g_stats.ledc_errors++;
      return false;
    }
    delay(2);
  }

  if (!set_volume(0)) {
    Serial.println("Falha ao desligar speaker");
    g_stats.ledc_errors++;
    return false;
  }

  g_stats.speaker_on = false;
  g_stats.last_freq_hz = 0;
  return true;
}

static bool speaker_play_freq(uint32_t freq_hz)
{
  if (freq_hz == 0) {
    return speaker_stop();
  }

  uint32_t real_freq = ledcWriteTone(SPEAKER_GPIO, freq_hz);

  if (real_freq == 0) {
    Serial.print("Falha ao configurar LEDC para ");
    Serial.print(freq_hz);
    Serial.println(" Hz");
    g_stats.ledc_errors++;
    return false;
  }

  for (int d = 0; d <= PIANO_ATTACK_DUTY; d += 12) {
    if (!set_volume((uint32_t)d)) {
      Serial.println("Falha no attack");
      g_stats.ledc_errors++;
      return false;
    }
    delay(1);
  }

  for (int d = PIANO_ATTACK_DUTY; d >= PIANO_SUSTAIN_DUTY; d -= 6) {
    if (!set_volume((uint32_t)d)) {
      Serial.println("Falha no decay");
      g_stats.ledc_errors++;
      return false;
    }
    delay(2);
  }

  if (!set_volume(PIANO_SUSTAIN_DUTY)) {
    Serial.println("Falha no sustain");
    g_stats.ledc_errors++;
    return false;
  }

  if (real_freq != freq_hz) {
    Serial.print("LEDC ajustou freq pedida=");
    Serial.print(freq_hz);
    Serial.print(" Hz para freq real=");
    Serial.print(real_freq);
    Serial.println(" Hz");
  }

  g_stats.speaker_on = true;
  g_stats.last_freq_hz = real_freq;
  return true;
}

// =======================
// UART
// =======================
static bool uart_music_init(void)
{
  Serial1.begin(UART_BAUD_RATE, SERIAL_8N1, UART_RX_PIN, UART_TX_PIN);

  Serial.print("UART inicializada | baud=");
  Serial.print(UART_BAUD_RATE);
  Serial.print(" tx=");
  Serial.print(UART_TX_PIN);
  Serial.print(" rx=");
  Serial.println(UART_RX_PIN);

  return true;
}

// =======================
// Processamento do protocolo
// =======================
static void process_rx_byte(uint8_t rx_byte)
{
  uint8_t octave = (rx_byte >> 4) & 0x07;
  uint8_t note   = rx_byte & 0x0F;

  g_stats.total_bytes++;
  g_stats.last_byte = rx_byte;
  g_stats.last_rx_time_ms = now_ms();

  log_decoded_byte(rx_byte, octave, note);

  if (rx_byte & 0x80) {
    Serial.println("WARN: bit7 veio em 1 (0x80). Atualmente ele nao esta sendo usado.");
  }

  if (note <= 11) {
    double freq = note_to_freq(octave, note);
    uint32_t freq_hz = (uint32_t)(freq + 0.5);

    Serial.print("Nota valida | oitava=");
    Serial.print(octave);
    Serial.print(" | nota=");
    Serial.print(note_names[note]);
    Serial.print(" | freq_calc=");
    Serial.print(freq, 2);
    Serial.print(" Hz | freq_round=");
    Serial.print(freq_hz);
    Serial.println(" Hz");

    if (speaker_play_freq(freq_hz)) {
      g_stats.valid_notes++;
    } else {
      Serial.println("ERRO: Falha ao tocar nota");
    }
  }
  else if (note == 15) {
    Serial.println("Comando de SILENCIO recebido");
    if (speaker_stop()) {
      g_stats.silence_cmds++;
    }
  }
  else {
    Serial.print("WARN: Nota invalida recebida: ");
    Serial.println(note);
    g_stats.invalid_notes++;
    speaker_stop();
  }
}

void setup()
{
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("Inicializando...");

  uart_music_init();
  speaker_init();

  g_stats.last_rx_time_ms = now_ms();

  Serial.println("Pronto. Aguardando bytes UART...");
  Serial.println("Formato esperado: [6:4]=oitava, [3:0]=nota");
  Serial.println("Notas 0..11 = C..B");
  Serial.println("Nota 15 = silencio");
  Serial.println("Notas 12,13,14 = invalidas");
  Serial.println("bit7 atualmente ignorado");
}

void loop()
{
  static uint32_t last_report_ms = 0;

  if (Serial1.available() > 0) {
    int data = Serial1.read();
    if (data >= 0) {
      process_rx_byte((uint8_t)data);
    }
  } else {
    g_stats.uart_timeouts++;

    uint32_t idle_ms = now_ms() - g_stats.last_rx_time_ms;

    if (g_stats.speaker_on && idle_ms >= RX_SILENCE_TIMEOUT_MS) {
      Serial.print("WARN: Sem dados UART por ");
      Serial.print(idle_ms);
      Serial.println(" ms. Desligando speaker por seguranca/debug.");
      speaker_stop();
    }

    delay(1);
  }

  uint32_t now = now_ms();
  if ((now - last_report_ms) >= DEBUG_REPORT_MS) {
    print_debug_report();
    last_report_ms = now;
  }
}