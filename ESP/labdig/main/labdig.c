#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <inttypes.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "driver/uart.h"
#include "driver/ledc.h"

#include "esp_err.h"
#include "esp_log.h"
#include "esp_timer.h"

// =======================
// Configuração de logs
// =======================
#define TAG "UART_MUSIC"

// Ajuste conforme necessidade:
// ESP_LOG_ERROR, ESP_LOG_WARN, ESP_LOG_INFO, ESP_LOG_DEBUG, ESP_LOG_VERBOSE
#ifndef LOG_LOCAL_LEVEL
#define LOG_LOCAL_LEVEL ESP_LOG_INFO
#endif

// =======================
// Ajustes de hardware
// =======================
#define UART_PORT              UART_NUM_1
#define UART_TX_PIN            17
#define UART_RX_PIN            18
#define UART_BAUD_RATE         115200
#define UART_BUF_SIZE          256
#define UART_READ_TIMEOUT_MS   200

#define SPEAKER_GPIO           4

// Timeout sem receber nada -> desliga speaker
#define RX_SILENCE_TIMEOUT_MS  3000

// Intervalo de relatório de debug
#define DEBUG_REPORT_MS        5000

// =======================
// LEDC
// =======================
#define LEDC_MODE_USED         LEDC_LOW_SPEED_MODE
#define LEDC_TIMER_USED        LEDC_TIMER_0
#define LEDC_CHANNEL_USED      LEDC_CHANNEL_0
#define LEDC_DUTY_RES          LEDC_TIMER_10_BIT
#define LEDC_DUTY_50PCT        512   // 50% de 1024

// =======================
// Mapeamento musical
// =======================
// nota: 0..11 = C, C#, D, D#, E, F, F#, G, G#, A, A#, B
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
    int64_t  last_rx_time_ms;
    bool     speaker_on;
} debug_stats_t;

static debug_stats_t g_stats = {0};

// =======================
// Utilitários
// =======================
static int64_t now_ms(void)
{
    return esp_timer_get_time() / 1000;
}

static void byte_to_binary_str(uint8_t value, char *out)
{
    // precisa de pelo menos 9 bytes
    for (int i = 7; i >= 0; --i) {
        out[7 - i] = (value & (1 << i)) ? '1' : '0';
    }
    out[8] = '\0';
}

/*
 * Frequência calculada por temperamento igual:
 * f = 440 * 2^((midi - 69)/12)
 *
 * Fórmula MIDI:
 * midi = 12 * (oitava + 1) + nota
 *
 * Ex.: A4 = oitava 4, nota 9 => midi = 69 => 440 Hz
 */
static double note_to_freq(uint8_t octave, uint8_t note)
{
    int midi = 12 * ((int)octave + 1) + (int)note;
    return 440.0 * pow(2.0, ((double)midi - 69.0) / 12.0);
}

static void log_decoded_byte(uint8_t rx_byte, uint8_t octave, uint8_t note)
{
    char bin_str[9];
    byte_to_binary_str(rx_byte, bin_str);

    ESP_LOGI(TAG,
             "RX byte=0x%02X bin=%s | bit7=%u | oitava(bits6:4)=%u | nota(bits3:0)=%u",
             rx_byte,
             bin_str,
             (rx_byte >> 7) & 0x01,
             octave,
             note);
}

static void print_debug_report(void)
{
    ESP_LOGI(TAG, "========== DEBUG REPORT ==========");
    ESP_LOGI(TAG, "total_bytes   = %" PRIu32, g_stats.total_bytes);
    ESP_LOGI(TAG, "valid_notes   = %" PRIu32, g_stats.valid_notes);
    ESP_LOGI(TAG, "silence_cmds  = %" PRIu32, g_stats.silence_cmds);
    ESP_LOGI(TAG, "invalid_notes = %" PRIu32, g_stats.invalid_notes);
    ESP_LOGI(TAG, "ledc_errors   = %" PRIu32, g_stats.ledc_errors);
    ESP_LOGI(TAG, "uart_timeouts = %" PRIu32, g_stats.uart_timeouts);
    ESP_LOGI(TAG, "last_byte     = 0x%02X", g_stats.last_byte);
    ESP_LOGI(TAG, "last_freq_hz  = %" PRIu32, g_stats.last_freq_hz);
    ESP_LOGI(TAG, "speaker_on    = %s", g_stats.speaker_on ? "true" : "false");
    ESP_LOGI(TAG, "last_rx_ms    = %" PRId64, g_stats.last_rx_time_ms);
    ESP_LOGI(TAG, "==================================");
}

// =======================
// Speaker
// =======================
static esp_err_t speaker_init(void)
{
    ledc_timer_config_t timer_cfg = {
        .speed_mode       = LEDC_MODE_USED,
        .duty_resolution  = LEDC_DUTY_RES,
        .timer_num        = LEDC_TIMER_USED,
        .freq_hz          = 1000,   // valor inicial
        .clk_cfg          = LEDC_AUTO_CLK
    };

    esp_err_t err = ledc_timer_config(&timer_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em ledc_timer_config: %s", esp_err_to_name(err));
        return err;
    }

    ledc_channel_config_t channel_cfg = {
        .gpio_num       = SPEAKER_GPIO,
        .speed_mode     = LEDC_MODE_USED,
        .channel        = LEDC_CHANNEL_USED,
        .intr_type      = LEDC_INTR_DISABLE,
        .timer_sel      = LEDC_TIMER_USED,
        .duty           = 0,
        .hpoint         = 0,
        .sleep_mode     = LEDC_SLEEP_MODE_NO_ALIVE_NO_PD
    };

    err = ledc_channel_config(&channel_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em ledc_channel_config: %s", esp_err_to_name(err));
        return err;
    }

    ESP_LOGI(TAG, "Speaker inicializado no GPIO %d", SPEAKER_GPIO);
    return ESP_OK;
}

static esp_err_t speaker_stop(void)
{
    esp_err_t err;

    err = ledc_set_duty(LEDC_MODE_USED, LEDC_CHANNEL_USED, 0);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em ledc_set_duty(stop): %s", esp_err_to_name(err));
        g_stats.ledc_errors++;
        return err;
    }

    err = ledc_update_duty(LEDC_MODE_USED, LEDC_CHANNEL_USED);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em ledc_update_duty(stop): %s", esp_err_to_name(err));
        g_stats.ledc_errors++;
        return err;
    }

    g_stats.speaker_on = false;
    g_stats.last_freq_hz = 0;
    return ESP_OK;
}

static esp_err_t speaker_play_freq(uint32_t freq_hz)
{
    if (freq_hz == 0) {
        return speaker_stop();
    }

    esp_err_t err;

    uint32_t real_freq = ledc_set_freq(LEDC_MODE_USED, LEDC_TIMER_USED, freq_hz);
    if (real_freq == 0) {
        ESP_LOGE(TAG, "Falha ao configurar LEDC para %lu Hz", (unsigned long)freq_hz);
        g_stats.ledc_errors++;
        return ESP_FAIL;
    }

    if (real_freq != freq_hz) {
        ESP_LOGW(TAG,
                 "LEDC ajustou freq pedida=%lu Hz para freq real=%lu Hz",
                 (unsigned long)freq_hz,
                 (unsigned long)real_freq);
    }

    err = ledc_set_duty(LEDC_MODE_USED, LEDC_CHANNEL_USED, LEDC_DUTY_50PCT);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em ledc_set_duty(play): %s", esp_err_to_name(err));
        g_stats.ledc_errors++;
        return err;
    }

    err = ledc_update_duty(LEDC_MODE_USED, LEDC_CHANNEL_USED);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em ledc_update_duty(play): %s", esp_err_to_name(err));
        g_stats.ledc_errors++;
        return err;
    }

    g_stats.speaker_on = true;
    g_stats.last_freq_hz = real_freq;
    return ESP_OK;
}

// =======================
// UART
// =======================
static esp_err_t uart_music_init(void)
{
    const uart_config_t uart_config = {
        .baud_rate  = UART_BAUD_RATE,
        .data_bits  = UART_DATA_8_BITS,
        .parity     = UART_PARITY_DISABLE,
        .stop_bits  = UART_STOP_BITS_1,
        .flow_ctrl  = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };

    esp_err_t err;

    err = uart_driver_install(UART_PORT, UART_BUF_SIZE, 0, 0, NULL, 0);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em uart_driver_install: %s", esp_err_to_name(err));
        return err;
    }

    err = uart_param_config(UART_PORT, &uart_config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em uart_param_config: %s", esp_err_to_name(err));
        return err;
    }

    err = uart_set_pin(UART_PORT, UART_TX_PIN, UART_RX_PIN,
                       UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro em uart_set_pin: %s", esp_err_to_name(err));
        return err;
    }

    ESP_LOGI(TAG,
             "UART inicializada | port=%d baud=%d tx=%d rx=%d",
             UART_PORT, UART_BAUD_RATE, UART_TX_PIN, UART_RX_PIN);

    return ESP_OK;
}

// =======================
// Processamento do protocolo
// =======================
static void process_rx_byte(uint8_t rx_byte)
{
    uint8_t octave = (rx_byte >> 4) & 0x07;  // bits 6:4
    uint8_t note   = rx_byte & 0x0F;         // bits 3:0

    g_stats.total_bytes++;
    g_stats.last_byte = rx_byte;
    g_stats.last_rx_time_ms = now_ms();

    log_decoded_byte(rx_byte, octave, note);

    // bit7 pode ser usado futuramente como flag/protocolo
    if (rx_byte & 0x80) {
        ESP_LOGW(TAG, "bit7 veio em 1 (0x80). Atualmente ele nao esta sendo usado.");
    }

    if (note <= 11) {
        double freq = note_to_freq(octave, note);
        uint32_t freq_hz = (uint32_t)(freq + 0.5);

        ESP_LOGI(TAG,
                 "Nota valida | oitava=%u | nota=%s | freq_calc=%.2f Hz | freq_round=%lu Hz",
                 octave,
                 note_names[note],
                 freq,
                 (unsigned long)freq_hz);

        if (speaker_play_freq(freq_hz) == ESP_OK) {
            g_stats.valid_notes++;
        } else {
            ESP_LOGE(TAG, "Falha ao tocar nota");
        }
    }
    else if (note == 15) {
        ESP_LOGI(TAG, "Comando de SILENCIO recebido");
        if (speaker_stop() == ESP_OK) {
            g_stats.silence_cmds++;
        }
    }
    else {
        ESP_LOGW(TAG, "Nota invalida recebida: %u", note);
        g_stats.invalid_notes++;
        speaker_stop();
    }
}

void app_main(void)
{
    esp_err_t err;

    err = uart_music_init();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Falha ao iniciar UART. Encerrando app_main.");
        return;
    }

    err = speaker_init();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Falha ao iniciar speaker. Encerrando app_main.");
        return;
    }

    ESP_LOGI(TAG, "Pronto. Aguardando bytes UART...");
    ESP_LOGI(TAG, "Formato esperado: [6:4]=oitava, [3:0]=nota");
    ESP_LOGI(TAG, "Notas 0..11 = C..B");
    ESP_LOGI(TAG, "Nota 15 = silencio");
    ESP_LOGI(TAG, "Notas 12,13,14 = invalidas");
    ESP_LOGI(TAG, "bit7 atualmente ignorado");

    uint8_t rx_byte;
    int64_t last_report_ms = now_ms();

    while (1) {
        int len = uart_read_bytes(UART_PORT, &rx_byte, 1, pdMS_TO_TICKS(UART_READ_TIMEOUT_MS));

        if (len == 1) {
            process_rx_byte(rx_byte);
        } else {
            g_stats.uart_timeouts++;

            int64_t idle_ms = now_ms() - g_stats.last_rx_time_ms;

            if (g_stats.speaker_on && idle_ms >= RX_SILENCE_TIMEOUT_MS) {
                ESP_LOGW(TAG,
                         "Sem dados UART por %" PRId64 " ms. Desligando speaker por seguranca/debug.",
                         idle_ms);
                speaker_stop();
            }
        }

        int64_t now = now_ms();
        if ((now - last_report_ms) >= DEBUG_REPORT_MS) {
            print_debug_report();
            last_report_ms = now;
        }
    }
}