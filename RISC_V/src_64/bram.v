// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
/** @module : BRAM
 *  Byte-addressable data memory implemented as packed, synchronous words.
 */

(* ram_style = "block" *)
module BRAM #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 14,
    parameter INIT_FILE = "data/zeros2048.dat"
)(
    input clock,

    // Byte-addressed synchronous CPU port.
    input readEnable,
    input [ADDR_WIDTH-1:0] readAddress,
    output reg [DATA_WIDTH-1:0] readData,

    // Independent synchronous read port for semihosted character output.
    input readEnableB,
    input [ADDR_WIDTH-1:0] readAddressB,
    output reg [DATA_WIDTH-1:0] readDataB,

    // Byte-addressed write port with per-byte enables.
    input writeEnable,
    input [ADDR_WIDTH-1:0] writeAddress,
    input [DATA_WIDTH-1:0] writeData,
    input [DATA_WIDTH/8-1:0] byteEnable
);

localparam LANES = DATA_WIDTH / 8;
localparam BYTE_ADDR_BITS = $clog2(LANES);
localparam MEM_DEPTH = 1 << (ADDR_WIDTH - BYTE_ADDR_BITS);

// Each entry is one aligned DATA_WIDTH-bit little-endian word. The external
// addresses remain byte addresses; their low lane bits select the byte lane.
(* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram [0:MEM_DEPTH-1];
integer init_index;
integer write_lane;

// Two synchronous read ports and one byte-enable write port infer a dual-port
// block RAM. Do not turn these into combinational reads or variable byte muxes.
always @(posedge clock) begin
    if (readEnable)
        readData <= ram[readAddress[ADDR_WIDTH-1:BYTE_ADDR_BITS]];

    if (writeEnable) begin
        for (write_lane = 0; write_lane < LANES; write_lane = write_lane + 1)
            if (byteEnable[write_lane])
                ram[writeAddress[ADDR_WIDTH-1:BYTE_ADDR_BITS]][write_lane*8 +: 8]
                    <= writeData[write_lane*8 +: 8];
    end
end

always @(posedge clock) begin
    if (readEnableB)
        readDataB <= ram[readAddressB[ADDR_WIDTH-1:BYTE_ADDR_BITS]];
end

initial begin
    for (init_index = 0; init_index < MEM_DEPTH; init_index = init_index + 1)
        ram[init_index] = {DATA_WIDTH{1'b0}};
    $readmemh(INIT_FILE, ram);
end

endmodule
