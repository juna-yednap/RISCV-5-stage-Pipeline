// main_decoder.v - top-level opcode decoder, lives in the Decode (ID) stage.
//
// Bug fix vs original: ImmSrc is driven with 3-bit case values (000..100,
// five immediate formats: I/S/B/J/U) but the original port declared it as
// [1:0] (only 2 bits) -- the top bit was silently truncated, corrupting
// U-type (lui/auipc) immediate selection. Widened to [2:0] to match
// imm_extend.v.

module main_decoder (
    input      [6:0] op_d,
    output     [1:0] result_src_d,
    output           mem_write_d, branch_d, alu_src_d,
    output           reg_write_d, jump_d,
    output     [2:0] imm_src_d,
    output     [1:0] alu_op_d
);

reg [11:0] controls; // 12 bits: RegWrite(1)+ImmSrc(3)+ALUSrc(1)+MemWrite(1)+ResultSrc(2)+Branch(1)+ALUOp(2)+Jump(1)
                     // (was declared [12:0]/13 bits, one bit wider than ever driven -- harmless,
                     // since the phantom MSB was always zero-padded, but incorrect and worth fixing)

localparam OP_LOAD   = 7'b0000011; // lw, lb, lh
localparam OP_STORE  = 7'b0100011; // sw
localparam OP_RTYPE  = 7'b0110011; // R-type
localparam OP_BRANCH = 7'b1100011; // beq
localparam OP_ITYPE  = 7'b0010011; // I-type ALU
localparam OP_JAL    = 7'b1101111; // jal
localparam OP_JALR   = 7'b1100111; // jalr
localparam OP_LUI    = 7'b0110111; // lui
localparam OP_AUIPC  = 7'b0010111; // auipc

always @(*) begin
    // RegWrite_ImmSrc[2:0]_ALUSrc_MemWrite_ResultSrc[1:0]_Branch_ALUOp[1:0]_Jump
    case (op_d)
        OP_LOAD:   controls = 12'b1_000_1_0_01_0_00_0;
        OP_STORE:  controls = 12'b0_001_1_1_00_0_00_0;
        OP_RTYPE:  controls = 12'b1_xxx_0_0_00_0_10_0;
        OP_BRANCH: controls = 12'b0_010_0_0_00_1_01_0;
        OP_ITYPE:  controls = 12'b1_000_1_0_00_0_10_0;
        OP_JAL:    controls = 12'b1_011_0_0_10_0_00_1;
        OP_JALR:   controls = 12'b1_000_1_0_10_0_00_1;
        OP_LUI:    controls = 12'b1_100_1_0_11_0_00_0;
        OP_AUIPC:  controls = 12'b1_100_1_0_11_0_00_0;
        // Unrecognized opcode -> safe no-op controls (never X). This
        // matters in the pipeline: a flushed/reset pipeline slot carries
        // instruction 32'h0 (opcode 0000000, not a real RISC-V opcode)
        // through IF/ID, and it must decode to "do nothing" rather than
        // poisoning every downstream stage with X.
        default:   controls = 12'b0_000_0_0_00_0_00_0;
    endcase
end

assign {reg_write_d, imm_src_d, alu_src_d, mem_write_d,
        result_src_d, branch_d, alu_op_d, jump_d} = controls;

endmodule
