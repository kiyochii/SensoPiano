`timescale 1ns / 1ps

module tb_music_rom;

    reg  [1:0] music_sel;
    reg  [3:0] note_idx;
    wire [3:0] note_out;
    wire [3:0] song_length;

    music_rom dut (
        .music_sel   (music_sel),
        .note_idx    (note_idx),
        .note_out    (note_out),
        .song_length (song_length)
    );

    initial begin
        $dumpfile("tb_music_rom.vcd");
        $dumpvars(0, tb_music_rom);

        music_sel = 2'd0;
        note_idx  = 4'd0; #1;
        $display("musica=%0d idx=%0d nota=%0d len=%0d", music_sel, note_idx, note_out, song_length);

        note_idx = 4'd1; #1;
        $display("musica=%0d idx=%0d nota=%0d len=%0d", music_sel, note_idx, note_out, song_length);

        note_idx = 4'd7; #1;
        $display("musica=%0d idx=%0d nota=%0d len=%0d", music_sel, note_idx, note_out, song_length);

        music_sel = 2'd1;
        note_idx  = 4'd0; #1;
        $display("musica=%0d idx=%0d nota=%0d len=%0d", music_sel, note_idx, note_out, song_length);

        note_idx = 4'd5; #1;
        $display("musica=%0d idx=%0d nota=%0d len=%0d", music_sel, note_idx, note_out, song_length);

        music_sel = 2'd2;
        note_idx  = 4'd3; #1;
        $display("musica=%0d idx=%0d nota=%0d len=%0d", music_sel, note_idx, note_out, song_length);

        music_sel = 2'd3;
        note_idx  = 4'd2; #1;
        $display("musica=%0d idx=%0d nota=%0d len=%0d", music_sel, note_idx, note_out, song_length);

        $finish;
    end

endmodule