module shift595(

    input clk,
    input rst,
    input start,
    input [15:0] data,

    output reg ser,
    output reg srclk,
    output reg rclk,
    output reg busy
);

reg [15:0] shift;
reg [5:0] count;
reg phase;

//PARA CONTROLAR O CI DOS LEDS



always @(posedge clk) begin

    if (rst) begin
        busy <= 0;
        srclk <= 0;
        rclk <= 0;
        phase <= 0;
    end

    else begin

        if (start && !busy) begin
            busy <= 1;
            shift <= data;
            count <= 16;
            phase <= 0;
            rclk <= 0;
        end

        else if (busy) begin

            phase <= ~phase;

            if (phase == 0) begin
                ser <= shift[15];
                srclk <= 0;
            end

            else begin
                srclk <= 1;
                shift <= shift << 1;
                count <= count - 1;
            end

            if (count == 0 && phase == 1) begin
                busy <= 0;
                rclk <= 1;
            end
        end

        else begin
            rclk <= 0;
        end

    end

end

endmodule