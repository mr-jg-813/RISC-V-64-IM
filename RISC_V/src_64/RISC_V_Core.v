// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
module RISC_V_Core #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 64,
  parameter INDEX_BITS = 6,
  parameter OFFSET_BITS = 3,
  parameter ADDRESS_BITS = 64,
  parameter INST_MEM_ADDR_BITS = 14,
  parameter DATA_MEM_ADDR_BITS = 14,
  parameter PRINT_CYCLES_MIN = 0,
  parameter PRINT_CYCLES_MAX = 15,
  parameter PROGRAM = "main_bsram.mem"
) (
  input clock,

  input reset,
  input start,
  input [ADDRESS_BITS-1:0] prog_address,

  output stop,
  input report // performance reporting
);

// TODO: Break up wire declarations by module/stage
wire [ADDRESS_BITS-1:0] current_PC;
wire [31:0]  instruction_fetch1; // output of i_mem_interface
wire [31:0]  instruction_fetch2; // output of fetch unit
wire [31:0]  instruction_decode;
// For Debug
wire [31:0]  instruction_execute;
wire [31:0]  instruction_memory1;
wire [31:0]  instruction_writeback;

wire [ADDRESS_BITS-1: 0] inst_PC_fetch;
wire [ADDRESS_BITS-1: 0] inst_PC_decode;
wire valid_fetch2;
wire ready_fetch2;
wire valid_memory2;
wire ready_memory2;
wire [4:0] rs1_decode;
wire [4:0] rs2_decode;
wire stall;
wire [ADDRESS_BITS-1: 0] JAL_target_decode;
wire [ADDRESS_BITS-1: 0] JAL_target_execute;
wire [ADDRESS_BITS-1: 0] JALR_target_execute;
wire [ADDRESS_BITS-1: 0] branch_target_decode;
wire [ADDRESS_BITS-1: 0] branch_target_execute;

wire  write_writeback;
wire  [4:0]  write_reg_writeback;
wire  [DATA_WIDTH-1:0] write_data_writeback;

wire [DATA_WIDTH-1:0]  rs1_data_decode;
wire [DATA_WIDTH-1:0]  rs2_data_decode;
wire [4:0]  rd_decode;
wire [6:0]  opcode_decode;
wire [6:0]  funct7_decode;
wire [2:0]  funct3_decode;

wire [DATA_WIDTH-1:0]  rs1_data_execute;
wire [DATA_WIDTH-1:0]  rs2_data_execute;
wire [DATA_WIDTH-1:0]  rs2_data_memory1;
wire [4:0]   rd_execute;

wire [ADDRESS_BITS-1: 0] PC_execute;
wire [6:0]  opcode_execute;
wire [6:0]  opcode_memory1;
wire [6:0]  funct7_execute;
wire [2:0]  funct3_execute;

wire memRead_decode;
wire memRead_execute;
wire memRead_memory1;
wire memRead_writeback;

wire [4:0]  rd_memory1;
wire [4:0]  rd_memory2;
wire [4:0]  rd_writeback;
wire memtoReg;
wire [3:0] ALUOp_decode;
wire [3:0] ALUOp_execute;
wire branch_op_decode;
wire branch_op_execute;
wire [1:0] next_PC_select_decode;
wire [1:0] next_PC_select_execute;
wire [1:0] next_PC_select_memory1;
wire [1:0] next_PC_select_memory2;
wire [1:0] next_PC_select_writeback; // TODO: MAke this memory2 when extra memory stage is added
wire [1:0] operand_A_sel_decode;
wire [1:0] operand_A_sel_execute;
wire operand_B_sel_decode;
wire operand_B_sel_execute;
wire [1:0] extend_sel_decode;
wire [DATA_WIDTH-1:0]  extend_imm_decode;
wire [DATA_WIDTH-1:0]  extend_imm_execute;

wire memWrite_decode;
wire memWrite_execute;
wire memWrite_memory1;
wire regWrite_decode;
wire regWrite_execute;
wire regWrite_memory1;
wire regWrite_memory2;
wire regWrite_writeback;

wire branch_execute;
wire [DATA_WIDTH-1:0]   ALU_result_execute;
wire [DATA_WIDTH-1:0]   ALU_result_memory1;
wire [DATA_WIDTH-1:0]   ALU_result_writeback;
wire [ADDRESS_BITS-1:0] generated_addr = ALU_result_memory1; // the case the address is not 32-bit

wire zero; // Have not done anything with this signal

wire [DATA_WIDTH-1:0]    memory_data_memory2;
wire [DATA_WIDTH-1:0]    memory_data_writeback;
wire [DATA_WIDTH-1:0]    bypass_data_memory2;
wire [ADDRESS_BITS-1: 0] memory_addr_memory2; // To use to check the address coming out the memory stage

wire [2:0] rs1_data_bypass;
wire [2:0] rs2_data_bypass;

// Memory Hierarchy Wires - Instruction Memory Interface
wire i_mem_read;
wire [ADDRESS_BITS-1:0] i_mem_read_address;
wire [ADDRESS_BITS-1:0] i_mem_out_addr;
wire [31:0] i_mem_out_data;
wire i_mem_valid;

// Memory Hierarchy Wires - Data Memory Interface
wire [ADDRESS_BITS-1:0] d_mem_out_addr;
wire [DATA_WIDTH-1:0] d_mem_out_data;
wire d_mem_valid;
wire d_mem_ready;
wire [ADDRESS_BITS-1:0] d_mem_address;
wire [DATA_WIDTH-1:0] d_mem_in_data;
wire d_mem_read;
wire d_mem_write;
wire [2:0]funct3;                                                               ///ADDED
wire [2:0]funct3_exec;                                                          ///ADDED
wire [2:0]funct3_e_m;                                                           ///ADDED
wire [11:0] imm_decode;
wire [11:0] imm_d_c;
wire flush_decode;
wire ebreak_decode;
wire ebreak_cont;
wire ecall_decode;
wire ecall_cont;
wire [8*DATA_WIDTH-1:0] ecall_reg_values;
wire [8*DATA_WIDTH-1:0] ecall_args_forwarded;
wire [8*DATA_WIDTH-1:0] ecall_args_execute;
wire semihost_request;
wire semihost_read;
wire [ADDRESS_BITS-1:0] semihost_address;
wire [DATA_WIDTH-1:0] semihost_data;
wire [7:0] semihost_char_data;
wire semihost_char_valid;
wire ebreak_halt;

// Picolibc's SYS_WRITEC semihost call uses a0=3 and a1=pointer.
assign semihost_request = ebreak_cont &&
                          (ecall_args_execute[0*DATA_WIDTH +: DATA_WIDTH] == 3);
assign ebreak_halt = ebreak_cont && !semihost_request;

// ECALL is reserved as an empty placeholder for future services.
ecall_module #(
  .DATA_WIDTH(DATA_WIDTH)
) ECALL (
  .ecall_valid(ecall_cont),
  .ecall_args(ecall_args_execute)
);

semihost_putchar #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .MEM_ADDR_BITS(DATA_MEM_ADDR_BITS)
) SEMIHOST_PUTCHAR (
  .clock(clock),
  .reset(reset),
  .request(semihost_request),
  .address(ecall_args_execute[1*DATA_WIDTH +: DATA_WIDTH]),
  .read_enable(semihost_read),
  .read_address(semihost_address),
  .read_data(semihost_data),
  .char_data(semihost_char_data),
  .char_valid(semihost_char_valid)
);


// Assignments to make debugging easier
assign current_PC         = inst_PC_fetch;
assign instruction_fetch1 = i_mem_out_data;

// Shared instruction and data memories.
memory_hierarchy #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .INSTRUCTION_WIDTH(32),
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INST_MEM_ADDR_BITS(INST_MEM_ADDR_BITS),
  .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS),
  .PROGRAM(PROGRAM)
) mem_hierarchy_inst (
  .clock(clock),
  .reset(reset),
 
  // Instruction Memory Interface
  .i_mem_read(i_mem_read),
  .i_mem_read_address(i_mem_read_address),
  .i_mem_out_addr(i_mem_out_addr),
  .i_mem_out_data(i_mem_out_data),
  .i_mem_valid(i_mem_valid),

  // Data Memory Interface
  .d_mem_address(d_mem_address),
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),
  .semihost_read(semihost_read),
  .semihost_address(semihost_address),
  .semihost_data(semihost_data),
  .d_mem_in_data(d_mem_in_data),
  .d_mem_out_addr(d_mem_out_addr),
  .d_mem_out_data(d_mem_out_data),

  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),
  .funct3(funct3_e_m),

  .report(report)

);

// Fetch the next instruction and carry it into decode.
fetch_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .INSTRUCTION_WIDTH(32),
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .PROGRAM(PROGRAM),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) IF (
  .clock(clock),
  .reset(reset),
  .start(start),
  .stall(stall),
  .next_PC_select_execute(next_PC_select_execute),
  .program_address(prog_address),
  .JAL_target(JAL_target_execute),
  .JALR_target(JALR_target_execute),
  .branch(branch_execute),
  .branch_target(branch_target_execute),

  // Instruction Memory Interface
  .i_mem_read(i_mem_read),
  .i_mem_read_address(i_mem_read_address),
  .i_mem_out_addr(i_mem_out_addr),
  .i_mem_out_data(i_mem_out_data),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_read),
  .flush(flush_decode),

  .instruction(instruction_fetch2),
  .inst_PC(inst_PC_fetch),
  .valid(valid_fetch2), // Unused in 7 stage BRAM
  .ready(ready_fetch2), // Unused in 7 stage BRAM
  .report(report),

  .inst_PC_decode(inst_PC_decode)

);

fetch_pipe_unit #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) IF_ID (
  .clock(clock),
  .reset(reset),
  .stall(stall),
  .instruction_fetch(instruction_fetch2),
  .inst_PC_fetch(inst_PC_fetch),
  .flush(flush_decode),

  .instruction_decode(instruction_decode),
  .inst_PC_decode(inst_PC_decode)
 );

// Decode the instruction and read the register file.
decode_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) ID (
  .clock(clock),
  .reset(reset),
  .PC(inst_PC_decode),
  .instruction(instruction_decode),

  .extend_sel(extend_sel_decode),
  .write(write_writeback),
  .write_reg(write_reg_writeback),
  .write_data(write_data_writeback),
  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),
  .ALU_result_execute(ALU_result_execute),
  .ALU_result_memory1(ALU_result_memory1),
  .ALU_result_memory2(bypass_data_memory2),
  .ALU_result_writeback(write_data_writeback),

  .opcode(opcode_decode),
  .funct3(funct3_decode),
  .funct7(funct7_decode),
  .rs1_data(rs1_data_decode),
  .rs2_data(rs2_data_decode),
  .rd(rd_decode),
  .extend_imm(extend_imm_decode),
  .branch_target(branch_target_decode),
  .JAL_target(JAL_target_decode),
  .rs1(rs1_decode),
  .rs2(rs2_decode),
  .imm_c(imm_decode),
  .ebreak(ebreak_decode),
  .ecall(ecall_decode),
  .ecall_reg_values(ecall_reg_values),
  
  .report(report)
);

// Detect load hazards and select operand bypass paths.
stall_and_bypass_control_unit ID_SB (
  .clock(clock),
  .rs1(rs1_decode),
  .rs2(rs2_decode),
  .regwrite_execute(regWrite_execute),
  .regwrite_memory1(regWrite_memory1),
  .regwrite_memory2(regWrite_memory2),
  .regwrite_writeback(regWrite_writeback),
  .rd_execute(rd_execute),
  .rd_memory1(rd_memory1),
  .rd_memory2(rd_memory2),
  .rd_writeback(rd_writeback),
  .opcode_execute(opcode_execute),
  .opcode_memory1(opcode_memory1),
  .ecall_decode(ecall_decode),

  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),
  .stall(stall)
);

// ECALL reads a0-a7 implicitly, so select each argument's youngest pending
// value from the pipeline instead of relying on ECALL's unused rs fields.
 assign ecall_args_forwarded[0*DATA_WIDTH +: DATA_WIDTH] =
        (regWrite_execute && rd_execute == 5'd10) ? ALU_result_execute :
        (regWrite_memory1 && rd_memory1 == 5'd10) ? ALU_result_memory1 :
        (regWrite_memory2 && rd_memory2 == 5'd10) ? bypass_data_memory2 :
        (regWrite_writeback && rd_writeback == 5'd10) ? write_data_writeback :
        ecall_reg_values[0*DATA_WIDTH +: DATA_WIDTH];

assign ecall_args_forwarded[1*DATA_WIDTH +: DATA_WIDTH] =
        (regWrite_execute && rd_execute == 5'd11) ? ALU_result_execute :
        (regWrite_memory1 && rd_memory1 == 5'd11) ? ALU_result_memory1 :
        (regWrite_memory2 && rd_memory2 == 5'd11) ? bypass_data_memory2 :
        (regWrite_writeback && rd_writeback == 5'd11) ? write_data_writeback :
        ecall_reg_values[1*DATA_WIDTH +: DATA_WIDTH];

assign ecall_args_forwarded[2*DATA_WIDTH +: DATA_WIDTH] =
        (regWrite_execute && rd_execute == 5'd12) ? ALU_result_execute :
        (regWrite_memory1 && rd_memory1 == 5'd12) ? ALU_result_memory1 :
        (regWrite_memory2 && rd_memory2 == 5'd12) ? bypass_data_memory2 :
        (regWrite_writeback && rd_writeback == 5'd12) ? write_data_writeback :
        ecall_reg_values[2*DATA_WIDTH +: DATA_WIDTH];

assign ecall_args_forwarded[3*DATA_WIDTH +: DATA_WIDTH] =
        (regWrite_execute && rd_execute == 5'd13) ? ALU_result_execute :
        (regWrite_memory1 && rd_memory1 == 5'd13) ? ALU_result_memory1 :
        (regWrite_memory2 && rd_memory2 == 5'd13) ? bypass_data_memory2 :
        (regWrite_writeback && rd_writeback == 5'd13) ? write_data_writeback :
        ecall_reg_values[3*DATA_WIDTH +: DATA_WIDTH];

assign ecall_args_forwarded[4*DATA_WIDTH +: DATA_WIDTH] =
        (regWrite_execute && rd_execute == 5'd14) ? ALU_result_execute :
        (regWrite_memory1 && rd_memory1 == 5'd14) ? ALU_result_memory1 :
        (regWrite_memory2 && rd_memory2 == 5'd14) ? bypass_data_memory2 :
        (regWrite_writeback && rd_writeback == 5'd14) ? write_data_writeback :
        ecall_reg_values[4*DATA_WIDTH +: DATA_WIDTH];

assign ecall_args_forwarded[5*DATA_WIDTH +: DATA_WIDTH] =
        (regWrite_execute && rd_execute == 5'd15) ? ALU_result_execute :
        (regWrite_memory1 && rd_memory1 == 5'd15) ? ALU_result_memory1 :
        (regWrite_memory2 && rd_memory2 == 5'd15) ? bypass_data_memory2 :
        (regWrite_writeback && rd_writeback == 5'd15) ? write_data_writeback :
        ecall_reg_values[5*DATA_WIDTH +: DATA_WIDTH];

assign ecall_args_forwarded[6*DATA_WIDTH +: DATA_WIDTH] =
        (regWrite_execute && rd_execute == 5'd16) ? ALU_result_execute :
        (regWrite_memory1 && rd_memory1 == 5'd16) ? ALU_result_memory1 :
        (regWrite_memory2 && rd_memory2 == 5'd16) ? bypass_data_memory2 :
        (regWrite_writeback && rd_writeback == 5'd16) ? write_data_writeback :
        ecall_reg_values[6*DATA_WIDTH +: DATA_WIDTH];

assign ecall_args_forwarded[7*DATA_WIDTH +: DATA_WIDTH] =
        (regWrite_execute && rd_execute == 5'd17) ? ALU_result_execute :
        (regWrite_memory1 && rd_memory1 == 5'd17) ? ALU_result_memory1 :
        (regWrite_memory2 && rd_memory2 == 5'd17) ? bypass_data_memory2 :
        (regWrite_writeback && rd_writeback == 5'd17) ? write_data_writeback :
        ecall_reg_values[7*DATA_WIDTH +: DATA_WIDTH];

    // Repeat for a2–a7 (x12–x17).

// Keep ECALL in decode during a pending argument load, then snapshot once
// its arguments are available from the pipeline bypasses.
// Generate instruction controls and branch flush signals.
control_unit #(
  .CORE(CORE),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) CU (
  .clock(clock),
  .reset(reset),

  .opcode(opcode_decode),
  .funct3(funct3_decode),
  .funct7(funct7_decode),
  .imm(imm_decode),
  .branch(branch_execute),
  .ebreak(ebreak_halt),
  
  .branch_op(branch_op_decode),
  .memRead(memRead_decode),
  .memtoReg(memtoReg),
  .ALUOp(ALUOp_decode),
  .memWrite(memWrite_decode),
  .next_PC_sel(next_PC_select_decode),
  .operand_A_sel(operand_A_sel_decode),
  .operand_B_sel(operand_B_sel_decode),
  .extend_sel(extend_sel_decode),
  .regWrite(regWrite_decode),
  .flush(flush_decode),
  .stop(stop),

  .report(report)
);

// Register decoded controls before execute.
decode_pipe_unit #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) ID_EU (
  .clock(clock),
  .reset(reset),
  .stall(stall),
  .rs1_data_decode(rs1_data_decode),
  .rs2_data_decode(rs2_data_decode),
  .funct7_decode(funct7_decode),
  .funct3_decode(funct3_decode),
  .rd_decode(rd_decode),
  .opcode_decode(opcode_decode),
  .extend_imm_decode(extend_imm_decode),
  .branch_target_decode(branch_target_decode),
  .JAL_target_decode(JAL_target_decode),
  .PC_decode(inst_PC_decode),
  .branch_op_decode(branch_op_decode),
  .memRead_decode(memRead_decode),
  .ALUOp_decode(ALUOp_decode),
  .memWrite_decode(memWrite_decode),
  .next_PC_select_decode(next_PC_select_decode),
  .next_PC_select_memory1(next_PC_select_memory1),
  .next_PC_select_memory2(next_PC_select_memory2),
  .operand_A_sel_decode(operand_A_sel_decode),
  .operand_B_sel_decode(operand_B_sel_decode),
  .regWrite_decode(regWrite_decode),
  .imm_d(imm_decode),
  .flush(flush_decode),
  .ebreak_in(ebreak_decode),
  .ecall_in(ecall_decode),
  .ecall_args_in(ecall_args_forwarded),
  // For Debug
  .instruction_decode(instruction_decode),

  .rs1_data_execute(rs1_data_execute),
  .rs2_data_execute(rs2_data_execute),
  .funct7_execute(funct7_execute),
  .funct3_execute(funct3_execute),
  .rd_execute(rd_execute),
  .opcode_execute(opcode_execute),
  .extend_imm_execute(extend_imm_execute),
  .branch_target_execute(branch_target_execute),
  .JAL_target_execute(JAL_target_execute),
  .PC_execute(PC_execute),
  .branch_op_execute(branch_op_execute),
  .memRead_execute(memRead_execute),
  .ALUOp_execute(ALUOp_execute),
  .memWrite_execute(memWrite_execute),
  .next_PC_select_execute(next_PC_select_execute),
  .operand_A_sel_execute(operand_A_sel_execute),
  .operand_B_sel_execute(operand_B_sel_execute),
  .regWrite_execute(regWrite_execute),
  .imm_d_c(imm_d_c),
  .ebreak_out(ebreak_cont),
  .ecall_out(ecall_cont),
  .ecall_args_out(ecall_args_execute),
  // For Debug
  .instruction_execute(instruction_execute)
);



// Perform ALU operations, branch checks, and jump-target calculation.
execution_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) EU (
  .clock(clock),
  .reset(reset),
  .stall(stall),

  .ALU_Operation(ALUOp_execute),
  .funct3_in(funct3_execute),
  .funct7(funct7_execute),
  .branch_op(branch_op_execute),
  .PC(PC_execute),
  .ALU_ASrc(operand_A_sel_execute),
  .ALU_BSrc(operand_B_sel_execute),
  .regRead_1(rs1_data_execute),
  .regRead_2(rs2_data_execute),
  .extend(extend_imm_execute),
  .ALU_result(ALU_result_execute),
  .zero(zero),
  .branch(branch_execute),
  .JALR_target(JALR_target_execute),
  .funct3_out(funct3),                                                          //ADDED

  .report(report)
);

// Carry execute results into the memory stages.
execute_pipe_unit #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) EU_MU (
  .clock(clock),
  .reset(reset),
  //.stall(stall),
  .ALU_result_execute(ALU_result_execute),
  .store_data_execute(rs2_data_execute),
  .rd_execute(rd_execute),
  .opcode_execute(opcode_execute),
  .memWrite_execute(memWrite_execute),
  .memRead_execute(memRead_execute),
  .next_PC_select_execute(next_PC_select_execute),
  .regWrite_execute(regWrite_execute),
  // For Debug
  .instruction_execute(instruction_execute),

  .ALU_result_memory1(ALU_result_memory1),
  .store_data_memory1(rs2_data_memory1),
  .rd_memory1(rd_memory1),
  .opcode_memory1(opcode_memory1),
  .memWrite_memory1(memWrite_memory1),
  .memRead_memory1(memRead_memory1),
  .next_PC_select_memory1(next_PC_select_memory1),
  .regWrite_memory1(regWrite_memory1),
  // For Debug
  .instruction_memory1(instruction_memory1),
  
  .funct3_in(funct3),                                                        //added
  .funct3_out(funct3_exec)
);

// Access data memory and pass results toward writeback.
memory_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) MU (
  .clock(clock),
  .reset(reset),
  .stall(stall),

  // Connections to/from pipeline stages
  .load(memRead_memory1),
  .store(memWrite_memory1),
  .address(generated_addr),
  .store_data(rs2_data_memory1),
  //.ALU_result(ALU_result_memory),
  .data_addr(memory_addr_memory2),
  .load_data(memory_data_memory2),
  //.bypass_data(bypass_data_memory),
  .valid(valid_memory2), // Unused in 7 stage BRAM
  .ready(ready_memory2), // Unused in 7 stage BRAM

  // Data Memory Interface 
  .d_mem_out_addr(d_mem_out_addr),
  .d_mem_out_data(d_mem_out_data),
  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),

  .d_mem_address(d_mem_address),
  .d_mem_in_data(d_mem_in_data),
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),

  .report(report),
  
  //ADDED                                                                                              Added
  .funct3_in(funct3_exec),
  .funct3_out(funct3_e_m)
  
);
// Forward Memory2 results and register the writeback data.
memory_pipe_unit #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) MU_WB (
  .clock(clock),
  .reset(reset),

  .ALU_result_memory1(ALU_result_memory1),
  .load_data_memory2(memory_data_memory2), // memory_data_memory1 is the bram register
  .opwrite_memory1(regWrite_memory1),
  .opSel_memory1(memRead_memory1),
  .opReg_memory1(rd_memory1),
  .next_PC_select_memory1(next_PC_select_memory1),
  // For Debug
  .instruction_memory1(instruction_memory1),

  .ALU_result_writeback(ALU_result_writeback),
  .load_data_writeback(memory_data_writeback),
  .opwrite_writeback(regWrite_writeback),
  .opSel_writeback(memRead_writeback),
  .opReg_writeback(rd_writeback),
  .next_PC_select_writeback(next_PC_select_writeback),
  // For Debug
  .instruction_writeback(instruction_writeback),

  .bypass_data_memory2(bypass_data_memory2),
  .next_PC_select_memory2(next_PC_select_memory2),
  .opwrite_memory2(regWrite_memory2),
  .opReg_memory2(rd_memory2)
);

// Commit the selected result to the register file.
writeback_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) WB (
  .clock(clock),
  .reset(reset),
  .stall(stall),

  // TODO: Rename op* ports. It is not clear what op means. they also
  // violate the naming convention of using underscores and lower case.
  .opWrite(regWrite_writeback),
  .opSel(memRead_writeback),
  .opReg(rd_writeback),
  .ALU_Result(ALU_result_writeback),
  .memory_data(memory_data_writeback),
  .write(write_writeback),
  .write_reg(write_reg_writeback),
  .write_data(write_data_writeback),

  .report(report)
);



endmodule
