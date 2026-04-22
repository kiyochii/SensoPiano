`timescale 1ns / 1ps

module tb_top;

    localparam integer UART_BIT_NS = 8640;
    localparam integer KEY_SETTLE_NS = 1000;
    localparam integer UART_FRAME_GAP_NS = 120000;

    reg         clk;
    reg         rst;
    reg  [11:0] keys_raw;
    reg         mode_sel;
    reg         start;

    wire        esp_txd;

    wire [11:0] keys_db;
    wire [11:0] keys_reg;
    wire        key_any;
    wire        key_valid;
    wire        key_error;

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

    integer     uart_byte_count;
    integer     i;
    reg [7:0]   uart_rx_byte;

    top dut (
        .clk              (clk),
        .rst              (rst),
        .keys_raw         (keys_raw),
        .mode_sel         (mode_sel),
        .start            (start),
        .esp_txd          (esp_txd),

        .keys_db          (keys_db),
        .keys_reg         (keys_reg),
        .key_any          (key_any),
        .key_valid        (key_valid),
        .key_error        (key_error),

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
        .rgb_b            (rgb_b)
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
        uart_byte_count = 0;
        uart_rx_byte    = 8'd0;

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
        #KEY_SETTLE_NS;
        release_key(3);
        #UART_FRAME_GAP_NS;

        // -----------------------------------------
        // TESTE 2: modo livre, tecla 7
        // -----------------------------------------
        $display("=== TESTE 2: modo livre, tecla 7 ===");
        press_key(7);
        #KEY_SETTLE_NS;
        release_key(7);
        #UART_FRAME_GAP_NS;

        // -----------------------------------------
        // TESTE 3: duas teclas ao mesmo tempo no modo livre
        // -----------------------------------------
        $display("=== TESTE 3: modo livre com duas teclas ===");
        press_key(1);
        press_key(2);
        #KEY_SETTLE_NS;
        release_key(1);
        release_key(2);
        #UART_FRAME_GAP_NS;

        // -----------------------------------------
        // TESTE 4: modo aprender
        // -----------------------------------------
        $display("=== TESTE 4: entrar no modo aprender ===");
        mode_sel = 1'b1;
        #1000;
        pulse_start;

        // espera LEARN_SHOW/LEARN_WAIT
        #UART_FRAME_GAP_NS;

        // responde primeira nota esperada com tecla 0
        $display("=== TESTE 5: resposta do usuario no modo aprender ===");
        press_key(0);
        #KEY_SETTLE_NS;
        release_key(0);
        #UART_FRAME_GAP_NS;

        // responde com a tecla correta mesmo com outra pressionada junto
        $display("=== TESTE 6: modo aprender com tecla correta + extra ===");
        press_key(2);
        press_key(9);
        #KEY_SETTLE_NS;
        release_key(2);
        release_key(9);
        #UART_FRAME_GAP_NS;

        $display("=== FIM DA SIMULACAO ===");
        $finish;
    end

    // =========================================================
    // Debug textual
    // =========================================================
    always @(posedge clk) begin
        if (key_valid_pulse) begin
            $display("[%0t ns] key_valid_pulse | keys_reg=%b | leds_out=%b | leds_out_reg=%b",
                     $time, keys_reg, leds_out, leds_out_reg);
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

    always @(posedge uart_busy) begin
        if (!rst) begin
            uart_rx_byte = 8'd0;

            #((UART_BIT_NS * 3) / 2);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_byte[i] = esp_txd;
                #UART_BIT_NS;
            end

            uart_byte_count = uart_byte_count + 1;
            $display("[%0t ns] UART byte[%0d] = 0x%02h", $time, uart_byte_count, uart_rx_byte);

            case (uart_byte_count)
                1: if (uart_rx_byte !== 8'h43) begin
                    $display("ERRO: esperado 0x43 para tecla 3 em modo livre, recebido 0x%02h", uart_rx_byte);
                    $fatal;
                end
                2: if (uart_rx_byte !== 8'h47) begin
                    $display("ERRO: esperado 0x47 para tecla 7 em modo livre, recebido 0x%02h", uart_rx_byte);
                    $fatal;
                end
                3: if (uart_rx_byte !== 8'h30) begin
                    $display("ERRO: esperado 0x30 para primeira nota do modo aprender, recebido 0x%02h", uart_rx_byte);
                    $fatal;
                end
            endcase
        end
    end

endmodule
