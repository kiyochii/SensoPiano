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
    // serve para nada
    // =========================================================
    output wire [11:0] leds_out,   // LEDs simples (tecla ativa)
    
    // =========================================================
    // (shift register 74HC595)
    // =========================================================
    output wire        led_ser,    // DATA
    output wire        led_srclk,  // SHIFT CLOCK
    output wire        led_rclk,   // LATCH
    output wire        led_busy,   // opcional (debug útil)

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
    output wire        key_any,
    output wire        key_valid,
    output wire        key_error,
    output wire [3:0]  key_code_current,
    output wire [3:0]  key_code_reg,

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

    wire [7:0] tx_tdata;
    wire       tx_tvalid;
    wire       tx_tready;

    wire [11:0] mc_leds_out;
    wire [11:0] mc_rgb_r;
    wire [11:0] mc_rgb_g;
    wire [11:0] mc_rgb_b;
    wire [2:0]  mc_octave_out;

    wire [35:0] rgb_data;
    wire        shift_start;

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
        .key_code        (key_code_reg),
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
    assign leds_out     = mc_leds_out;
    assign leds_out_reg = (12'b000000000001 << key_code_reg);

    // =========================================================
    // RGB vindos do mode_controller
    // =========================================================
    assign rgb_r = mc_rgb_r;
    assign rgb_g = mc_rgb_g;
    assign rgb_b = mc_rgb_b;

    // =========================================================
    // Empacotamento RGB por LED
    // Ordem: LED11 ... LED0
    // Cada LED ocupa 3 bits: R, G, B
    // Se a ligação física estiver BGR, troque a ordem aqui
    // =========================================================
    assign rgb_data = {
        rgb_r[11], rgb_g[11], rgb_b[11],
        rgb_r[10], rgb_g[10], rgb_b[10],
        rgb_r[9],  rgb_g[9],  rgb_b[9],
        rgb_r[8],  rgb_g[8],  rgb_b[8],
        rgb_r[7],  rgb_g[7],  rgb_b[7],
        rgb_r[6],  rgb_g[6],  rgb_b[6],
        rgb_r[5],  rgb_g[5],  rgb_b[5],
        rgb_r[4],  rgb_g[4],  rgb_b[4],
        rgb_r[3],  rgb_g[3],  rgb_b[3],
        rgb_r[2],  rgb_g[2],  rgb_b[2],
        rgb_r[1],  rgb_g[1],  rgb_b[1],
        rgb_r[0],  rgb_g[0],  rgb_b[0]
    };

    // =========================================================
    // Atualização do shift register
    // =========================================================
    assign shift_start = key_valid_pulse | mc_send_note;

    shift595 u_shift595 (
        .clk   (clk),
        .rst   (rst),
        .start (shift_start),
        .data  (rgb_data),
        .ser   (led_ser),
        .srclk (led_srclk),
        .rclk  (led_rclk),
        .busy  (led_busy)
    );

    // =========================================================
    // Envio UART
    // Por enquanto ainda manda só a nota.
    // Depois você pode adaptar o sender para mandar {oitava, nota}.
    // =========================================================
    uart_key_sender u_uart_key_sender (
        .clk       (clk),
        .rst       (rst),
        .send_pulse(mc_send_note),
        .key_code  (mc_note_out),
        .tx_tdata  (tx_tdata),
        .tx_tvalid (tx_tvalid),
        .octave_code(mc_octave_out),
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
