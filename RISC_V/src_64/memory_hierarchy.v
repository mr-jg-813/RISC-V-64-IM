// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
module memory_hierarchy #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 64,
  parameter INSTRUCTION_WIDTH = 32,
  parameter INDEX_BITS = 6,
  parameter OFFSET_BITS = 3,
  parameter ADDRESS_BITS = 64,
  parameter INST_MEM_ADDR_BITS = 14,
  parameter DATA_MEM_ADDR_BITS = 14,
  parameter PROGRAM = "../software/applications/binaries/<your_program>"
) (

  input clock,
  input reset,

  // Instruction Memory Interface
  input i_mem_read,
  input [ADDRESS_BITS-1:0] i_mem_read_address,
  output [ADDRESS_BITS-1:0] i_mem_out_addr,
  output [INSTRUCTION_WIDTH-1:0] i_mem_out_data,
  output i_mem_valid,


  output [ADDRESS_BITS-1:0] d_mem_out_addr,
  output [DATA_WIDTH-1:0] d_mem_out_data,
  output d_mem_valid,
  output d_mem_ready,
  input [ADDRESS_BITS-1:0] d_mem_address,
  input [DATA_WIDTH-1:0] d_mem_in_data,
  input d_mem_read,
  input d_mem_write,
  input semihost_read,
  input [ADDRESS_BITS-1:0] semihost_address,
  output [DATA_WIDTH-1:0] semihost_data,

  input report,

  input [2:0]funct3                                                                                 //ADDED
);

// Route instruction requests to word-addressed instruction RAM.
i_mem_interface #(
  .CORE(CORE),
  .DATA_WIDTH(INSTRUCTION_WIDTH),
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MEM_ADDR_BITS(INST_MEM_ADDR_BITS),
  .PROGRAM(PROGRAM)
) i_mem_interface0 (
  .clock(clock),
  .reset(reset),
  .read(i_mem_read),
  .read_address(i_mem_read_address),
  .out_addr(i_mem_out_addr),
  .out_data(i_mem_out_data),
  .valid(i_mem_valid),
  .report(report)
);


// Route data requests to byte-addressed data RAM.
d_mem_interface #(
    .CORE(CORE),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDRESS_BITS(ADDRESS_BITS),
    .MEM_ADDR_BITS(DATA_MEM_ADDR_BITS)
) d_mem_interface0 (
    .clock(clock),
    .reset(reset),
    .read(d_mem_read),
    .write(d_mem_write),
    .address(d_mem_address),
    .in_data(d_mem_in_data),
    .semihost_read(semihost_read),
    .semihost_address(semihost_address),
    .semihost_data(semihost_data),
    .out_addr(d_mem_out_addr),
    .out_data(d_mem_out_data),
    .valid(d_mem_valid),
    .ready(d_mem_ready),
    .report(report),
    .funct3_dm(funct3)                                                                          //ADDED
);

endmodule
