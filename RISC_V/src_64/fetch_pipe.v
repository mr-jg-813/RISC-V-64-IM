// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
//////////////////////////////////////////////////////////////////////////////////

module fetch_pipe_unit #(
  parameter DATA_WIDTH = 64,
  parameter ADDRESS_BITS = 64
) (
  input clock,
  input reset,
  input stall,
  input flush,
  input [ADDRESS_BITS-1:0] inst_PC_fetch,
  input [31:0]   instruction_fetch,

  output reg [ADDRESS_BITS-1:0] inst_PC_decode,
  output reg [31:0]   instruction_decode
);

localparam NOP = 32'h00000013;

// Keep the instruction and its PC together; hold or flush both at once.
always @(posedge clock) begin
  if(reset) begin
    inst_PC_decode     <= {ADDRESS_BITS{1'b0}};
    instruction_decode <= NOP;
  end else begin
    inst_PC_decode     <= flush ? {ADDRESS_BITS{1'b0}} : stall ? inst_PC_decode : inst_PC_fetch;
    instruction_decode <= flush ? NOP : stall ? instruction_decode : instruction_fetch;
  end
end

endmodule

