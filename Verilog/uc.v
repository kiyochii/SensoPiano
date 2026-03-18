module UC (
    input  wire       clk,
    input  wire       rst,

    input  wire       key_any,
    input  wire       key_valid,
    input  wire       key_error,

    output reg        load_key,
    output reg        key_valid_pulse,
    output reg [1:0]  state_dbg
);

    localparam SCAN         = 2'd0;
    localparam REGISTER     = 2'd1;
    localparam WAIT_RELEASE = 2'd2;

    reg [1:0] state, next_state;

    always @(posedge clk) begin
        if (rst)
            state <= SCAN;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;

        case (state)
            SCAN: begin
                if (key_error)
                    next_state = WAIT_RELEASE;
                else if (key_valid)
                    next_state = REGISTER;
                else
                    next_state = SCAN;
            end

            REGISTER: begin
                next_state = WAIT_RELEASE;
            end

            WAIT_RELEASE: begin
                if (!key_any)
                    next_state = SCAN;
                else
                    next_state = WAIT_RELEASE;
            end

            default: begin
                next_state = SCAN;
            end
        endcase
    end

    always @(*) begin
        load_key        = 1'b0;
        key_valid_pulse = 1'b0;
        state_dbg       = state;

        case (state)
            REGISTER: begin
                load_key        = 1'b1;
                key_valid_pulse = 1'b1;
            end
        endcase
    end

endmodule