`timescale 1ns / 1ps

module tb_top;

    reg         clk;
    reg         rst;
    reg  [11:0] keys_raw;
    reg         mode_sel;
    reg         start;

    wire        esp_txd;

    wire [11:0] keys_db;
    wire        key_any;
    wire        key_valid;
    wire        key_error;
    wire [3:0]  key_code_current;
    wire [3:0]  key_code_reg;

    wire        key_valid_pulse;
    wire [1:0]  state_dbg;

    wire        uart_busy;

    wire [11:0] leds_out;
    wire [11:0] leds_out_reg;

    wire        mc_send_note;
    wire [3:0]  mc_note_out;
    wire        mc_correct_pulse;
    wire        mc_wrong_pulse;
    wire        mc_done;
    wire [2:0]  mc_state_dbg;

    wire [11:0] rgb_r;
    wire [11:0] rgb_g;
    wire [11:0] rgb_b;

    wire        led_ser;
    wire        led_srclk;
    wire        led_rclk;
    wire        led_busy;

    top dut (
        .clk              (clk),
        .rst              (rst),
        .keys_raw         (keys_raw),
        .mode_sel         (mode_sel),
        .start            (start),
        .esp_txd          (esp_txd),

        .keys_db          (keys_db),
        .key_any          (key_any),
        .key_valid        (key_valid),
        .key_error        (key_error),
        .key_code_current (key_code_current),
        .key_code_reg     (key_code_reg),

        .key_valid_pulse  (key_valid_pulse),
        .state_dbg        (state_dbg),

        .uart_busy        (uart_busy),

        .leds_out         (leds_out),
        .leds_out_reg     (leds_out_reg),

        .mc_send_note     (mc_send_note),
        .mc_note_out      (mc_note_out),
        .mc_correct_pulse (mc_correct_pulse),
        .mc_wrong_pulse   (mc_wrong_pulse),
        .mc_done          (mc_done),
        .mc_state_dbg     (mc_state_dbg),

        .rgb_r            (rgb_r),
        .rgb_g            (rgb_g),
        .rgb_b            (rgb_b),

        .led_ser          (led_ser),
        .led_srclk        (led_srclk),
        .led_rclk         (led_rclk),
        .led_busy         (led_busy)
    );

    // =========================================================
    // Clock 50 MHz
    // =========================================================
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // =========================================================
    // Tasks
    // =========================================================
    task press_key;
        input integer idx;
        begin
            keys_raw[idx] = 1'b1;
        end
    endtask

    task release_key;
        input integer idx;
        begin
            keys_raw[idx] = 1'b0;
        end
    endtask

    task pulse_start;
        begin
            start = 1'b1;
            #20;
            start = 1'b0;
        end
    endtask

    // =========================================================
    // Test sequence
    // =========================================================
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        rst      = 1'b1;
        keys_raw = 12'b0;
        mode_sel = 1'b0; // modo livre
        start    = 1'b0;

        #100;
        rst = 1'b0;

        // -----------------------------------------
        // TESTE 1: modo livre, tecla 3
        // -----------------------------------------
        $display("=== TESTE 1: modo livre, tecla 3 ===");
        press_key(3);
        #25_000_000;   // > 20 ms debounce
        #2_000_000;
        release_key(3);
        #25_000_000;

        // -----------------------------------------
        // TESTE 2: modo livre, tecla 7
        // -----------------------------------------
        $display("=== TESTE 2: modo livre, tecla 7 ===");
        press_key(7);
        #25_000_000;
        #2_000_000;
        release_key(7);
        #25_000_000;

        // -----------------------------------------
        // TESTE 3: duas teclas ao mesmo tempo
        // -----------------------------------------
        $display("=== TESTE 3: erro com duas teclas ===");
        press_key(1);
        press_key(2);
        #25_000_000;
        release_key(1);
        release_key(2);
        #25_000_000;

        // -----------------------------------------
        // TESTE 4: modo aprender
        // -----------------------------------------
        $display("=== TESTE 4: entrar no modo aprender ===");
        mode_sel = 1'b1;
        #1000;
        pulse_start;

        // espera LEARN_SHOW/LEARN_WAIT
        #5_000_000;

        // responde primeira nota esperada com tecla 0
        $display("=== TESTE 5: resposta do usuario no modo aprender ===");
        press_key(0);
        #25_000_000;
        #2_000_000;
        release_key(0);
        #25_000_000;

        // mais uma resposta
        press_key(4);
        #25_000_000;
        #2_000_000;
        release_key(4);
        #25_000_000;

        $display("=== FIM DA SIMULACAO ===");
        $finish;
    end

    // =========================================================
    // Debug textual
    // =========================================================
    always @(posedge clk) begin
        if (key_valid_pulse) begin
            $display("[%0t ns] key_valid_pulse | key_code_reg=%0d | leds_out=%b | leds_out_reg=%b",
                     $time, key_code_reg, leds_out, leds_out_reg);
        end

        if (mc_send_note) begin
            $display("[%0t ns] mc_send_note | nota=%0d", $time, mc_note_out);
        end

        if (mc_correct_pulse) begin
            $display("[%0t ns] ACERTO", $time);
        end

        if (mc_wrong_pulse) begin
            $display("[%0t ns] ERRO", $time);
        end
    end

    always @(posedge uart_busy) begin
        $display("[%0t ns] UART iniciou transmissao", $time);
    end

    always @(negedge uart_busy) begin
        $display("[%0t ns] UART terminou transmissao", $time);
    end

    always @(posedge led_rclk) begin
        $display("[%0t ns] Shift register latch", $time);
    end

endmodule