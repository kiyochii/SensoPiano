`timescale 1ns / 1ps

module tb_top;

    reg         clk;
    reg         rst;
    reg  [11:0] keys_raw;

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

    top dut (
        .clk              (clk),
        .rst              (rst),
        .keys_raw         (keys_raw),
        .esp_txd          (esp_txd),
        .keys_db          (keys_db),
        .key_any          (key_any),
        .key_valid        (key_valid),
        .key_error        (key_error),
        .key_code_current (key_code_current),
        .key_code_reg     (key_code_reg),
        .key_valid_pulse  (key_valid_pulse),
        .state_dbg        (state_dbg),
        .uart_busy        (uart_busy)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;   // 50 MHz
    end

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

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        rst = 1'b1;
        keys_raw = 12'b0;

        #100;
        rst = 1'b0;

        // espera sair do reset
        #100;

        // aperta tecla 3
        $display("=== Teste 1: tecla 3 ===");
        press_key(3);

        // espera debounce
        #25_000_000; // 25 ms em escala de simulação 1ns

        // segura mais um pouco
        #2_000_000;

        // solta
        release_key(3);

        // espera estabilizar
        #25_000_000;

        // aperta tecla 7
        $display("=== Teste 2: tecla 7 ===");
        press_key(7);
        #25_000_000;
        #2_000_000;
        release_key(7);
        #25_000_000;

        // erro: duas teclas ao mesmo tempo
        $display("=== Teste 3: erro com duas teclas ===");
        press_key(1);
        press_key(2);
        #25_000_000;
        release_key(1);
        release_key(2);
        #25_000_000;

        $display("Fim da simulacao.");
        $finish;
    end

    always @(posedge clk) begin
        if (key_valid_pulse) begin
            $display("[%0t ns] Nova tecla valida registrada: %0d", $time, key_code_reg);
        end
    end

endmodule