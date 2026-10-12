// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
module i_mem_interface #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter INDEX_BITS = 6,
  parameter OFFSET_BITS = 3,
  parameter ADDRESS_BITS = 64,
  parameter MEM_ADDR_BITS = 14,
  parameter PROGRAM = "../software/applications/binaries/<your_program>"
) (
  input clock,
  input reset,

  input read,
  input [ADDRESS_BITS-1:0] read_address,

  output valid,
  output [ADDRESS_BITS-1:0] out_addr,
  output [DATA_WIDTH-1:0] out_data,

  input  report

);

// Keep the full PC-derived address for the pipeline; RAM uses its low index bits.
reg [ADDRESS_BITS-1:0] read_address_reg;

// Instruction memory is word-addressed and read-only here.
BSRAM #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(MEM_ADDR_BITS),
  .INIT_FILE(PROGRAM)
) RAM (
  .clock(clock),
  // Read
  .readEnable(1'b1), // Read signal checked at addr reg
  .readAddress(read_address_reg[MEM_ADDR_BITS-1:0]),
  .readData(out_data)
);

assign out_addr = read_address_reg;

assign valid = read;

// This logic stalls read address when readEnable is low. This is opposed to
// the old version which did not stall read address and set readData to 0.
// Stalling read address (and therefore readData) allows the pipeline to
// stall the whole BRAM memory stage.
always@(posedge clock) begin
  if(reset) begin
    read_address_reg <= {ADDRESS_BITS{1'b0}};
  end else begin
    read_address_reg <= read ? read_address : read_address_reg;
  end
end

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (report)begin
    $display ("------ Core %d Memory Interface - Current Cycle %d --", CORE, cycles);
    $display ("| Rd Address  [%h]", read_address);
    $display ("| Read        [%b]", read);
    $display ("| Out Data    [%h]", out_data);
    $display ("| Valid       [%b]", valid);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule

