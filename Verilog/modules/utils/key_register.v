module key_register (
    input  wire        clk,
    input  wire        rst,
    input  wire        load_key,
    input  wire [11:0] keys_in,
    output reg  [11:0] keys_out
);

    always @(posedge clk) begin
        if (rst)
            keys_out <= 12'd0;
        else if (load_key)
            keys_out <= keys_in;
    end

endmodule
