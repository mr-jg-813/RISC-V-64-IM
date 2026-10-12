// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
/*********************************************************************************
*                              stallControl.v                                    *
*********************************************************************************/


module stall_and_bypass_control_unit (
  input clock,
  input [4:0] rs1,
  input [4:0] rs2,
  input regwrite_execute,
  input regwrite_memory1,
  input regwrite_memory2,
  input regwrite_writeback,
  input [4:0] rd_execute,
  input [4:0] rd_memory1,
  input [4:0] rd_memory2,
  input [4:0] rd_writeback,
  input [6:0] opcode_execute,
  input [6:0] opcode_memory1,
  input ecall_decode,

  output [2:0] rs1_data_bypass,
  output [2:0] rs2_data_bypass,
  output stall
);


wire rs1_stall_detected;
wire rs2_stall_detected;
wire stall_detected;

wire rs1_hazard_execute;
wire rs1_hazard_memory1;
wire rs1_hazard_memory2;
wire rs1_hazard_writeback;
wire rs1_load_hazard_execute;
wire rs1_load_hazard_memory1;
wire rs1_load_hazard;

wire rs2_hazard_execute;
wire rs2_hazard_memory1;
wire rs2_hazard_memory2;
wire rs2_hazard_writeback;
wire rs2_load_hazard_execute;
wire rs2_load_hazard_memory1;
wire rs2_load_hazard;
wire ecall_load_hazard;

wire load_opcode_in_execute;
wire load_opcode_in_memory1;

localparam [6:0] LOAD = 7'b0000011;

// Compare decode sources with destinations in later stages.
assign load_opcode_in_execute = opcode_execute == LOAD;
assign load_opcode_in_memory1 = opcode_memory1 == LOAD;

assign rs1_hazard_execute = (rs1 != 5'd0) && (rs1 == rd_execute) && regwrite_execute;
assign rs1_hazard_memory1 = (rs1 != 5'd0) && (rs1 == rd_memory1) && regwrite_memory1;
assign rs1_hazard_memory2 = (rs1 != 5'd0) && (rs1 == rd_memory2) && regwrite_memory2;
assign rs1_hazard_writeback = (rs1 != 5'd0) && (rs1 == rd_writeback) && regwrite_writeback;

assign rs2_hazard_execute = (rs2 != 5'd0) && (rs2 == rd_execute) && regwrite_execute;
assign rs2_hazard_memory1 = (rs2 != 5'd0) && (rs2 == rd_memory1) && regwrite_memory1;
assign rs2_hazard_memory2 = (rs2 != 5'd0) && (rs2 == rd_memory2) && regwrite_memory2;
assign rs2_hazard_writeback = (rs2 != 5'd0) && (rs2 == rd_writeback) && regwrite_writeback;

// TODO: Add read enable to detect true reads. Not every instruction reads
// both registers.
assign rs1_load_hazard_execute = rs1_hazard_execute & load_opcode_in_execute;
assign rs1_load_hazard_memory1 = rs1_hazard_memory1 & load_opcode_in_memory1;
assign rs1_load_hazard         = rs1_load_hazard_execute | rs1_load_hazard_memory1 ;
assign rs1_stall_detected      = rs1_load_hazard & (rs1 != 5'd0);

assign rs2_load_hazard_execute = rs2_hazard_execute & load_opcode_in_execute;
assign rs2_load_hazard_memory1 = rs2_hazard_memory1 & load_opcode_in_memory1;
assign rs2_load_hazard         = rs2_load_hazard_execute | rs2_load_hazard_memory1 ;
assign rs2_stall_detected      = rs2_load_hazard & (rs2 != 5'd0);

// ECALL reads a0-a7 implicitly, so stall while any of these arguments is
// being produced by a load whose data is not yet available for forwarding.
assign ecall_load_hazard = ecall_decode & (
    (regwrite_execute & load_opcode_in_execute &
     (rd_execute >= 5'd10) & (rd_execute <= 5'd17)) |
    (regwrite_memory1 & load_opcode_in_memory1 &
     (rd_memory1 >= 5'd10) & (rd_memory1 <= 5'd17))
);

//stall on a loadword and rd overlap
assign stall_detected = rs1_stall_detected | rs2_stall_detected |
                        ecall_load_hazard;

// The "Bonus" stall cycle has been removed.
assign stall = stall_detected;

// Select the youngest matching value for each decode source.
assign rs1_data_bypass = rs1_hazard_execute   ? 3'b001 :
                         rs1_hazard_memory1   ? 3'b010 :
                         rs1_hazard_memory2   ? 3'b011 :
                         rs1_hazard_writeback ? 3'b100 :
                         3'b000;

assign rs2_data_bypass = rs2_hazard_execute   ? 3'b001 :
                         rs2_hazard_memory1   ? 3'b010 :
                         rs2_hazard_memory2   ? 3'b011 :
                         rs2_hazard_writeback ? 3'b100 :
                         3'b000;
endmodule
