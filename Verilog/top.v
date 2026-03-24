module top (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] keys_raw,

    // controle de modo
    input  wire        mode_sel,   // 0 = livre, 1 = aprender
    input  wire        start,      // inicia modo aprender

    output wire        esp_txd,

    // debug fluxo de dados
    output wire [11:0] keys_db,
    output wire        key_any,
    output wire        key_valid,
    output wire        key_error,
    output wire [3:0]  key_code_current,
    output wire [3:0]  key_code_reg,

    // debug UC base
    output wire        key_valid_pulse,
    output wire [1:0]  state_dbg,

    // debug UART
    output wire        uart_busy,

    // debug LEDs simples
    output wire [11:0] leds_out,       // tecla atual / visualização
    output wire [11:0] leds_out_reg,   // tecla registrada

    // debug mode controller
    output wire        mc_send_note,
    output wire [3:0]  mc_note_out,
    output wire        mc_correct_pulse,
    output wire        mc_wrong_pulse,
    output wire        mc_done,
    output wire [2:0]  mc_state_dbg,

    // RGB das 12 teclas
    output wire [11:0] rgb_r,
    output wire [11:0] rgb_g,
    output wire [11:0] rgb_b
);

    wire load_key;

    wire [7:0] tx_tdata;
    wire       tx_tvalid;
    wire       tx_tready;

    wire [11:0] mc_leds_out;

    // =========================================================
    // Fluxo de dados: debounce / validação / codificação da tecla
    // =========================================================
    fluxo_dados u_fluxo_dados (
        .clk              (clk),
        .rst              (rst),
        .keys_raw         (keys_raw),
        .load_key         (load_key),
        .key_any          (key_any),
        .key_valid        (key_valid),
        .key_error        (key_error),
        .key_code_current (key_code_current),
        .key_code_reg     (key_code_reg),
        .keys_db          (keys_db)
    );

    // =========================================================
    // UC base: registra tecla uma vez e espera soltar
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
    // Em modo livre:
    //   - acende tecla tocada
    //   - envia nota tocada
    // Em modo aprender:
    //   - mostra nota esperada
    //   - envia nota esperada no estado LEARN_SHOW
    // =========================================================
    mode_controller u_mode_controller (
        .clk             (clk),
        .rst             (rst),
        .mode_sel        (mode_sel),
        .start           (start),
        .key_code        (key_code_reg),
        .key_valid_pulse (key_valid_pulse),
        .leds_out        (mc_leds_out),
        .send_note       (mc_send_note),
        .note_out        (mc_note_out),
        .correct_pulse   (mc_correct_pulse),
        .wrong_pulse     (mc_wrong_pulse),
        .done            (mc_done),
        .state_dbg       (mc_state_dbg)
    );

    // =========================================================
    // Visualizações simples
    // =========================================================
    assign leds_out     = mc_leds_out;
    assign leds_out_reg = (12'b000000000001 << key_code_reg);

    // =========================================================
    // RGB
    // Por enquanto: acende em branco a tecla ativa do mode_controller
    // =========================================================
    assign rgb_r = mc_leds_out;
    assign rgb_g = mc_leds_out;
    assign rgb_b = mc_leds_out;

    // =========================================================
    // Envio UART
    // A UART agora segue o mode_controller
    // =========================================================
    uart_key_sender u_uart_key_sender (
        .clk       (clk),
        .rst       (rst),
        .send_pulse(mc_send_note),
        .key_code  (mc_note_out),
        .tx_tdata  (tx_tdata),
        .tx_tvalid (tx_tvalid),
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