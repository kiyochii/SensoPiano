module top (

    // =========================================================
    // OBRIGATÓRIO (clock e reset)
    // =========================================================
    input  wire        clk,        // CLOCK FPGA (ex: 50 MHz DE0-CV)
    input  wire        rst,        // RESET global

    // =========================================================
    // OBRIGATORIO (entrada do teclado físico)
    // =========================================================
    input  wire [11:0] keys_raw,   // 12 teclas físicas

    // =========================================================
    // OBRIGATORIO (controle do modo - pode ir pra botão)
    // =========================================================
    input  wire        mode_sel,   // chave: livre/aprender
    input  wire        start,      // botão: iniciar modo aprender

    // =========================================================
    // UART para ESP32
    // =========================================================
    output wire        esp_txd,    // UART TX -> RX do ESP32

    // =========================================================
    // Saida de audio 1-bit
    // =========================================================
    output wire        audio_pwm,

    // =========================================================
    // serve para nada
    // =========================================================
    output wire [11:0] leds_out,   // LEDs simples (tecla ativa)
    
    // =========================================================
    // RGB (depende se você realmente usar LED RGB)
    // =========================================================
    output wire [11:0] rgb_r,
    output wire [11:0] rgb_g,
    output wire [11:0] rgb_b,

    // =========================================================
    //  DEBUG
    // =========================================================
    output wire [11:0] keys_db,
    output wire [11:0] keys_reg,
    output wire        key_any,
    output wire        key_valid,
    output wire        key_error,

    output wire        key_valid_pulse,
    output wire [1:0]  state_dbg,

    output wire        uart_busy,

    output wire [11:0] leds_out_reg,

    output wire        mc_send_note,
    output wire [3:0]  mc_note_out,
    output wire        mc_correct_pulse,
    output wire        mc_wrong_pulse,
    output wire        mc_done,
    output wire [2:0]  mc_state_dbg

);
    wire load_key;

    wire [7:0]  tx_tdata;
    wire        tx_tvalid;
    wire        tx_tready;

    wire [11:0] mc_leds_out;
    wire [11:0] mc_rgb_r;
    wire [11:0] mc_rgb_g;
    wire [11:0] mc_rgb_b;
    wire [2:0]  mc_octave_out;
    wire        mc_tone_enable;
    wire [3:0]  mc_tone_note;
    wire [2:0]  mc_tone_octave;

    reg  [20:0] audio_half_period;
    reg  [20:0] audio_counter;
    reg         audio_out_reg;

    assign audio_pwm = audio_out_reg;

    // =========================================================
    // Fluxo de dados: debounce / validação / registro da tecla
    // =========================================================
    fluxo_dados u_fluxo_dados (
        .clk      (clk),
        .rst      (rst),
        .keys_raw (keys_raw),
        .load_key (load_key),
        .key_any  (key_any),
        .key_valid(key_valid),
        .key_error(key_error),
        .keys_reg (keys_reg),
        .keys_db  (keys_db)
    );

    // =========================================================
    // UC base
    // =========================================================
    UC u_uc (
        .clk             (clk),
        .rst             (rst),
        .key_any         (key_any),
        .key_valid       (key_valid),
        .key_error       (key_error),
        .load_key        (load_key),
        .key_valid_pulse (key_valid_pulse),
        .state_dbg       (state_dbg)
    );

    // =========================================================
    // Mode controller
    // =========================================================
    mode_controller u_mode_controller (
        .clk             (clk),
        .rst             (rst),
        .mode_sel        (mode_sel),
        .start           (start),
        .keys_db         (keys_db),
        .keys_reg        (keys_reg),
        .key_valid_pulse (key_valid_pulse),

        .leds_out        (mc_leds_out),
        .rgb_r           (mc_rgb_r),
        .rgb_g           (mc_rgb_g),
        .rgb_b           (mc_rgb_b),

        .send_note       (mc_send_note),
        .note_out        (mc_note_out),
        .octave_out      (mc_octave_out),
        .tone_enable     (mc_tone_enable),
        .tone_note       (mc_tone_note),
        .tone_octave     (mc_tone_octave),

        .correct_pulse   (mc_correct_pulse),
        .wrong_pulse     (mc_wrong_pulse),
        .done            (mc_done),
        .state_dbg       (mc_state_dbg)
    );

    // =========================================================
    // Visualizações simples
    // =========================================================
    // Saidas de LED na placa sao ativas em nivel baixo.
    assign leds_out     = ~mc_leds_out;
    assign leds_out_reg = ~keys_reg;

    // =========================================================
    // RGB vindos do mode_controller
    // =========================================================
    assign rgb_r = ~mc_rgb_r;
    assign rgb_g = ~mc_rgb_g;
    assign rgb_b = ~mc_rgb_b;

    // =========================================================
    // UART
    // =========================================================
    uart_key_sender u_uart_key_sender (
        .clk        (clk),
        .rst        (rst),
        .send_pulse (mc_send_note),
        .note_code  (mc_note_out),
        .octave_code(mc_octave_out),
        .tx_tdata   (tx_tdata),
        .tx_tvalid  (tx_tvalid),
        .tx_tready  (tx_tready)
    );

    uart_tx #(
        .DATA_WIDTH(8)
    ) u_uart_tx (
        .clk           (clk),
        .rst           (rst),
        .s_axis_tdata  (tx_tdata),
        .s_axis_tvalid (tx_tvalid),
        .s_axis_tready (tx_tready),
        .txd           (esp_txd),
        .busy          (uart_busy),
        .prescale      (16'd54)
    );

    // =========================================================
    // Geracao de audio 1-bit
    // =========================================================
    always @(*) begin
        case (mc_tone_note)
            4'd0:  audio_half_period = 21'd47778; // C
            4'd1:  audio_half_period = 21'd45098; // C#
            4'd2:  audio_half_period = 21'd42567; // D
            4'd3:  audio_half_period = 21'd40177; // D#
            4'd4:  audio_half_period = 21'd37922; // E
            4'd5:  audio_half_period = 21'd35792; // F
            4'd6:  audio_half_period = 21'd33784; // F#
            4'd7:  audio_half_period = 21'd31888; // G
            4'd8:  audio_half_period = 21'd30101; // G#
            4'd9:  audio_half_period = 21'd28409; // A
            4'd10: audio_half_period = 21'd26814; // A#
            4'd11: audio_half_period = 21'd25310; // B
            default: audio_half_period = 21'd0;
        endcase

        case (mc_tone_octave)
            3'd0: audio_half_period = audio_half_period << 4;
            3'd1: audio_half_period = audio_half_period << 3;
            3'd2: audio_half_period = audio_half_period << 2;
            3'd3: audio_half_period = audio_half_period << 1;
            3'd4: audio_half_period = audio_half_period;
            3'd5: audio_half_period = audio_half_period >> 1;
            3'd6: audio_half_period = audio_half_period >> 2;
            default: audio_half_period = audio_half_period >> 3;
        endcase
    end

    always @(posedge clk) begin
        if (rst || !mc_tone_enable || (audio_half_period <= 21'd1)) begin
            audio_counter <= 21'd0;
            audio_out_reg <= 1'b0;
        end else begin
            if (audio_counter >= (audio_half_period - 21'd1)) begin
                audio_counter <= 21'd0;
                audio_out_reg <= ~audio_out_reg;
            end else begin
                audio_counter <= audio_counter + 21'd1;
            end
        end
    end

endmodule
