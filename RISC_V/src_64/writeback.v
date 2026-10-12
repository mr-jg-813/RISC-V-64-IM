// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
module writeback_unit #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 64,
  parameter PRINT_CYCLES_MIN = 1,
  parameter PRINT_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input stall,
  input opWrite,
  input opSel,
  input [4:0] opReg,
  input [DATA_WIDTH-1:0] ALU_Result,
  input [DATA_WIDTH-1:0] memory_data,

  output write,
  output [4:0] write_reg,
  output [DATA_WIDTH-1:0] write_data,

  input report

);

// Choose the load value or ALU result for register writeback.
assign write_data = opSel ? memory_data : ALU_Result;
assign write_reg  = opReg;
assign write      = opWrite;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
  if (report)begin
    $display ("------ Core %d Writeback Unit - Current Cycle %d ----", CORE, cycles);
    $display ("| opSel       [%b]", opSel);
    $display ("| opReg       [%b]", opReg);
    $display ("| ALU_Result  [%d]", ALU_Result);
    $display ("| Memory_data [%d]", memory_data);
    $display ("| write       [%b]", write);
    $display ("| write_reg   [%d]", write_reg);
    $display ("| write_data  [%d]", write_data);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule

