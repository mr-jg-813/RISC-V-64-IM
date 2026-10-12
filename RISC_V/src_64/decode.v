// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
// TODO: Remove all '=' from wire declarations.
// Decode 32-bit instructions into XLEN-wide operands.
module decode_unit #(
  parameter CORE = 0,
  parameter ADDRESS_BITS = 64,
  parameter DATA_WIDTH = 64,
  parameter PRINT_CYCLES_MIN = 1,
  parameter PRINT_CYCLES_MAX = 1000
) (

  input  clock,
  input  reset,
  input  [ADDRESS_BITS-1:0] PC,
input  [31:0] instruction,
  input  [1:0] extend_sel,
  input  write,
         // TODO: rename write_reg to write_sel to match read_sel signals. This
         // is more clear. -Alan
  input  [4:0]  write_reg,
  input  [DATA_WIDTH-1:0] write_data,
  input  [2:0] rs1_data_bypass,
  input  [2:0] rs2_data_bypass,
  input  [DATA_WIDTH-1:0] ALU_result_execute,
  input  [DATA_WIDTH-1:0] ALU_result_memory1,
  input  [DATA_WIDTH-1:0] ALU_result_memory2,
  input  [DATA_WIDTH-1:0] ALU_result_writeback,

  output [DATA_WIDTH-1:0] rs1_data,
  output [DATA_WIDTH-1:0] rs2_data,
  output [4:0]  rd,
  output [6:0]  opcode,
  output [6:0]  funct7,
  output [2:0]  funct3,
  output [DATA_WIDTH-1:0] extend_imm,
  output [ADDRESS_BITS-1:0] branch_target,
  output [ADDRESS_BITS-1:0] JAL_target,
  output [4:0] rs1,
  output [4:0] rs2,
  output [11:0] imm_c,
  output ebreak,
  output ecall,
  output [8*DATA_WIDTH-1:0] ecall_reg_values,

  input report

); 
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
                
 
// Instruction fields and immediate values.
wire[DATA_WIDTH-1:0] rs1_data_decode;
wire[DATA_WIDTH-1:0] rs2_data_decode;
wire[11:0] i_imm      = instruction[31:20];
wire[6:0]  s_imm_msb  = instruction[31:25];
wire[4:0]  s_imm_lsb  = instruction[11:7];
wire[19:0] u_imm      = instruction[31:12];
wire[11:0] i_imm_orig = instruction[31:20]; 
wire[19:0] j_imm     = {instruction[31],instruction[19:12],instruction[20],instruction[30:21]};

//Forming the s immediate value from the two msb and lsb parts of the s immediate
wire[11:0] s_imm_orig  = {s_imm_msb,s_imm_lsb};
wire[12:0] sb_imm_orig = {s_imm_msb[6],s_imm_lsb[0],s_imm_msb[5:0],s_imm_lsb[4:1],1'b0};

// Read registers
assign  rs2           = instruction[24:20];
assign  rs1           = instruction[19:15];

/* Instruction decoding */
assign opcode        = instruction[6:0];
assign funct7        = instruction[31:25];
assign funct3        = instruction[14:12];

/* Write register */
assign  rd           = instruction[11:7];

/* Only workig with BEQ at the moment */
wire[DATA_WIDTH-1:0] sb_imm_xlen = {{(DATA_WIDTH-13){sb_imm_orig[12]}}, sb_imm_orig};
assign branch_target = PC + sb_imm_xlen;

/* Extensions */
wire[DATA_WIDTH-1:0] u_imm_xlen = {{(DATA_WIDTH-32){u_imm[19]}}, u_imm, 12'b0};
wire[DATA_WIDTH-1:0] i_imm_xlen = {{(DATA_WIDTH-12){i_imm_orig[11]}}, i_imm_orig};
wire[DATA_WIDTH-1:0] s_imm_xlen = {{(DATA_WIDTH-12){s_imm_orig[11]}}, s_imm_orig};

assign extend_imm    = (extend_sel == 2'b01)? s_imm_xlen :
                       (extend_sel == 2'b10)? u_imm_xlen : i_imm_xlen;

/* Only JAL Target. JALR happens in the execution unit*/
wire[DATA_WIDTH-1:0] j_imm_xlen = {{(DATA_WIDTH-21){j_imm[19]}},j_imm[19:0],1'b0};
assign JAL_target    = j_imm_xlen + PC;

// Select the newest forwarded value for each source register.
assign rs1_data      = (rs1_data_bypass == 3'b000)? rs1_data_decode      :
                       (rs1_data_bypass == 3'b001)? ALU_result_execute   :
                       (rs1_data_bypass == 3'b010)? ALU_result_memory1   :
                       (rs1_data_bypass == 3'b011)? ALU_result_memory2   :
                       (rs1_data_bypass == 3'b100)? ALU_result_writeback :
                       {DATA_WIDTH{1'b0}};
                       
assign rs2_data      = (rs2_data_bypass == 3'b000)? rs2_data_decode      :
                       (rs2_data_bypass == 3'b001)? ALU_result_execute   :
                       (rs2_data_bypass == 3'b010)? ALU_result_memory1   :
                       (rs2_data_bypass == 3'b011)? ALU_result_memory2   :
                       (rs2_data_bypass == 3'b100)? ALU_result_writeback :
                       {DATA_WIDTH{1'b0}};
                       
// Recognize ECALL and EBREAK system instructions.
assign imm_c = i_imm;
assign ebreak = (opcode == SYSCALL) & (funct3 == 3'b000) & (i_imm == 12'h001);
assign ecall = (opcode == SYSCALL) & (funct3 == 3'b000) & (i_imm == 12'h000);



// Report whether this decoder recognizes the current instruction encoding.
wire opcode_recognized = (opcode == R_TYPE) | (opcode == I_TYPE) |
                         (opcode == STORE) | (opcode == LOAD) |
                         (opcode == BRANCH) | (opcode == JALR) |
                         (opcode == JAL) | (opcode == AUIPC) |
                         (opcode == LUI) | (opcode == R_TYPE64) |
                         (opcode == I_TYPE64);
wire instruction_decoded = opcode_recognized |
                           (opcode == SYSCALL && funct3 == 3'b000 &&
                            (i_imm == 12'h000 || i_imm == 12'h001));

regFile #(DATA_WIDTH, 5) registers (
                .clock(clock),
                .reset(reset),
                .read_sel1(rs1),
                .read_sel2(rs2),
                .wEn(write),
                .write_sel(write_reg),
                .write_data(write_data),
                .read_data1(rs1_data_decode),
                .read_data2(rs2_data_decode),
                .read_a0(ecall_reg_values[0*DATA_WIDTH +: DATA_WIDTH]),
                .read_a1(ecall_reg_values[1*DATA_WIDTH +: DATA_WIDTH]),
                .read_a2(ecall_reg_values[2*DATA_WIDTH +: DATA_WIDTH]),
                .read_a3(ecall_reg_values[3*DATA_WIDTH +: DATA_WIDTH]),
                .read_a4(ecall_reg_values[4*DATA_WIDTH +: DATA_WIDTH]),
                .read_a5(ecall_reg_values[5*DATA_WIDTH +: DATA_WIDTH]),
                .read_a6(ecall_reg_values[6*DATA_WIDTH +: DATA_WIDTH]),
                .read_a7(ecall_reg_values[7*DATA_WIDTH +: DATA_WIDTH])
);

reg [31: 0] cycles;
always @ (posedge clock) begin
    cycles <= reset? 0 : cycles + 1;
    if (!reset)
        $display("PC_ADDR=%016h INSN=%08h DECODED=%s",
                 PC, instruction, instruction_decoded ? "YES" : "NO");
end

endmodule
