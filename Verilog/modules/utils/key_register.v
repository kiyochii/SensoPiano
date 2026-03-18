module key_register (
    input  wire       clk,
    input  wire       rst,
    input  wire       load_key,
    input  wire [3:0] key_code_in,
    output reg  [3:0] key_code_out
);

    always @(posedge clk) begin
        if (rst)
            key_code_out <= 4'd0;
        else if (load_key)
            key_code_out <= key_code_in;
    end

endmodule