module fluxo_dados (
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] keys_raw,
    input  wire        debug_bypass,

    input  wire        load_key,

    output wire        key_any,
    output wire        key_valid,
    output wire        key_error,
    output wire [11:0] keys_reg,
    output wire [11:0] keys_db
);

    reg  [11:0] keys_sync_0;
    reg  [11:0] keys_sync_1;
    wire [11:0] keys_selected;
    wire [11:0] keys_eval;

    always @(posedge clk) begin
        if (rst) begin
            keys_sync_0 <= 12'd0;
            keys_sync_1 <= 12'd0;
        end else begin
            keys_sync_0 <= keys_raw;
            keys_sync_1 <= keys_sync_0;
        end
    end

    debouncer u_db_0  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[0]),  .button_out(keys_db[0]));
    debouncer u_db_1  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[1]),  .button_out(keys_db[1]));
    debouncer u_db_2  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[2]),  .button_out(keys_db[2]));
    debouncer u_db_3  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[3]),  .button_out(keys_db[3]));
    debouncer u_db_4  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[4]),  .button_out(keys_db[4]));
    debouncer u_db_5  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[5]),  .button_out(keys_db[5]));
    debouncer u_db_6  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[6]),  .button_out(keys_db[6]));
    debouncer u_db_7  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[7]),  .button_out(keys_db[7]));
    debouncer u_db_8  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[8]),  .button_out(keys_db[8]));
    debouncer u_db_9  (.clk(clk), .rst_n(~rst), .button_in(keys_raw[9]),  .button_out(keys_db[9]));
    debouncer u_db_10 (.clk(clk), .rst_n(~rst), .button_in(keys_raw[10]), .button_out(keys_db[10]));
    debouncer u_db_11 (.clk(clk), .rst_n(~rst), .button_in(keys_raw[11]), .button_out(keys_db[11]));

    assign keys_eval     = debug_bypass ? keys_sync_1 : keys_db;
    assign key_any       = |keys_eval;
    assign key_valid     = key_any && ((keys_eval & (keys_eval - 12'd1)) == 12'd0);
    assign key_error     = key_any && !key_valid;
    assign keys_selected = keys_eval & (~keys_eval + 12'd1);

    key_register u_key_register (
        .clk      (clk),
        .rst      (rst),
        .load_key (load_key),
        .keys_in  (keys_selected),
        .keys_out (keys_reg)
    );

endmodule
