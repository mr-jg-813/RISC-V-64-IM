// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
//////////////////////////////////////////////////////////////////////////////////

module decode_pipe_unit #(
  parameter DATA_WIDTH = 64,
  parameter ADDRESS_BITS = 64
) (
  input clock, reset, stall,
  input [DATA_WIDTH-1:0] rs1_data_decode,
  input [DATA_WIDTH-1:0] rs2_data_decode,
  input [6:0] funct7_decode,
  input [2:0] funct3_decode,
  input [4:0] rd_decode,
  input [6:0] opcode_decode,
  input [DATA_WIDTH-1:0] extend_imm_decode,
  input [ADDRESS_BITS-1:0] branch_target_decode,
  input [ADDRESS_BITS-1:0] JAL_target_decode,
  input [ADDRESS_BITS-1:0] PC_decode,
  input branch_op_decode,
  input memRead_decode,
  input [3:0] ALUOp_decode,
  input memWrite_decode,
  input [1:0] next_PC_select_decode,
  input [1:0] next_PC_select_memory1,
  input [1:0] next_PC_select_memory2,
  input [1:0] operand_A_sel_decode,
  input operand_B_sel_decode,
  input regWrite_decode,
  input [31:0] instruction_decode,
  input [11:0] imm_d,
  input flush, 
  input ebreak_in,
  input ecall_in,
  input [8*DATA_WIDTH-1:0] ecall_args_in,

  output reg [DATA_WIDTH-1:0] rs1_data_execute,
  output reg [DATA_WIDTH-1:0] rs2_data_execute,
  output reg [6:0] funct7_execute,
  output reg [2:0] funct3_execute,
  output reg [4:0] rd_execute,
  output reg [6:0] opcode_execute,
  output reg [DATA_WIDTH-1:0] extend_imm_execute,
  output reg [ADDRESS_BITS-1:0] branch_target_execute,
  output reg [ADDRESS_BITS-1:0] JAL_target_execute,
  output reg [ADDRESS_BITS-1:0] PC_execute,
  output reg branch_op_execute,
  output reg memRead_execute,
  output reg [3:0] ALUOp_execute,
  output reg memWrite_execute,
  output reg [1:0] next_PC_select_execute,
  output reg [1:0] operand_A_sel_execute,
  output reg operand_B_sel_execute,
  output reg regWrite_execute,
  output reg [31:0] instruction_execute,
  output reg [11:0] imm_d_c,
  output reg ebreak_out,
  output reg ecall_out,
  output reg [8*DATA_WIDTH-1:0] ecall_args_out
);

localparam NOP = 32'h00000013;

wire bubble;

// Note: Breaking up stall and next_PC_select conditions into different
// if/else statments added 0.2MHz to Fmax but used ~15 more logic elements.
// For readability, they are combined into a single if condition.
// Flushes, redirects, and stalls inject a safe NOP into execute.
assign bubble = flush || 
                (next_PC_select_execute != 2'b00) ||
                (next_PC_select_memory1 != 2'b00) ||
                (next_PC_select_memory2 != 2'b00) ||
                stall;

// Carry decoded controls and ECALL data into execute.
always @(posedge clock) begin
  if(reset) begin
    rs1_data_execute       <= {DATA_WIDTH{1'b0}};
    rs2_data_execute       <= {DATA_WIDTH{1'b0}};
    funct7_execute         <= 7'b0;
    funct3_execute         <= 3'b0;
    rd_execute             <= 5'b0;
    opcode_execute         <= 7'b0;
    extend_imm_execute     <= {DATA_WIDTH{1'b0}};
    branch_target_execute  <= {ADDRESS_BITS{1'b0}};
    JAL_target_execute     <= {ADDRESS_BITS{1'b0}};
    PC_execute             <= {ADDRESS_BITS{1'b0}};
    branch_op_execute      <= 1'b0;
    memRead_execute        <= 1'b0;
    ALUOp_execute          <= 4'b0;
    memWrite_execute       <= 1'b0;
    next_PC_select_execute <= 2'b0;
    operand_A_sel_execute  <= 2'b0;
    operand_B_sel_execute  <= 1'b0;
    regWrite_execute       <= 1'b0;
    instruction_execute    <= NOP;
    imm_d_c                <= 11'b0;
    ebreak_out             <= 1'b0;
    ecall_out              <= 1'b0;
    ecall_args_out         <= {8*DATA_WIDTH{1'b0}};
  end else if(bubble) begin
    // Send ADDI zero zero 0
    rs1_data_execute       <= 5'd0;
    rs2_data_execute       <= 5'd0;
    funct7_execute         <= 7'd0;
    funct3_execute         <= 3'd0;
    rd_execute             <= 5'd0;
    opcode_execute         <= 7'h13; // ADDi
    branch_target_execute  <= {ADDRESS_BITS{1'b0}};
    JAL_target_execute     <= {ADDRESS_BITS{1'b0}};
    branch_op_execute      <= 1'b0;
    memRead_execute        <= 1'b0;
    ALUOp_execute          <= 4'd1; // I type
    memWrite_execute       <= 1'b0;
    next_PC_select_execute <= 2'd0;
    operand_A_sel_execute  <= 2'd0;
    operand_B_sel_execute  <= 1'b1; // 1 for I type
    regWrite_execute       <= 1'b1; // Decoded as 1, regfile prevents actual write
    extend_imm_execute     <= {DATA_WIDTH{1'b0}};
    PC_execute             <= {ADDRESS_BITS{1'b0}}; // should be held constant in fetch
    instruction_execute    <= NOP;
    imm_d_c                <= 11'b0;
    ebreak_out             <= 1'b0;
    ecall_out              <= 1'b0;
    ecall_args_out         <= {8*DATA_WIDTH{1'b0}};
  end else begin
    rs1_data_execute       <= rs1_data_decode;
    rs2_data_execute       <= rs2_data_decode;
    funct7_execute         <= funct7_decode;
    funct3_execute         <= funct3_decode;
    rd_execute             <= rd_decode;
    opcode_execute         <= opcode_decode;
    branch_target_execute  <= branch_target_decode;
    JAL_target_execute     <= JAL_target_decode;
    branch_op_execute      <= branch_op_decode;
    memRead_execute        <= memRead_decode;
    ALUOp_execute          <= ALUOp_decode;
    memWrite_execute       <= memWrite_decode;
    next_PC_select_execute <= next_PC_select_decode;
    operand_A_sel_execute  <= operand_A_sel_decode;
    operand_B_sel_execute  <= operand_B_sel_decode;
    regWrite_execute       <= regWrite_decode;
    extend_imm_execute     <= extend_imm_decode;
    PC_execute             <= PC_decode;
    imm_d_c                <= imm_d;
    // For Debugging
    instruction_execute    <= instruction_decode;
    ebreak_out             <= ebreak_in;
    ecall_out              <= ecall_in;
    ecall_args_out         <= ecall_args_in;
  end
end

endmodule

