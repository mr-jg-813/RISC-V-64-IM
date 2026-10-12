// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
//Same cycle read memory access

 (* ram_style = "block" *)
module BSRAM #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 14,
  parameter INIT_FILE = "../software/applications/binaries/zeros4096.dat"
) (
  input clock,
  input readEnable,
  input [ADDR_WIDTH-1:0]   readAddress,
  output [DATA_WIDTH-1:0]  readData
);

localparam MEM_DEPTH = 1 << ADDR_WIDTH;

reg [DATA_WIDTH-1:0] sram [0:MEM_DEPTH-1];

assign readData = readEnable ? sram[readAddress] : 0;

initial begin
    $readmemh(INIT_FILE, sram);
end

endmodule

