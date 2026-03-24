module coord_to_key (
    input  wire [1:0] row_idx,
    input  wire [2:0] col_idx,
    input  wire       coord_valid,
    output reg        key_valid,
    output reg  [4:0] key_code
);

    always @(*) begin
        key_valid = 1'b0;
        key_code  = 5'd0;

        if (coord_valid) begin
            key_valid = 1'b1;
            key_code  = (row_idx * 5) + col_idx;
        end
    end

endmodule