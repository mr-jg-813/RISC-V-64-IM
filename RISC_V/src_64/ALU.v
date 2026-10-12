// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
module ALU #(parameter DATA_WIDTH = 64)(
        ALU_Control,
        operand_A, operand_B,
        ALU_result, zero, branch
);
input [6:0] ALU_Control;
input [DATA_WIDTH-1:0]  operand_A ;
input [DATA_WIDTH-1:0]  operand_B ;
output zero, branch;
output [DATA_WIDTH-1:0] ALU_result;


localparam SHAMT_WIDTH = $clog2(DATA_WIDTH);
wire [SHAMT_WIDTH-1:0] shamt;
wire signed [DATA_WIDTH-1:0] signed_operand_A;
wire signed [DATA_WIDTH-1:0] signed_operand_B;

// wires for signed operations
wire [(DATA_WIDTH*2)-1:0] arithmetic_right_shift_double;
wire [DATA_WIDTH-1:0] arithmetic_right_shift;
wire signed [DATA_WIDTH-1:0] signed_less_than;
wire signed [DATA_WIDTH-1:0] signed_greater_than_equal;
wire signed [(DATA_WIDTH / 2)-1:0] signed_word_operand_A; // ] 32 bit 
wire [4:0] word_shamt;

wire [(DATA_WIDTH / 2)-1:0] RV64_add_result; // ]
wire [(DATA_WIDTH / 2)-1:0] RV64_sub_result; // ]
wire [(DATA_WIDTH / 2)-1:0] RV64_sll_result; // ]32 bit 
wire [(DATA_WIDTH / 2)-1:0] RV64_srl_result; // ]
wire [(DATA_WIDTH / 2)-1:0] RV64_sra_result; // ]

wire [(DATA_WIDTH * 2)-1:0] mul_result;    // ]
wire [(DATA_WIDTH * 2)-1:0] mulhsu_result; // ]128 bit 
wire [(DATA_WIDTH * 2)-1:0] mulhu_result;  // ]
wire [(DATA_WIDTH * 2)-1:0] mulhsu_operand_A =
    {{DATA_WIDTH{operand_A[DATA_WIDTH-1]}}, operand_A};
wire [(DATA_WIDTH * 2)-1:0] mulhsu_operand_B =
    {{DATA_WIDTH{1'b0}}, operand_B};

wire [DATA_WIDTH-1:0] div_result;   
wire [DATA_WIDTH-1:0] divu_result; 

wire [DATA_WIDTH-1:0] rem_result; 
wire [DATA_WIDTH-1:0] remu_result;

wire [(DATA_WIDTH / 2)-1:0] mulw_result;
wire [(DATA_WIDTH / 2)-1:0] divw_result;
wire [(DATA_WIDTH / 2)-1:0] divuw_result;
wire [(DATA_WIDTH / 2)-1:0] remw_result;
wire [(DATA_WIDTH / 2)-1:0] remuw_result;

assign shamt = operand_B[SHAMT_WIDTH-1:0];

assign signed_operand_A = operand_A;
assign signed_operand_B = operand_B;
assign signed_word_operand_A = operand_A[31:0];
assign word_shamt = operand_B[4:0];

assign zero   = (ALU_result==0);
assign branch = (ALU_Control[6:3] == 4'b0010) & (ALU_result == 1'b1);

// Signed Operations
assign arithmetic_right_shift_double = ({ {DATA_WIDTH{operand_A[DATA_WIDTH-1]}}, operand_A }) >> shamt;
assign arithmetic_right_shift        = arithmetic_right_shift_double[DATA_WIDTH-1:0];
assign signed_less_than              = signed_operand_A < signed_operand_B;
assign signed_greater_than_equal     = signed_operand_A >= signed_operand_B;

assign RV64_add_result = operand_A[31:0] + operand_B[31:0];
assign RV64_sub_result = operand_A[31:0] - operand_B[31:0];
assign RV64_sll_result = operand_A[31:0] << word_shamt;
assign RV64_srl_result = operand_A[31:0] >> word_shamt;
assign RV64_sra_result = signed_word_operand_A >>> word_shamt;

assign mul_result   = $signed(operand_A) * $signed(operand_B); // mul
// Explicitly extend A as signed and B as unsigned before multiplication.
assign mulhsu_result  = mulhsu_operand_A * mulhsu_operand_B;    // mulhsu
assign mulhu_result  = operand_A * operand_B;                  // mulhu

assign div_result  = $signed(operand_A) / $signed(operand_B); // div
assign divu_result  = operand_A / operand_B;                  // divu

assign rem_result  = $signed(operand_A) % $signed(operand_B); // rem
assign remu_result  = operand_A % operand_B;                  // remu

assign mulw_result  = $signed(operand_A[31:0]) * $signed(operand_B[31:0]); // mulw
assign divw_result  = $signed(operand_A[31:0]) / $signed(operand_B[31:0]); // divw 
assign divuw_result = operand_A[31:0] / operand_B[31:0];                   // divuw
assign remw_result  = $signed(operand_A[31:0]) % $signed(operand_B[31:0]); // remw
assign remuw_result = operand_A[31:0] % operand_B[31:0];                   // remuw

// Select the arithmetic, logic, shift, or branch result.
assign ALU_result =
            (ALU_Control == 7'b0000_000) ? operand_A + operand_B:      /* ADD, ADDI*/
            (ALU_Control == 7'b0001_000) ? operand_A - operand_B:      /* SUB */
            (ALU_Control == 7'b0000_100) ? operand_A ^ operand_B:      /* XOR, XORI*/
            (ALU_Control == 7'b0000_110) ? operand_A | operand_B:      /* OR, ORI */
            (ALU_Control == 7'b0000_111) ? operand_A & operand_B:      /* AND, ANDI */
            (ALU_Control == 7'b0000_010) ? signed_less_than:           /* SLT, SLTI */
            (ALU_Control == 7'b0000_011) ? operand_A < operand_B:      /* SLTU, SLTIU */
            (ALU_Control == 7'b0000_001) ? operand_A << shamt:         /* SLL, SLLI => 0's shifted in from right */
            (ALU_Control == 7'b0000_101) ? operand_A >> shamt:         /* SRL, SRLI => 0's shifted in from left */
            (ALU_Control == 7'b0001_101) ? arithmetic_right_shift:     /* SRA, SRAI => sign bit shifted in from left */
            (ALU_Control == 7'b0011_111) ? operand_A:                  /* operand_A = PC+4 for JAL   and JALR */
            (ALU_Control == 7'b0010_000) ? operand_A == operand_B:     /* BEQ */
            (ALU_Control == 7'b0010_001) ? operand_A != operand_B:     /* BNE */
            (ALU_Control == 7'b0010_100) ? signed_less_than:           /* BLT */
            (ALU_Control == 7'b0010_101) ? signed_greater_than_equal:  /* BGE */
            (ALU_Control == 7'b0010_110) ? operand_A < operand_B:      /* BLTU */
            (ALU_Control == 7'b0010_111) ? operand_A >= operand_B:     /* BGEU */
            
            (ALU_Control == 7'b0100_000) ? {{(DATA_WIDTH-32){RV64_add_result[31]}}, RV64_add_result} :// ADDIW, ADDW
            (ALU_Control == 7'b0100_001) ? {{(DATA_WIDTH-32){RV64_sll_result[31]}}, RV64_sll_result} :// SLLIW, SLLW
            (ALU_Control == 7'b0100_101) ? {{(DATA_WIDTH-32){RV64_srl_result[31]}}, RV64_srl_result} :// SRLIW, SRLW
            (ALU_Control == 7'b0101_000) ? {{(DATA_WIDTH-32){RV64_sub_result[31]}}, RV64_sub_result} :// SUBW
            (ALU_Control == 7'b0101_101) ? {{(DATA_WIDTH-32){RV64_sra_result[31]}}, RV64_sra_result} :// SRAIW, SRAW
            
            (ALU_Control == 7'b1001_000) ? mul_result[63:0] :       // mul
            (ALU_Control == 7'b1001_001) ? mul_result[127:64] :     // mulh
            (ALU_Control == 7'b1001_010) ? mulhsu_result[127:64] :  // mulhsu
            (ALU_Control == 7'b1001_011) ? mulhu_result[127:64] :   // mulhu
            
            (ALU_Control == 7'b1001_100) ? div_result :   // div
            (ALU_Control == 7'b1001_101) ? divu_result :  // divu
         
            (ALU_Control == 7'b1001_110) ? rem_result :   // rem
            (ALU_Control == 7'b1001_111) ? remu_result :  // remu
            
            (ALU_Control == 7'b1010_000) ? {{(DATA_WIDTH-32){mulw_result[31]}},mulw_result} :  // mulw
            (ALU_Control == 7'b1010_100) ? {{(DATA_WIDTH-32){divw_result[31]}},divw_result} :  // divw
            (ALU_Control == 7'b1010_101) ? {{(DATA_WIDTH-32){divuw_result[31]}},divuw_result} :  // divuw
            (ALU_Control == 7'b1010_110) ? {{(DATA_WIDTH-32){remw_result[31]}},remw_result} :  // remw
            (ALU_Control == 7'b1010_111) ? {{(DATA_WIDTH-32){remuw_result[31]}},remuw_result} :  // remuw
            
            {DATA_WIDTH{1'b0}};
endmodule


