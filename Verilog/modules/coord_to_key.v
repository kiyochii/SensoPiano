module coord_to_key (
    input  wire [1:0] row_idx,
    input  wire [2:0] col_idx,
    input  wire       coord_valid,
    output reg        key_valid,
    output reg  [4:0] key_code
);

//como a gente vai enviar para o ESP32 acho que fazer dessa maneira faz mais sentido

    always @(*) begin
        key_valid = 1'b0;
        key_code  = 5'd0;

        if (coord_valid) begin
            case ({row_idx, col_idx})

                {2'd0, 3'd0}: begin key_valid = 1'b1; key_code = 5'd0;  end;
                {2'd0, 3'd1}: begin key_valid = 1'b1; key_code = 5'd1;  end;
                {2'd0, 3'd2}: begin key_valid = 1'b1; key_code = 5'd2;  end;
                {2'd0, 3'd3}: begin key_valid = 1'b1; key_code = 5'd3;  end;
                {2'd0, 3'd4}: begin key_valid = 1'b1; key_code = 5'd4;  end;

                {2'd1, 3'd0}: begin key_valid = 1'b1; key_code = 5'd5;  end;
                {2'd1, 3'd1}: begin key_valid = 1'b1; key_code = 5'd6;  end;
                {2'd1, 3'd2}: begin key_valid = 1'b1; key_code = 5'd7;  end;
                {2'd1, 3'd3}: begin key_valid = 1'b1; key_code = 5'd8;  end;
                {2'd1, 3'd4}: begin key_valid = 1'b1; key_code = 5'd9;  end;

                {2'd2, 3'd0}: begin key_valid = 1'b1; key_code = 5'd10; end;
                {2'd2, 3'd1}: begin key_valid = 1'b1; key_code = 5'd11; end;
                {2'd2, 3'd2}: begin key_valid = 1'b1; key_code = 5'd12; end;
                {2'd2, 3'd3}: begin key_valid = 1'b1; key_code = 5'd13; end;
                {2'd2, 3'd4}: begin key_valid = 1'b1; key_code = 5'd14; end;

                {2'd3, 3'd0}: begin key_valid = 1'b1; key_code = 5'd15; end;
                {2'd3, 3'd1}: begin key_valid = 1'b1; key_code = 5'd16; end;
                {2'd3, 3'd2}: begin key_valid = 1'b1; key_code = 5'd17; end;
                {2'd3, 3'd3}: begin key_valid = 1'b1; key_code = 5'd18; end;
                {2'd3, 3'd4}: begin key_valid = 1'b1; key_code = 5'd19; end;

                default: begin
                    key_valid = 1'b0;
                    key_code  = 5'd0;
                end
            endcase
        end
    end

endmodule