// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
// Implement the RISC-V semihosting SYS_WRITEC operation (a0=3, a1=byte ptr).
// The host-facing character is exposed through the core's existing output pins.
module semihost_putchar #(
    parameter DATA_WIDTH = 64,
    parameter ADDRESS_BITS = 64,
    parameter MEM_ADDR_BITS = 14
)(
    input clock,
    input reset,
    input request,
    input [DATA_WIDTH-1:0] address,
    output read_enable,
    output [ADDRESS_BITS-1:0] read_address,
    input [DATA_WIDTH-1:0] read_data,
    output reg [7:0] char_data,
    output reg char_valid
);

localparam [1:0] IDLE = 2'd0, READ = 2'd1, CAPTURE = 2'd2;
reg [1:0] state;
reg [DATA_WIDTH-1:0] byte_address;

assign read_enable = (state == READ);
assign read_address = byte_address;

always @(posedge clock) begin
    if (reset) begin
        state <= IDLE;
        byte_address <= {DATA_WIDTH{1'b0}};
        char_data <= 8'b0;
        char_valid <= 1'b0;
    end else begin
        char_valid <= 1'b0;
        case (state)
            IDLE: if (request) begin
                byte_address <= address;
                state <= READ;
            end
            READ: state <= CAPTURE;
            CAPTURE: begin
                char_data <= read_data[7:0];
                char_valid <= 1'b1;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
