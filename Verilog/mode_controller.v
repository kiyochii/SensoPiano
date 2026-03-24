module mode_controller (
    input  wire       clk,
    input  wire       rst,

    input  wire       mode_sel,         // 0 = livre, 1 = aprender
    input  wire       start,            // inicia modo aprender

    input  wire [3:0] key_code,
    input  wire       key_valid_pulse,

    output reg  [11:0] leds_out,
    output reg         send_note,
    output reg  [3:0]  note_out,
    output reg         correct_pulse,
    output reg         wrong_pulse,
    output reg         done,
    output reg  [2:0]  state_dbg
);

    localparam FREE_MODE   = 3'd0;
    localparam LEARN_IDLE  = 3'd1;
    localparam LEARN_SHOW  = 3'd2;
    localparam LEARN_WAIT  = 3'd3;
    localparam LEARN_CHECK = 3'd4;
    localparam LEARN_DONE  = 3'd5;

    reg [2:0] state, next_state;

    reg [1:0] song_index;
    reg [3:0] expected_key;
    reg [3:0] user_key;

    // música de teste: 4 notas
    function [3:0] song_rom;
        input [1:0] idx;
        begin
            case (idx)
                2'd0: song_rom = 4'd0;
                2'd1: song_rom = 4'd4;
                2'd2: song_rom = 4'd7;
                2'd3: song_rom = 4'd11;
                default: song_rom = 4'd0;
            endcase
        end
    endfunction

    // registradores principais
    always @(posedge clk) begin
        if (rst) begin
            state      <= FREE_MODE;
            song_index <= 2'd0;
            user_key   <= 4'd0;
        end else begin
            state <= next_state;

            if (!mode_sel) begin
                song_index <= 2'd0;
            end else begin
                if (state == LEARN_IDLE && start)
                    song_index <= 2'd0;
                else if (state == LEARN_CHECK && key_valid_pulse && key_code == expected_key)
                    song_index <= song_index + 2'd1;

                if (state == LEARN_WAIT && key_valid_pulse)
                    user_key <= key_code;
            end
        end
    end

    // expected key
    always @(*) begin
        expected_key = song_rom(song_index);
    end

    // próxima lógica de estado
    always @(*) begin
        next_state = state;

        case (state)
            FREE_MODE: begin
                if (mode_sel)
                    next_state = LEARN_IDLE;
                else
                    next_state = FREE_MODE;
            end

            LEARN_IDLE: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (start)
                    next_state = LEARN_SHOW;
                else
                    next_state = LEARN_IDLE;
            end

            LEARN_SHOW: begin
                next_state = LEARN_WAIT;
            end

            LEARN_WAIT: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (key_valid_pulse)
                    next_state = LEARN_CHECK;
                else
                    next_state = LEARN_WAIT;
            end

            LEARN_CHECK: begin
                if (!mode_sel) begin
                    next_state = FREE_MODE;
                end else if (user_key == expected_key) begin
                    if (song_index == 2'd3)
                        next_state = LEARN_DONE;
                    else
                        next_state = LEARN_SHOW;
                end else begin
                    next_state = LEARN_SHOW;
                end
            end

            LEARN_DONE: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else
                    next_state = LEARN_DONE;
            end

            default: begin
                next_state = FREE_MODE;
            end
        endcase
    end

    // saídas
    always @(*) begin
        leds_out      = 12'd0;
        send_note     = 1'b0;
        note_out      = 4'd0;
        correct_pulse = 1'b0;
        wrong_pulse   = 1'b0;
        done          = 1'b0;
        state_dbg     = state;

        case (state)
            FREE_MODE: begin
                if (key_valid_pulse) begin
                    leds_out  = 12'b000000000001 << key_code;
                    send_note = 1'b1;
                    note_out  = key_code;
                end
            end

            LEARN_SHOW: begin
                leds_out  = 12'b000000000001 << expected_key;
                send_note = 1'b1;
                note_out  = expected_key;
            end

            LEARN_WAIT: begin
                leds_out = 12'b000000000001 << expected_key;
            end

            LEARN_CHECK: begin
                if (user_key == expected_key) begin
                    correct_pulse = 1'b1;
                end else begin
                    wrong_pulse = 1'b1;
                end
            end

            LEARN_DONE: begin
                done = 1'b1;
            end
        endcase
    end

endmodule