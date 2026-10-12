// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
/** Byte-addressable data-memory interface for the RV64 datapath. */
module d_mem_interface #(
    parameter CORE = 0,
    parameter DATA_WIDTH = 64,
    parameter ADDRESS_BITS = 64,
    parameter MEM_ADDR_BITS = 14
)(
    input clock,
    input reset,
    input read,
    input write,
    input [ADDRESS_BITS-1:0] address,
    input [DATA_WIDTH-1:0] in_data,
    input semihost_read,
    input [ADDRESS_BITS-1:0] semihost_address,
    output [DATA_WIDTH-1:0] semihost_data,
    output [DATA_WIDTH-1:0] out_data,
    input [2:0] funct3_dm,
    output reg [ADDRESS_BITS-1:0] out_addr,
    output reg valid,
    output reg ready,
    input report
);

localparam LANES = DATA_WIDTH / 8;
localparam BYTE = 3'b000;
localparam HALF = 3'b001;
localparam WORD = 3'b010;
localparam DOUBLE = 3'b011;
localparam WORD_UNSIGNED = 3'b110;

reg [LANES-1:0] byteEnable;
reg [DATA_WIDTH-1:0] store_data_aligned;
wire [DATA_WIDTH-1:0] bram_read_data;
wire [DATA_WIDTH-1:0] semihost_bram_data;
reg [DATA_WIDTH-1:0] shifted_read_data;
reg [DATA_WIDTH-1:0] load_data;
reg [2:0] load_funct3;
reg [$clog2(LANES)-1:0] load_offset;

wire [ADDRESS_BITS-1:0] aligned_address = {address[ADDRESS_BITS-1:$clog2(LANES)], {$clog2(LANES){1'b0}}};

BRAM #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(MEM_ADDR_BITS),
    .INIT_FILE("data/zeros2048.dat")
) RAM (
    .clock(clock),
    .readEnable(read),
    .readAddress(aligned_address[MEM_ADDR_BITS-1:0]),
    .readData(bram_read_data),
    .readEnableB(semihost_read),
    .readAddressB({semihost_address[MEM_ADDR_BITS-1:$clog2(LANES)], {$clog2(LANES){1'b0}}}),
    .readDataB(semihost_bram_data),
    .writeEnable(write),
    .writeAddress(aligned_address[MEM_ADDR_BITS-1:0]),
    .writeData(store_data_aligned),
    .byteEnable(byteEnable)
);

assign semihost_data = semihost_bram_data >> (semihost_address[$clog2(LANES)-1:0] * 8);

// Set byte lanes and align store data for the selected store size.
always @* begin
    byteEnable = {LANES{1'b0}};
    store_data_aligned = in_data << (address[$clog2(LANES)-1:0] * 8);
    if (write) begin
        case (funct3_dm)
            3'b000: byteEnable = {{(LANES-1){1'b0}},1'b1} << address[$clog2(LANES)-1:0]; // SB
            3'b001: if (address[0] == 1'b0) byteEnable = {{(LANES-2){1'b0}},2'b11} << address[$clog2(LANES)-1:0]; // SH
            3'b010: if (address[1:0] == 2'b00) byteEnable = {{(LANES-4){1'b0}},4'b1111} << address[$clog2(LANES)-1:0]; // SW
            DOUBLE: if ((DATA_WIDTH >= 64) && (address[$clog2(LANES)-1:0] == 0))
                        byteEnable = {LANES{1'b1}}; // SD
            default: byteEnable = {LANES{1'b0}};
        endcase
    end
end

always @(posedge clock) begin
    if (reset) begin
        load_funct3 <= WORD;
        load_offset <= 0;
    end else if (read) begin
        load_funct3 <= funct3_dm;
        load_offset <= address[$clog2(LANES)-1:0];
    end
end

always @* begin
    shifted_read_data = bram_read_data >> (load_offset * 8);
    load_data = {DATA_WIDTH{1'b0}};
    case (load_funct3)
        3'b000: load_data = {{(DATA_WIDTH-8){shifted_read_data[7]}}, shifted_read_data[7:0]}; // LB
        3'b100: load_data = {{(DATA_WIDTH-8){1'b0}}, shifted_read_data[7:0]}; // LBU
        3'b001: if (load_offset[0] == 1'b0) load_data = {{(DATA_WIDTH-16){shifted_read_data[15]}}, shifted_read_data[15:0]}; // LH
        3'b101: if (load_offset[0] == 1'b0) load_data = {{(DATA_WIDTH-16){1'b0}}, shifted_read_data[15:0]}; // LHU
        3'b010: if (load_offset[1:0] == 2'b00) load_data = {{(DATA_WIDTH-32){shifted_read_data[31]}}, shifted_read_data[31:0]}; // LW
        WORD_UNSIGNED: if ((DATA_WIDTH >= 32) && (load_offset[1:0] == 0))
                            load_data = {{(DATA_WIDTH-32){1'b0}}, shifted_read_data[31:0]}; // LWU
        DOUBLE: if ((DATA_WIDTH >= 64) && (load_offset == 0))
                    load_data = bram_read_data; // LD
        default: load_data = {DATA_WIDTH{1'b0}};
    endcase
end

assign out_data = load_data;

always @(posedge clock) begin
    if (reset) begin
        out_addr <= {ADDRESS_BITS{1'b0}};
        valid <= 1'b0;
        ready <= 1'b0;
    end else begin
        out_addr <= address;
        valid <= read | write;
        ready <= 1'b1;
    end
end

endmodule
