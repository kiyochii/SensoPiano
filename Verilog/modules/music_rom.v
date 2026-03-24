module music_rom (
    input  wire [1:0] music_sel,   // Seleciona a música
    input  wire [3:0] note_idx,    // Índice da nota
    output reg  [3:0] note_out,    // Nota atual
    output reg  [3:0] song_length  // Tamanho da música
);

    // ROM combinacional de músicas
    always @(*) begin

        // valores padrão
        note_out    = 4'd0;
        song_length = 4'd0;

        case (music_sel)

            // =========================
            // Música 0
            // =========================
            2'd0: begin
                song_length = 4'd8;

                case (note_idx)
                    4'd0: note_out = 4'd0;
                    4'd1: note_out = 4'd2;
                    4'd2: note_out = 4'd4;
                    4'd3: note_out = 4'd5;
                    4'd4: note_out = 4'd7;
                    4'd5: note_out = 4'd5;
                    4'd6: note_out = 4'd4;
                    4'd7: note_out = 4'd2;
                endcase
            end

            // =========================
            // Música 1
            // =========================
            2'd1: begin
                song_length = 4'd6;

                case (note_idx)
                    4'd0: note_out = 4'd7;
                    4'd1: note_out = 4'd7;
                    4'd2: note_out = 4'd9;
                    4'd3: note_out = 4'd7;
                    4'd4: note_out = 4'd4;
                    4'd5: note_out = 4'd2;
                endcase
            end

            // =========================
            // Música 2
            // =========================
            2'd2: begin
                song_length = 4'd5;

                case (note_idx)
                    4'd0: note_out = 4'd0;
                    4'd1: note_out = 4'd4;
                    4'd2: note_out = 4'd7;
                    4'd3: note_out = 4'd11;
                    4'd4: note_out = 4'd7;
                endcase
            end

            // =========================
            // Música 3
            // =========================
            2'd3: begin
                song_length = 4'd4;

                case (note_idx)
                    4'd0: note_out = 4'd11;
                    4'd1: note_out = 4'd9;
                    4'd2: note_out = 4'd7;
                    4'd3: note_out = 4'd4;
                endcase
            end

        endcase
    end

endmodule