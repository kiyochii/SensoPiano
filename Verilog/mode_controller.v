module mode_controller (
    input  wire        clk,
    input  wire        rst,

    input  wire        mode_sel,         // 0 = livre, 1 = aprender
    input  wire        start,            // inicia modo aprender

    input  wire [3:0]  key_code,
    input  wire        key_valid_pulse,

    output reg  [11:0] leds_out,
    output reg  [11:0] rgb_r,
    output reg  [11:0] rgb_g,
    output reg  [11:0] rgb_b,

    output reg         send_note,
    output reg  [3:0]  note_out,
    output reg  [2:0]  octave_out,

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
    reg [3:0] user_key;

    reg [6:0] expected_full;
    reg [3:0] expected_note;
    reg [2:0] expected_octave;

    wire [11:0] expected_onehot;
    wire [11:0] user_onehot;

    assign expected_onehot = (12'b000000000001 << expected_note);
    assign user_onehot     = (12'b000000000001 << key_code);

    // ==========================================
    // ROM simples da música
    // Formato: [6:4] = oitava, [3:0] = nota
    // ==========================================
    function [6:0] song_rom;
        input [1:0] idx;
        begin
            case (idx)
                2'd0: song_rom = 7'b011_0000; // oitava 3, nota 0
                2'd1: song_rom = 7'b100_0100; // oitava 4, nota 4
                2'd2: song_rom = 7'b101_0111; // oitava 5, nota 7
                2'd3: song_rom = 7'b110_1011; // oitava 6, nota 11
                default: song_rom = 7'b100_0000;
            endcase
        end
    endfunction

    // ==========================================
    // Registradores principais
    // ==========================================
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
                else if (state == LEARN_CHECK && user_key == expected_note) begin
                    if (song_index != 2'd3)
                        song_index <= song_index + 2'd1;
                end

                if (state == LEARN_WAIT && key_valid_pulse)
                    user_key <= key_code;
            end
        end
    end

    // ==========================================
    // Nota e oitava esperadas
    // ==========================================
    always @(*) begin
        expected_full   = song_rom(song_index);
        expected_octave = expected_full[6:4];
        expected_note   = expected_full[3:0];
    end

    // ==========================================
    // Próximo estado
    // ==========================================
    always @(*) begin
        next_state = state;

        case (state)
            FREE_MODE: begin
                if (mode_sel)
                    next_state = LEARN_IDLE;
            end

            LEARN_IDLE: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (start)
                    next_state = LEARN_SHOW;
            end

            LEARN_SHOW: begin
                next_state = LEARN_WAIT;
            end

            LEARN_WAIT: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (key_valid_pulse)
                    next_state = LEARN_CHECK;
            end

            LEARN_CHECK: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (user_key == expected_note) begin
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
            end

            default: begin
                next_state = FREE_MODE;
            end
        endcase
    end

    // ==========================================
    // Saídas
    // ==========================================
    always @(*) begin
        leds_out      = 12'd0;
        rgb_r         = 12'd0;
        rgb_g         = 12'd0;
        rgb_b         = 12'd0;

        send_note     = 1'b0;
        note_out      = 4'd0;
        octave_out    = 3'd0;

        correct_pulse = 1'b0;
        wrong_pulse   = 1'b0;
        done          = 1'b0;
        state_dbg     = state;

        case (state)

            FREE_MODE: begin
                if (key_valid_pulse) begin
                    leds_out   = user_onehot;

                    // branco no modo livre
                    rgb_r      = user_onehot;
                    rgb_g      = user_onehot;
                    rgb_b      = user_onehot;

                    send_note  = 1'b1;
                    note_out   = key_code;
                    octave_out = 3'd4;
                end
            end

            LEARN_SHOW: begin
                leds_out   = expected_onehot;
                send_note  = 1'b1;
                note_out   = expected_note;
                octave_out = expected_octave;

                // cor baseada na oitava
                case (expected_octave)
                    3'd0, 3'd1, 3'd2: rgb_r = expected_onehot; // grave
                    3'd3, 3'd4, 3'd5: rgb_g = expected_onehot; // médio
                    default:           rgb_b = expected_onehot; // agudo
                endcase
            end

            LEARN_WAIT: begin
                leds_out = expected_onehot;

                case (expected_octave)
                    3'd0, 3'd1, 3'd2: rgb_r = expected_onehot;
                    3'd3, 3'd4, 3'd5: rgb_g = expected_onehot;
                    default:           rgb_b = expected_onehot;
                endcase
            end

            LEARN_CHECK: begin
                if (user_key == expected_note)
                    correct_pulse = 1'b1;
                else
                    wrong_pulse = 1'b1;
            end

            LEARN_DONE: begin
                done = 1'b1;
            end
        endcase
    end

endmodule