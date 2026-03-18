//https://www.chipverify.com/verilog/verilog-debounce-circuit

module debouncer #(
    parameter CLK_FREQ = 50_000_000,    // Clock frequency in Hz
    parameter DEBOUNCE_TIME_MS = 20     // Debounce time in milliseconds
)(
    input wire clk,           // System clock
    input wire rst_n,         // Active low reset
    input wire button_in,     // Raw button input (noisy)
    output reg button_out     // Debounced button output
);

    // Calculate counter value for debounce time
    localparam COUNTER_MAX = (CLK_FREQ / 1000) * DEBOUNCE_TIME_MS;
    localparam COUNTER_WIDTH = $clog2(COUNTER_MAX + 1);

    // Internal registers
    reg [COUNTER_WIDTH-1:0] counter;
    reg button_sync_0, button_sync_1;

    // Double-flop synchronizer to avoid metastability
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            button_sync_0 <= 1'b0;
            button_sync_1 <= 1'b0;
        end else begin
            button_sync_0 <= button_in;
            button_sync_1 <= button_sync_0;
        end
    end

    // Debounce logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            button_out <= 1'b0;
        end else begin
            if (button_sync_1 != button_out) begin
                // Input differs from output, start/continue counting
                counter <= counter + 1;
                if (counter >= COUNTER_MAX) begin
                    button_out <= button_sync_1;
                    counter <= 0;
                end
            end else begin
                // Input matches output, reset counter
                counter <= 0;
            end
        end
    end

endmodule