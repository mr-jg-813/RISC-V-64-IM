// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
//////////////////////////////////////////////////////////////////////////////////


module execute_pipe_unit #(
  parameter DATA_WIDTH = 64,
  parameter ADDRESS_BITS = 64
) (
  input clock,
  input reset,

  input [DATA_WIDTH-1:0] ALU_result_execute,
  input [DATA_WIDTH-1:0] store_data_execute,
  input [4:0] rd_execute,
  input [6:0] opcode_execute,
  input [1:0] next_PC_select_execute,
  input memRead_execute,
  input memWrite_execute,
  input regWrite_execute,
  input [31:0] instruction_execute,
  input [2:0] funct3_in,                                                    //added

  output reg [DATA_WIDTH-1:0] ALU_result_memory1,
  output reg [DATA_WIDTH-1:0] store_data_memory1,
  output reg [4:0] rd_memory1,
  output reg [6:0] opcode_memory1,
  output reg [1:0] next_PC_select_memory1,
  output reg memRead_memory1,
  output reg memWrite_memory1,
  output reg regWrite_memory1,
  output reg [31:0] instruction_memory1,
  output reg [2:0] funct3_out                                               //added

);

localparam NOP = 32'h00000013;

// Carry execute results and memory controls into Memory1.
always @(posedge clock) begin
  if(reset) begin
    ALU_result_memory1     <= {DATA_WIDTH{1'b0}};
    store_data_memory1     <= {DATA_WIDTH{1'b0}};
    rd_memory1             <= 5'b0;
    opcode_memory1         <= 7'b0;
    memRead_memory1        <= 1'b1;
    memWrite_memory1       <= 1'b0;
    next_PC_select_memory1 <= 2'b0;
    regWrite_memory1       <= 1'b0;
    funct3_out             <= 3'b0;                                         //added
    instruction_memory1    <= NOP;
  end else begin
    ALU_result_memory1     <= ALU_result_execute;
    store_data_memory1     <= store_data_execute;
    rd_memory1             <= rd_execute;
    opcode_memory1         <= opcode_execute;
    memRead_memory1        <= memRead_execute;
    memWrite_memory1       <= memWrite_execute;
    next_PC_select_memory1 <= next_PC_select_execute;
    regWrite_memory1       <= regWrite_execute;
    instruction_memory1    <= instruction_execute;
    funct3_out             <= funct3_in;                                    //added
  end
end

endmodule
