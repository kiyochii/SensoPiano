module mode_controller (
    input  wire        clk,
    input  wire        rst,

    input  wire        mode_sel,         // 0 = livre, 1 = aprender
    input  wire        start,            // inicia modo aprender

    input  wire [11:0] keys_db,
    input  wire [11:0] keys_reg,
    input  wire        key_valid_pulse,

    output reg  [11:0] leds_out,
    output reg  [11:0] rgb_r,
    output reg  [11:0] rgb_g,
    output reg  [11:0] rgb_b,

    output reg         send_note,
    output reg  [3:0]  note_out,
    output reg  [2:0]  octave_out,
    output reg         tone_enable,
    output reg  [3:0]  tone_note,
    output reg  [2:0]  tone_octave,

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
    reg [2:0] song_index;
    reg       expected_key_prev;
    reg       free_key_prev;
    reg [3:0] free_note_latched;
    reg [7:0] rand_lfsr;

    reg [6:0] expected_full;
    reg [3:0] expected_note;
    reg [2:0] expected_octave;

    wire [11:0] expected_onehot;
    wire        expected_key_down;
    wire        expected_key_pulse;
    wire        free_key_any;
    wire        free_press_pulse;

    assign expected_onehot   = (12'b000000000001 << expected_note);
    assign expected_key_down = keys_db[expected_note];
    assign expected_key_pulse = expected_key_down & ~expected_key_prev;
    assign free_key_any      = |keys_db;
    assign free_press_pulse  = free_key_any & ~free_key_prev;

    // ==========================================
    // ROM simples da música
    // Formato: [6:4] = oitava, [3:0] = nota
    // ==========================================
    function [6:0] song_rom;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: song_rom = 7'b011_0000; // oitava 3, nota 0
                3'd1: song_rom = 7'b100_0010; // oitava 4, nota 2
                3'd2: song_rom = 7'b101_0100; // oitava 5, nota 4
                3'd3: song_rom = 7'b110_0001; // oitava 6, nota 1
                3'd4: song_rom = 7'b101_0100; // oitava 5, nota 4
                3'd5: song_rom = 7'b110_0101; // oitava 6, nota 5
                default: song_rom = 7'b100_0000;
            endcase
        end
    endfunction

    function [3:0] key_vector_to_note;
        input [11:0] keys_in;
        begin
            key_vector_to_note = 4'd0;

            if (keys_in[0])
                key_vector_to_note = 4'd0;
            else if (keys_in[1])
                key_vector_to_note = 4'd1;
            else if (keys_in[2])
                key_vector_to_note = 4'd2;
            else if (keys_in[3])
                key_vector_to_note = 4'd3;
            else if (keys_in[4])
                key_vector_to_note = 4'd4;
            else if (keys_in[5])
                key_vector_to_note = 4'd5;
            else if (keys_in[6])
                key_vector_to_note = 4'd6;
            else if (keys_in[7])
                key_vector_to_note = 4'd7;
            else if (keys_in[8])
                key_vector_to_note = 4'd8;
            else if (keys_in[9])
                key_vector_to_note = 4'd9;
            else if (keys_in[10])
                key_vector_to_note = 4'd10;
            else if (keys_in[11])
                key_vector_to_note = 4'd11;
        end
    endfunction

    function [3:0] pick_note_from_keys;
        input [11:0] keys_in;
        input [3:0]  seed;
        reg   [3:0]  idx;
        reg   [3:0]  offset;
        reg          found;
        begin
            pick_note_from_keys = 4'd0;
            found = 1'b0;

            for (offset = 0; offset < 12; offset = offset + 1) begin
                idx = seed + offset;
                if (idx >= 4'd12)
                    idx = idx - 4'd12;

                if (!found && keys_in[idx]) begin
                    pick_note_from_keys = idx;
                    found = 1'b1;
                end
            end
        end
    endfunction

    // ==========================================
    // Registradores principais
    // ==========================================
    always @(posedge clk) begin
        if (rst) begin
            state             <= FREE_MODE;
            song_index        <= 3'd0;
            expected_key_prev <= 1'b0;
            free_key_prev     <= 1'b0;
            free_note_latched <= 4'd0;
            rand_lfsr         <= 8'hA5;
        end else begin
            state             <= next_state;
            expected_key_prev <= expected_key_down;
            free_key_prev     <= free_key_any;
            rand_lfsr         <= {rand_lfsr[6:0], rand_lfsr[7] ^ rand_lfsr[5] ^ rand_lfsr[4] ^ rand_lfsr[3]};

            if (!mode_sel) begin
                if (free_press_pulse)
                    free_note_latched <= pick_note_from_keys(keys_db, rand_lfsr[3:0]);
                else if (!free_key_any)
                    free_note_latched <= 4'd0;
            end

            if (!mode_sel) begin
                song_index <= 3'd0;
            end else begin
                if (state == LEARN_IDLE && start)
                    song_index <= 3'd0;
                else if (state == LEARN_CHECK && expected_key_prev) begin
                    if (song_index != 3'd5)
                        song_index <= song_index + 3'd1;
                end
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
                else if (expected_key_pulse)
                    next_state = LEARN_CHECK;
            end

            LEARN_CHECK: begin
                if (!mode_sel)
                    next_state = FREE_MODE;
                else if (expected_key_prev) begin
                    if (song_index == 3'd5)
                        next_state = LEARN_DONE;
                    else
                        next_state = LEARN_SHOW;
                end else begin
                    next_state = LEARN_WAIT;
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
        tone_enable   = 1'b0;
        tone_note     = 4'd0;
        tone_octave   = 3'd0;

        correct_pulse = 1'b0;
        wrong_pulse   = 1'b0;
        done          = 1'b0;
        state_dbg     = state;

        case (state)
            FREE_MODE: begin
                leds_out = keys_db;
                rgb_r    = keys_db;
                rgb_g    = keys_db;
                rgb_b    = keys_db;

                if (free_key_any) begin
                    tone_enable = 1'b1;
                    if (free_press_pulse)
                        tone_note = pick_note_from_keys(keys_db, rand_lfsr[3:0]);
                    else
                        tone_note = free_note_latched;
                    tone_octave = 3'd4;
                end

                if (free_press_pulse) begin
                    send_note  = 1'b1;
                    note_out   = pick_note_from_keys(keys_db, rand_lfsr[3:0]);
                    octave_out = 3'd4;
                end
            end

            LEARN_SHOW: begin
                leds_out   = expected_onehot;
                send_note  = 1'b1;
                note_out   = expected_note;
                octave_out = expected_octave;
                tone_enable = 1'b1;
                tone_note   = expected_note;
                tone_octave = expected_octave;

                case (expected_octave)
                    3'd0, 3'd1, 3'd2: rgb_r = expected_onehot; // grave
                    3'd3, 3'd4, 3'd5: rgb_g = expected_onehot; // medio
                    default:           rgb_b = expected_onehot; // agudo
                endcase
            end

            LEARN_WAIT: begin
                leds_out = expected_onehot;
                tone_enable = 1'b1;
                tone_note   = expected_note;
                tone_octave = expected_octave;

                case (expected_octave)
                    3'd0, 3'd1, 3'd2: rgb_r = expected_onehot;
                    3'd3, 3'd4, 3'd5: rgb_g = expected_onehot;
                    default:           rgb_b = expected_onehot;
                endcase
            end

            LEARN_CHECK: begin
                if (expected_key_prev)
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
