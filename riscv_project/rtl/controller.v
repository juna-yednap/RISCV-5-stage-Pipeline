// controller.v - Decode-stage (ID) control unit.
// Produces only combinational *_d control signals from the instruction
// currently in ID. Unlike the single-cycle version, this module no longer
// computes PCSrc: in the pipelined design the branch/jump outcome depends
// on the Zero flag out of the EX-stage ALU, so PCSrc is now computed in
// datapath.v's EX stage (as PCSrcE) once Branch/Jump have propagated
// through the ID/EX pipeline register.

module controller (
    input      [6:0] op_d,
    input      [2:0] funct3_d,
    input             funct7_b5_d,
    output     [1:0] result_src_d,
    output            mem_write_d,
    output            alu_src_d,
    output            reg_write_d, jump_d, branch_d,
    output     [2:0] imm_src_d,
    output     [3:0] alu_control_d
);

wire [1:0] alu_op_d;

main_decoder md (
    .op_d          (op_d),
    .result_src_d  (result_src_d),
    .mem_write_d   (mem_write_d),
    .branch_d      (branch_d),
    .alu_src_d     (alu_src_d),
    .reg_write_d   (reg_write_d),
    .jump_d        (jump_d),
    .imm_src_d     (imm_src_d),
    .alu_op_d      (alu_op_d)
);

alu_decoder ad (
    .op_b5          (op_d[5]),
    .funct3_d       (funct3_d),
    .funct7_b5_d    (funct7_b5_d),
    .alu_op_d       (alu_op_d),
    .alu_control_d  (alu_control_d)
);

endmodule
