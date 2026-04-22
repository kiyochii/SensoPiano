// Unidade de Controle (UC)
// Arquitetura atual: leitura direta de 12 teclas em GPIOs independentes,
// Função:
// 1) esperar uma tecla válida;
// 2) registrar a tecla uma única vez;
// 3) aguardar a liberação da tecla para evitar repetição.

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

    // Estados da FSM:
    // SCAN         -> espera uma tecla válida
    // REGISTER     -> gera pulso de registro da tecla
    // WAIT_RELEASE -> aguarda soltar a tecla antes de aceitar novo evento
    localparam SCAN         = 2'd0;
    localparam REGISTER     = 2'd1;
    localparam WAIT_RELEASE = 2'd2;

    reg [1:0] state, next_state;

    // Registrador de estado
    always @(posedge clk) begin
        if (rst)
            state <= SCAN;
        else
            state <= next_state;
    end

    // Lógica de transição de estados
    always @(*) begin
        next_state = state;

        case (state)
            SCAN: begin
                if (key_valid || key_error)
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

    // Lógica de saída (Moore)
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
