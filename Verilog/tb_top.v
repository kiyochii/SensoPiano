`timescale 1ms/1ps

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
        .rgb_b            (rgb_b)
    );

    // =========================================================
    // clock de 50 MHz -> 20 ns
    // =========================================================
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // =========================================================
    // Funções auxiliares para debug de estado
    // =========================================================
    function [127:0] uc_state_name;
        input [1:0] s;
        begin
            case (s)
                2'd0: uc_state_name = "SCAN";
                2'd1: uc_state_name = "REGISTER";
                2'd2: uc_state_name = "WAIT_RELEASE";
                default: uc_state_name = "UNKNOWN";
            endcase
        end
    endfunction

    function [127:0] mc_state_name;
        input [2:0] s;
        begin
            case (s)
                3'd0: mc_state_name = "FREE_MODE";
                3'd1: mc_state_name = "LEARN_IDLE";
                3'd2: mc_state_name = "LEARN_SHOW";
                3'd3: mc_state_name = "LEARN_WAIT";
                3'd4: mc_state_name = "LEARN_CHECK";
                3'd5: mc_state_name = "LEARN_DONE";
                default: mc_state_name = "UNKNOWN";
            endcase
        end
    endfunction

    // =========================================================
    // Task para apertar tecla
    // =========================================================
    task press_key;
        input integer idx;
        input integer hold_cycles;
        begin
            $display("\n[%0t] >>> PRESS_KEY: tecla=%0d, hold_cycles=%0d", $time, idx, hold_cycles);

            keys_raw = 12'd0;
            keys_raw[idx] = 1'b1;

            repeat (hold_cycles) @(posedge clk);

            $display("[%0t] <<< RELEASE_KEY: tecla=%0d", $time, idx);

            keys_raw = 12'd0;
            repeat (10) @(posedge clk);
        end
    endtask

    // =========================================================
    // Monitor principal: imprime sinais a cada borda de subida
    // =========================================================
    always @(posedge clk) begin
        $display("[%0t] clk | rst=%b mode_sel=%b start=%b keys_raw=%b | key_any=%b key_valid=%b key_error=%b key_code_current=%0d key_code_reg=%0d key_valid_pulse=%b | UC=%s | MC=%s | mc_send_note=%b mc_note_out=%0d correct=%b wrong=%b done=%b | leds_out=%b leds_out_reg=%b | rgb_r=%b rgb_g=%b rgb_b=%b | uart_busy=%b esp_txd=%b",
                 $time,
                 rst, mode_sel, start, keys_raw,
                 key_any, key_valid, key_error, key_code_current, key_code_reg, key_valid_pulse,
                 uc_state_name(state_dbg),
                 mc_state_name(mc_state_dbg),
                 mc_send_note, mc_note_out, mc_correct_pulse, mc_wrong_pulse, mc_done,
                 leds_out, leds_out_reg,
                 rgb_r, rgb_g, rgb_b,
                 uart_busy, esp_txd);
    end

    // =========================================================
    // Monitor de eventos importantes
    // =========================================================
    always @(posedge clk) begin
        if (key_valid_pulse) begin
            $display("[%0t] *** EVENTO: key_valid_pulse=1 | key_code_reg=%0d", $time, key_code_reg);
        end

        if (mc_send_note) begin
            $display("[%0t] *** EVENTO: mc_send_note=1 | mc_note_out=%0d", $time, mc_note_out);
        end

        if (mc_correct_pulse) begin
            $display("[%0t] *** EVENTO: tecla correta!", $time);
        end

        if (mc_wrong_pulse) begin
            $display("[%0t] *** EVENTO: tecla errada!", $time);
        end

        if (mc_done) begin
            $display("[%0t] *** EVENTO: musica concluida!", $time);
        end
    end

    // =========================================================
    // Detecta mudanças de estado da UC
    // =========================================================
    reg [1:0] last_state_dbg;
    reg [2:0] last_mc_state_dbg;

    always @(posedge clk) begin
        if (rst) begin
            last_state_dbg    <= 2'd0;
            last_mc_state_dbg <= 3'd0;
        end else begin
            if (state_dbg != last_state_dbg) begin
                $display("[%0t] >>> UC mudou de estado: %s -> %s",
                         $time, uc_state_name(last_state_dbg), uc_state_name(state_dbg));
            end

            if (mc_state_dbg != last_mc_state_dbg) begin
                $display("[%0t] >>> MC mudou de estado: %s -> %s",
                         $time, mc_state_name(last_mc_state_dbg), mc_state_name(mc_state_dbg));
            end

            last_state_dbg    <= state_dbg;
            last_mc_state_dbg <= mc_state_dbg;
        end
    end

    // =========================================================
    // Teste
    // =========================================================
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        $display("==============================================");
        $display("INICIO DA SIMULACAO");
        $display("==============================================");

        rst      = 1'b1;
        keys_raw = 12'd0;
        mode_sel = 1'b0;
        start    = 1'b0;

        repeat (10) @(posedge clk);
        rst = 1'b0;

        $display("\n==============================================");
        $display("TESTE 1 - MODO LIVRE");
        $display("==============================================");
        press_key(3, 20);
        press_key(7, 20);

        $display("\n==============================================");
        $display("TESTE 2 - MODO APRENDER (sequencia correta)");
        $display("==============================================");

        mode_sel = 1'b1;
        repeat (5) @(posedge clk);

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        repeat (10) @(posedge clk);
        press_key(0, 20);

        repeat (10) @(posedge clk);
        press_key(4, 20);

        repeat (10) @(posedge clk);
        press_key(7, 20);

        repeat (10) @(posedge clk);
        press_key(11, 20);

        repeat (50) @(posedge clk);

        $display("\n==============================================");
        $display("TESTE 3 - MODO APRENDER (erro)");
        $display("==============================================");

        rst = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;

        mode_sel = 1'b1;
        repeat (5) @(posedge clk);

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        repeat (10) @(posedge clk);
        press_key(2, 20);

        repeat (50) @(posedge clk);

        $display("\n==============================================");
        $display("FIM DA SIMULACAO");
        $display("==============================================");

        $finish;
    end

endmodule