module key_encoder_12 (
    input  wire [11:0] keys_in,
    output reg         key_any,
    output reg         key_valid,
    output reg         key_error,
    output reg  [3:0]  key_code
);

    always @(*) begin
        key_any   = 1'b0;
        key_valid = 1'b0;
        key_error = 1'b0;
        key_code  = 4'd0;

        case (keys_in)
            12'b000000000000: begin
                key_any   = 1'b0;
                key_valid = 1'b0;
                key_error = 1'b0;
                key_code  = 4'd0;
            end

            12'b000000000001: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd0;  end
            12'b000000000010: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd1;  end
            12'b000000000100: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd2;  end
            12'b000000001000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd3;  end
            12'b000000010000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd4;  end
            12'b000000100000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd5;  end
            12'b000001000000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd6;  end
            12'b000010000000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd7;  end
            12'b000100000000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd8;  end
            12'b001000000000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd9;  end
            12'b010000000000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd10; end
            12'b100000000000: begin key_any = 1'b1; key_valid = 1'b1; key_code = 4'd11; end

            default: begin
                key_any   = 1'b1;
                key_valid = 1'b0;
                key_error = 1'b1;
                key_code  = 4'd0;
            end
        endcase
    end

endmodule