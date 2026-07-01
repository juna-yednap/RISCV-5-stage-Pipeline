// riscv_cpu.v - top-level 5-stage pipelined RISC-V core.
// Wires controller.v (ID-stage decode) to datapath.v (all 5 stages),
// the same controller/datapath split used by the original single-cycle
// design. The only structural difference: controller.v now decodes
// instr_d (the instruction latched into the IF/ID register) instead of a
// raw combinational fetch, since ID-stage control must stay stable for a
// full cycle and must itself be able to stall/flush with the pipeline.

module riscv_cpu (
    input         clk, reset,
    output [31:0] pc_f,
    input  [31:0] instr_f,
    output        mem_write_m,
    output [31:0] mem_wr_addr_m,
    output [31:0] mem_wr_data_m,
    input  [31:0] read_data_m,
    output [31:0] result_w
);

wire [31:0] instr_d;
wire [1:0]  result_src_d;
wire        mem_write_d, alu_src_d, reg_write_d, jump_d, branch_d;
wire [2:0]  imm_src_d;
wire [3:0]  alu_control_d;

controller ctrl (
    .op_d          (instr_d[6:0]),
    .funct3_d      (instr_d[14:12]),
    .funct7_b5_d   (instr_d[30]),
    .result_src_d  (result_src_d),
    .mem_write_d   (mem_write_d),
    .alu_src_d     (alu_src_d),
    .reg_write_d   (reg_write_d),
    .jump_d        (jump_d),
    .branch_d      (branch_d),
    .imm_src_d     (imm_src_d),
    .alu_control_d (alu_control_d)
);

datapath dp (
    .clk(clk), .reset(reset),
    .result_src_d(result_src_d), .mem_write_d(mem_write_d), .alu_src_d(alu_src_d),
    .reg_write_d(reg_write_d), .jump_d(jump_d), .branch_d(branch_d),
    .imm_src_d(imm_src_d), .alu_control_d(alu_control_d),
    .pc_f(pc_f), .instr_f(instr_f), .instr_d(instr_d),
    .mem_write_m(mem_write_m), .mem_wr_addr_m(mem_wr_addr_m), .mem_wr_data_m(mem_wr_data_m),
    .read_data_m(read_data_m),
    .result_w(result_w)
);

endmodule
