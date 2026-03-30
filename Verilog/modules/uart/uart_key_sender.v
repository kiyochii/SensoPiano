module uart_key_sender (
    input  wire       clk,
    input  wire       rst,

    input  wire       send_pulse,
    input  wire [3:0] key_code,
    input  wire [2:0] octave_code,

    output reg  [7:0] tx_tdata,
    output reg        tx_tvalid,
    input  wire       tx_tready
);

    reg pending;
    reg [7:0] data_buf;

    always @(posedge clk) begin
        if (rst) begin
            pending   <= 1'b0;
            data_buf  <= 8'd0;
            tx_tdata  <= 8'd0;
            tx_tvalid <= 1'b0;
        end else begin
            if (send_pulse && !pending) begin
                data_buf <= {1'b0, octave_code, key_code};
                pending  <= 1'b1;
            end

            if (pending) begin
                tx_tdata  <= data_buf;
                tx_tvalid <= 1'b1;

                if (tx_tvalid && tx_tready) begin
                    tx_tvalid <= 1'b0;
                    pending   <= 1'b0;
                end
            end else begin
                tx_tvalid <= 1'b0;
            end
        end
    end

endmodule