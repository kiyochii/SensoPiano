module top (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] keys_raw,

    output wire        esp_txd,

    // debug
    output wire [11:0] keys_db,
    output wire        key_any,
    output wire        key_valid,
    output wire        key_error,
    output wire [3:0]  key_code_current,
    output wire [3:0]  key_code_reg,
    output wire        key_valid_pulse,
    output wire [1:0]  state_dbg,
    output wire        uart_busy
);

    wire load_key;

    wire [7:0] tx_tdata;
    wire       tx_tvalid;
    wire       tx_tready;

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

    uart_key_sender u_uart_key_sender (
        .clk       (clk),
        .rst       (rst),
        .send_pulse(key_valid_pulse),
        .key_code  (key_code_reg),
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