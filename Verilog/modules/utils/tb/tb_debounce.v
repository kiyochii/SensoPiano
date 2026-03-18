`timescale 1ns / 1ps

module tb_debouncer;

    reg clk;
    reg rst_n;
    reg button_in;
    wire button_out;

    // instância com debounce rápido (para simulação)
    debouncer #(
        .CLK_FREQ(1000),          // 1 kHz
        .DEBOUNCE_TIME_MS(5)      // 5 ms
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .button_in(button_in),
        .button_out(button_out)
    );

    // clock: 1 kHz → período = 1 ms → 1_000_000 ns
    initial begin
        clk = 0;
        forever #500_000 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_debouncer.vcd");
        $dumpvars(0, tb_debouncer);

        // reset
        rst_n = 0;
        button_in = 0;
        #2_000_000;
        rst_n = 1;

        $display("=== INICIO ===");

        // ------------------------------------------------
        // TESTE 1: bounce ao pressionar
        // ------------------------------------------------
        $display("=== Teste 1: bounce pressionando ===");

        // simula bounce (oscila rápido)
        button_in = 1; #200_000;
        button_in = 0; #200_000;
        button_in = 1; #200_000;
        button_in = 0; #200_000;
        button_in = 1;

        // espera debounce estabilizar
        #10_000_000;

        // ------------------------------------------------
        // TESTE 2: segurando pressionado
        // ------------------------------------------------
        $display("=== Teste 2: segurando ===");
        #5_000_000;

        // ------------------------------------------------
        // TESTE 3: bounce ao soltar
        // ------------------------------------------------
        $display("=== Teste 3: bounce soltando ===");

        button_in = 0; #200_000;
        button_in = 1; #200_000;
        button_in = 0; #200_000;
        button_in = 1; #200_000;
        button_in = 0;

        #10_000_000;

        // ------------------------------------------------
        // TESTE 4: múltiplos cliques rápidos
        // ------------------------------------------------
        $display("=== Teste 4: múltiplos cliques ===");

        repeat (3) begin
            button_in = 1;
            #8_000_000;
            button_in = 0;
            #8_000_000;
        end

        $display("=== FIM ===");
        #5_000_000;
        $finish;
    end

    // debug no terminal
    always @(posedge clk) begin
        $display("[%0t ns] in=%b out=%b", $time, button_in, button_out);
    end

endmodule