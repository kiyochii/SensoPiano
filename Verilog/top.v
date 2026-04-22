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
    // comunicação com ESP32
    // =========================================================
    output wire        esp_txd,    // UART TX → RX do ESP32

    // =========================================================
    // Audio PWM simples
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
    wire debug_input_bypass;
    wire debug_uart_mode;

    wire [7:0] tx_tdata;
    wire       tx_tvalid;
    wire       tx_tready;

    wire [11:0] mc_leds_out;
    wire [11:0] mc_rgb_r;
    wire [11:0] mc_rgb_g;
    wire [11:0] mc_rgb_b;
    wire [2:0]  mc_octave_out;
    wire        uart_send_pulse;
    wire [3:0]  uart_note_out;
    wire [2:0]  uart_octave_out;

    reg         free_uart_pulse;
    reg [3:0]   free_uart_note;
    reg [23:0]  debug_uart_counter;
    reg         debug_uart_pulse;
    reg  [15:0] audio_counter;
    reg         audio_pwm_reg;

    wire        audio_enable;

    assign debug_input_bypass = !mode_sel && start;
    assign debug_uart_mode    = !mode_sel && start;
    assign audio_enable       = |keys_raw;
    assign audio_pwm          = audio_pwm_reg;

    function [3:0] key_vector_to_note;
        input [11:0] keys_in;
        begin
            key_vector_to_note = 4'd0;

            if (keys_in[0])
                key_vector_to_note = 4'd0;
            else if (keys_in[1])
                key_vector_to_note = 4'd1;
            else if (keys_in[2])
                key_vector_to_note = 4'd2;
            else if (keys_in[3])
                key_vector_to_note = 4'd3;
            else if (keys_in[4])
                key_vector_to_note = 4'd4;
            else if (keys_in[5])
                key_vector_to_note = 4'd5;
            else if (keys_in[6])
                key_vector_to_note = 4'd6;
            else if (keys_in[7])
                key_vector_to_note = 4'd7;
            else if (keys_in[8])
                key_vector_to_note = 4'd8;
            else if (keys_in[9])
                key_vector_to_note = 4'd9;
            else if (keys_in[10])
                key_vector_to_note = 4'd10;
            else if (keys_in[11])
                key_vector_to_note = 4'd11;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            free_uart_pulse   <= 1'b0;
            free_uart_note    <= 4'd0;
            debug_uart_counter <= 24'd0;
            debug_uart_pulse   <= 1'b0;
            audio_counter      <= 16'd0;
            audio_pwm_reg      <= 1'b0;
        end else begin
            free_uart_pulse <= (!mode_sel && !debug_uart_mode && key_valid_pulse);

            if (!mode_sel && key_valid_pulse)
                free_uart_note <= key_vector_to_note(keys_db & (~keys_db + 12'd1));

            if (debug_uart_mode) begin
                debug_uart_pulse <= 1'b0;

                if (debug_uart_counter == 24'd4_999_999) begin
                    debug_uart_counter <= 24'd0;
                    debug_uart_pulse   <= 1'b1;
                end else begin
                    debug_uart_counter <= debug_uart_counter + 24'd1;
                end
            end else begin
                debug_uart_counter <= 24'd0;
                debug_uart_pulse   <= 1'b0;
            end

            if (audio_enable) begin
                if (audio_counter == 16'd24_999) begin
                    audio_counter <= 16'd0;
                    audio_pwm_reg <= ~audio_pwm_reg;
                end else begin
                    audio_counter <= audio_counter + 16'd1;
                end
            end else begin
                audio_counter <= 16'd0;
                audio_pwm_reg <= 1'b0;
            end
        end
    end

    assign uart_send_pulse = debug_uart_mode ? debug_uart_pulse : (mode_sel ? mc_send_note : free_uart_pulse);
    assign uart_note_out   = debug_uart_mode ? 4'd5 : (mode_sel ? mc_note_out : free_uart_note);
    assign uart_octave_out = debug_uart_mode ? 3'd2 : (mode_sel ? mc_octave_out : 3'd4);

    // =========================================================
    // Fluxo de dados: debounce / validação / registro da tecla
    // =========================================================
    fluxo_dados u_fluxo_dados (
        .clk      (clk),
        .rst      (rst),
        .keys_raw (keys_raw),
        .debug_bypass(debug_input_bypass),
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
    // Envio UART
    // =========================================================
    uart_key_sender u_uart_key_sender (
        .clk       (clk),
        .rst       (rst),
        .send_pulse(uart_send_pulse),
        .note_code (uart_note_out),
        .tx_tdata  (tx_tdata),
        .tx_tvalid (tx_tvalid),
        .octave_code(uart_octave_out),
        .tx_tready (tx_tready)
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

endmodule
