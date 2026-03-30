module shift595 #(
    parameter WIDTH = 36
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             start,
    input  wire [WIDTH-1:0] data,

    output reg              ser,
    output reg              srclk,
    output reg              rclk,
    output reg              busy
);

    reg [WIDTH-1:0] shift;
    reg [$clog2(WIDTH+1)-1:0] count;
    reg phase;

    always @(posedge clk) begin
        if (rst) begin
            ser   <= 1'b0;
            srclk <= 1'b0;
            rclk  <= 1'b0;
            busy  <= 1'b0;
            phase <= 1'b0;
            shift <= {WIDTH{1'b0}};
            count <= {($clog2(WIDTH+1)){1'b0}};
        end else begin
            rclk <= 1'b0;

            if (start && !busy) begin
                busy  <= 1'b1;
                shift <= data;
                count <= WIDTH;
                phase <= 1'b0;
                srclk <= 1'b0;
            end else if (busy) begin
                phase <= ~phase;

                if (phase == 1'b0) begin
                    ser   <= shift[WIDTH-1];
                    srclk <= 1'b0;
                end else begin
                    srclk <= 1'b1;
                    shift <= shift << 1;

                    if (count > 0)
                        count <= count - 1'b1;

                    if (count == 1) begin
                        busy <= 1'b0;
                        rclk <= 1'b1;
                    end
                end
            end
        end
    end

endmodule