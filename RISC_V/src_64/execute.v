// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
// 32-bit Exection
module execution_unit #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 64,
  parameter ADDRESS_BITS = 64,
  parameter PRINT_CYCLES_MIN = 1,
  parameter PRINT_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input stall,
  input [3:0] ALU_Operation,
  input [6:0] funct7,
  input [2:0] funct3_in,                                //Added
  input [ADDRESS_BITS-1:0] PC,
  input [1:0] ALU_ASrc,
  input ALU_BSrc,
  input branch_op,
  input [DATA_WIDTH-1:0] regRead_1,
  input [DATA_WIDTH-1:0] regRead_2,
  input [DATA_WIDTH-1:0] extend,

  output zero,
  output branch,
  output [DATA_WIDTH-1:0] ALU_result, 
  output [ADDRESS_BITS-1:0] JALR_target,
  output [2:0] funct3_out,                                    //Added
  input report
);

wire [6:0] ALU_Control;
wire [DATA_WIDTH-1:0] operand_A;
wire [DATA_WIDTH-1:0] operand_B;
wire ALU_branch;

// Combine the operation class with funct3/funct7 to select the ALU action.
assign ALU_Control =
    (ALU_Operation == 4'b0011) ? 7'b0011_111 : // pass for JAL and JALR
    (ALU_Operation == 4'b0010) ? {4'b0010, funct3_in} : // branches

    // R Type instructions
    ({ALU_Operation, funct7} == {4'b0000, 7'b0000000}) ? // most reg type inst
        {4'b0000, funct3_in} : 
        
    ({ALU_Operation, funct7} == {4'b0000, 7'b0100000}) ? // sub and sra
        {4'b0001, funct3_in} : 
        
    // I Type instructions
    ({ALU_Operation, funct3_in, funct7[6:1]} == {4'b0001, 3'b101, 6'b000000}) ? // SRLI
        {4'b0000, funct3_in} :
        
    ({ALU_Operation, funct3_in, funct7[6:1]} == {4'b0001, 3'b101, 6'b010000}) ? // SRAI
        {4'b0001, funct3_in} : 
        
    (ALU_Operation == 4'b0001) ? {4'b0000, funct3_in} : // all other imm

    // R Type 64 instructions
    ({ALU_Operation, funct7} == {4'b0111, 7'b0000000}) ? {4'b0100, funct3_in} : // ADDW, SLLW, and SRLW
    
    ({ALU_Operation, funct7} == {4'b0111, 7'b0100000}) ? {4'b0101, funct3_in} : // SUBW and SRAW

    // I Type 64 instructions
    ({ALU_Operation, funct3_in, funct7} == {4'b1000, 3'b101, 7'b0100000}) ? // SRAIW
        {4'b0101, funct3_in} : 
        
    (ALU_Operation == 4'b1000) ? {4'b0100, funct3_in} : // ADDIW, SLLIW, and SRLIW
    
    ({ALU_Operation, funct7} == {4'b1001,7'b0000001}) ? {4'b1001, funct3_in} :  // mult 
    ({ALU_Operation, funct7} == {4'b1010,7'b0000001}) ? {4'b1010, funct3_in} :  // mult_64

    7'b0000000; // default: addition
                     

// Choose the ALU inputs and form the JALR destination.
assign operand_A = (ALU_ASrc == 2'b01) ? PC     :
                   (ALU_ASrc == 2'b10) ? PC + 4 :
                   (ALU_ASrc == 2'b11) ? {DATA_WIDTH{1'b0}}  :
                   regRead_1;

assign operand_B = ALU_BSrc ? extend : regRead_2;
assign branch    = (ALU_branch & branch_op)? 1 : 0;

assign funct3_out = funct3_in;                                                  //Added

// Only JALR Target. JAL happens in the decode unit
assign JALR_target = (regRead_1 + extend) & {{(ADDRESS_BITS-1){1'b1}},1'b0};


ALU #(DATA_WIDTH) EU (
        .ALU_Control(ALU_Control),
        .operand_A(operand_A),
        .operand_B(operand_B),
        .ALU_result(ALU_result),
        .zero(zero),
        .branch(ALU_branch)
);

reg [31: 0] cycles;
always @ (posedge clock) begin
    cycles <= reset? 0 : cycles + 1;
    //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
   if (report) begin
        $display ("------ Core %d Execute Unit - Current Cycle %d ------", CORE, cycles);
        $display ("| ALU_Operat  [%b]", ALU_Operation);
        $display ("| funct7      [%b]", funct7);
        $display ("| funct3_in   [%b]", funct3_in);
        $display ("| ALU_Control [%b]", ALU_Control);
        $display ("| branch_op   [%b]", branch_op);
        $display ("| regRead_1   [%h]", regRead_1);
        $display ("| regRead_2   [%h]", regRead_2);
        $display ("| operand_A   [%h]", operand_A);
        $display ("| operand_B   [%h]", operand_B);
        $display ("| Zero        [%b]", zero);
        $display ("| Branch      [%b]", branch);
        $display ("| ALU_result  [%h]", ALU_result);
        $display ("----------------------------------------------------------------------");
    end
end

endmodule
