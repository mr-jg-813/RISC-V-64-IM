// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
/*********************************************************************************
*                              control_unit.v                                    *
*********************************************************************************/


module control_unit #(
  parameter CORE = 0,
  PRINT_CYCLES_MIN = 1,
  PRINT_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input [6:0] opcode,
  input [11:0] imm, 
  input [2:0] funct3,
  input [6:0] funct7,
  input branch,
  input ebreak,

  output branch_op,
  output memRead,
  output memtoReg,
  output [3:0] ALUOp,
  output memWrite,
  output [1:0] next_PC_sel,
  output [1:0] operand_A_sel,
  output operand_B_sel,
  output [1:0] extend_sel,
  output regWrite,
  output flush,
  output stop,

  input  report

);
reg r2;
localparam [6:0]R_TYPE   = 7'b0110011, // 64
                I_TYPE   = 7'b0010011, // 64
                STORE    = 7'b0100011, // ]
                LOAD     = 7'b0000011, // ]
                BRANCH   = 7'b1100011, // ]
                JALR     = 7'b1100111, // ] 
                JAL      = 7'b1101111, // ]both
                AUIPC    = 7'b0010111, // ]
                LUI      = 7'b0110111, // ]
                FENCES   = 7'b0001111, // ]
                SYSCALL  = 7'b1110011, // ]
                R_TYPE64 = 7'b0111011, // 32
                I_TYPE64 = 7'b0011011, // 32
                M_ex     = 7'b0110011, // mult extension
                M_ex_64  = 7'b0111011; // mult extension 64bit 
 
                
                
// Decode the instruction's main control signals.
assign regWrite      = (opcode == R_TYPE) | (opcode == I_TYPE)   | (opcode == LOAD)    |
                       (opcode == JALR)   | (opcode == JAL)      | (opcode == AUIPC)   |
                       (opcode == LUI)    | (opcode == R_TYPE64) | (opcode == I_TYPE64)| 
                       (opcode == M_ex)   | (opcode == M_ex_64) ;
                        
                       
assign memWrite      = (opcode == STORE);
assign branch_op     = (opcode == BRANCH);
assign memRead       = (opcode == LOAD);
assign memtoReg      = (opcode == LOAD);

assign ALUOp         = (opcode == M_ex && funct7 == 7'b0000001) ? 4'b1001 :
                       (opcode == M_ex_64 && funct7 == 7'b0000001) ? 4'b1010 :
                       (opcode == R_TYPE)   ? 4'b0000 :
                       (opcode == I_TYPE)   ? 4'b0001 :
                       (opcode == STORE)    ? 4'b0101 :
                       (opcode == LOAD)     ? 4'b0100 :
                       (opcode == BRANCH)   ? 4'b0010 :
                       ((opcode == JALR)    | (opcode == JAL))? 4'b0011 :
                       ((opcode == AUIPC)   | (opcode == LUI))? 4'b0110 : 
                       (opcode == R_TYPE64) ? 4'b0111 : 
                       (opcode == I_TYPE64) ? 4'b1000 :
                       4'b0000;

assign operand_A_sel = (opcode == AUIPC) ?  2'b01 :
                       (opcode == LUI)   ?  2'b11 :
                       (opcode == JALR)  | (opcode == JAL) ?  2'b10 : 2'b00;

assign operand_B_sel = (opcode == I_TYPE) | (opcode == STORE)   |
                       (opcode == LOAD)   | (opcode == AUIPC)   |
                       (opcode == LUI)    | (opcode == I_TYPE64);

assign extend_sel    = (opcode == I_TYPE) | (opcode == LOAD) | (opcode == I_TYPE64) ? 2'b00 :
                       (opcode == STORE)                                            ? 2'b01 :
                       (opcode == AUIPC) | (opcode == LUI)                          ? 2'b10 :
                       2'b00;

assign next_PC_sel   = (opcode == BRANCH) ? 2'b01 :
                       (opcode == JAL)    ? 2'b10 :
                       (opcode == JALR)   ? 2'b11 :
                       2'b00;
                       
// flushing 
always@ (posedge clock)  begin
r2 <= reset;
end

assign flush = reset? 0 : r2 ? 0 : (ebreak | branch);
reg [2:0] stop_counter;
// stop counter to stop after some cycles
always @(posedge clock) begin
    if (reset)
        stop_counter <= 0;
    else if (ebreak)
        stop_counter <= 1;
    else if (stop_counter != 0 && stop_counter < 4)
        stop_counter <= stop_counter + 1;
end

assign stop = (stop_counter == 4);

reg [31: 0] cycles;
always @ (posedge clock) begin
    cycles <= reset? 0 : cycles + 1;
    //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
    if (report)begin
        $display ("------ Core %d Control Unit - Current Cycle %d ------", CORE, cycles);
        $display ("| Opcode      [%b]", opcode);
        $display ("| Branch_op   [%b]", branch_op);
        $display ("| memRead     [%b]", memRead);
        $display ("| memtoReg    [%b]", memtoReg);
        $display ("| memWrite    [%b]", memWrite);
        $display ("| RegWrite    [%b]", regWrite);
        $display ("| ALUOp       [%b]", ALUOp);
        $display ("| Extend_sel  [%b]", extend_sel);
        $display ("| ALUSrc_A    [%b]", operand_A_sel);
        $display ("| ALUSrc_B    [%b]", operand_B_sel);
        $display ("| Next PC     [%b]", next_PC_sel);
        $display ("----------------------------------------------------------------------");
    end
end
endmodule
