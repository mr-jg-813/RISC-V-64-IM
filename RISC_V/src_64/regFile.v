// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
// Parameterized register file
module regFile #(
  parameter REG_DATA_WIDTH = 64,
  parameter REG_SEL_BITS   = 5,
  parameter INIT_FILE      = "data/zeros32.dat"
) (
  input clock,
  input reset,
  input wEn,

  input [REG_DATA_WIDTH-1:0] write_data,

  input [REG_SEL_BITS-1:0] read_sel1,
  input [REG_SEL_BITS-1:0] read_sel2,
  input [REG_SEL_BITS-1:0] write_sel,

  output [REG_DATA_WIDTH-1:0] read_data1,
  output [REG_DATA_WIDTH-1:0] read_data2,
  output [REG_DATA_WIDTH-1:0] read_a0,
  output [REG_DATA_WIDTH-1:0] read_a1,
  output [REG_DATA_WIDTH-1:0] read_a2,
  output [REG_DATA_WIDTH-1:0] read_a3,
  output [REG_DATA_WIDTH-1:0] read_a4,
  output [REG_DATA_WIDTH-1:0] read_a5,
  output [REG_DATA_WIDTH-1:0] read_a6,
  output [REG_DATA_WIDTH-1:0] read_a7
);

(* ram_style = "distributed" *)
reg [REG_DATA_WIDTH-1:0] register_file[0:(1<<REG_SEL_BITS)-1];

// Initialize registers
initial begin
  $readmemh(INIT_FILE, register_file);
end

// Write one register; x0 is always kept at zero.
always @(posedge clock) begin
  if (reset)
    register_file[0] <= 0;
  else if (wEn && (write_sel != 0))
    register_file[write_sel] <= write_data;
end

// Read operands and the eight ABI argument registers.
assign read_data1 = register_file[read_sel1];
assign read_data2 = register_file[read_sel2];
assign read_a0 = register_file[10];
assign read_a1 = register_file[11];
assign read_a2 = register_file[12];
assign read_a3 = register_file[13];
assign read_a4 = register_file[14];
assign read_a5 = register_file[15];
assign read_a6 = register_file[16];
assign read_a7 = register_file[17];

// Debug signals
wire [REG_DATA_WIDTH-1:0] r1;
assign r1 = register_file[1];

wire [REG_DATA_WIDTH-1:0] r14;
assign r14 = register_file[14];

wire [REG_DATA_WIDTH-1:0] r15;
assign r15 = register_file[15];

endmodule
