// datapath.v - 5-stage pipelined RISC-V datapath: IF - ID - EX - MEM - WB
//
// Structure mirrors the classic Harris & Harris pipelined datapath:
//   * four pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB), each built
//     from a single flopenrc with all stage fields packed into one bus
//   * an internal hazard_unit providing stall/flush/forwarding control
//   * branch/jump outcome (PCSrcE) resolved in EX using the ALU's Zero
//     flag, feeding back to the IF-stage PC mux
//   * a fully combinational, "asynchronous-read" data memory interface
//     (Mem_WrAddr/Mem_WrData/ReadData) at the MEM stage, matching the
//     external memory module wiring used by the original single-cycle
//     design
//
// Decode-stage control signals (the *_d inputs) are produced externally
// by controller.v, which is fed back InstrD (exposed here) -- this keeps
// controller.v itself pipeline-agnostic, same as the original design.

module datapath (
    input             clk, reset,

    // control signals from controller.v, valid for InstrD (ID stage)
    input      [1:0]  result_src_d,
    input             mem_write_d,
    input             alu_src_d,
    input             reg_write_d, jump_d, branch_d,
    input      [2:0]  imm_src_d,
    input      [3:0]  alu_control_d,

    // instruction fetch / decode
    output     [31:0] pc_f,
    input      [31:0] instr_f,
    output     [31:0] instr_d,        // fed back into controller.v

    // data memory interface (MEM stage)
    output             mem_write_m,
    output     [31:0] mem_wr_addr_m, mem_wr_data_m,
    input      [31:0] read_data_m,

    // final writeback result, exposed for testing/observation
    output     [31:0] result_w
);

// =========================================================================
// IF stage
// =========================================================================
wire [31:0] pc_next_f, pc_plus4_f, pc_target_final_e;
wire        stall_f, pc_src_e;

adder pc_add4 (.a(pc_f), .b(32'd4), .y(pc_plus4_f));
mux2 #(32) pc_mux (.d0(pc_plus4_f), .d1(pc_target_final_e), .sel(pc_src_e), .y(pc_next_f));
flopenr #(32) pc_reg (.clk(clk), .reset(reset), .en(~stall_f), .d(pc_next_f), .q(pc_f));

// =========================================================================
// IF/ID pipeline register
// =========================================================================
wire [31:0] pc_plus4_d, pc_d;
wire        stall_d, flush_d;

flopenrc #(96) if_id_reg (
    .clk(clk), .reset(reset), .en(~stall_d), .clear(flush_d),
    .d({pc_plus4_f, instr_f, pc_f}),
    .q({pc_plus4_d, instr_d, pc_d})
);

// =========================================================================
// ID stage
// =========================================================================
wire [4:0]  rs1_d, rs2_d, rd_d;
wire [31:0] rd1_d, rd2_d, imm_ext_d;
wire        op5_d;

assign rs1_d = instr_d[19:15];
assign rs2_d = instr_d[24:20];
assign rd_d  = instr_d[11:7];
assign op5_d = instr_d[5];

reg_file rf (
    .clk(clk), .write_en_w(reg_write_w),
    .rs1_addr_d(rs1_d), .rs2_addr_d(rs2_d), .rd_addr_w(rd_w),
    .write_data_w(result_w),
    .rd1_d(rd1_d), .rd2_d(rd2_d)
);

imm_extend ext (.instr_d(instr_d[31:7]), .imm_src_d(imm_src_d), .imm_ext_d(imm_ext_d));

// =========================================================================
// ID/EX pipeline register
// =========================================================================
wire        reg_write_e, jump_e, branch_e, mem_write_e, alu_src_e, op5_e;
wire [1:0]  result_src_e;
wire [3:0]  alu_control_e;
wire [2:0]  funct3_e;
wire [31:0] rd1_e, rd2_e, pc_e, imm_ext_e, pc_plus4_e;
wire [4:0]  rs1_e, rs2_e, rd_e;
wire        flush_e;

flopenrc #(190) id_ex_reg (
    .clk(clk), .reset(reset), .en(1'b1), .clear(flush_e),
    .d({reg_write_d, result_src_d, mem_write_d, jump_d, branch_d,
        alu_control_d, alu_src_d, op5_d, instr_d[14:12],
        rd1_d, rd2_d, pc_d, rs1_d, rs2_d, rd_d, imm_ext_d, pc_plus4_d}),
    .q({reg_write_e, result_src_e, mem_write_e, jump_e, branch_e,
        alu_control_e, alu_src_e, op5_e, funct3_e,
        rd1_e, rd2_e, pc_e, rs1_e, rs2_e, rd_e, imm_ext_e, pc_plus4_e})
);

// =========================================================================
// EX stage
// =========================================================================
wire [1:0]  forward_ae, forward_be;
wire [31:0] src_a_e, write_data_e, src_b_e, alu_result_e;
wire        zero_e, pc_target_src_e;
wire [31:0] pc_target_e, auipc_lui_result_e;

mux3 #(32) fwd_a_mux (.d0(rd1_e), .d1(result_w), .d2(alu_result_m), .sel(forward_ae), .y(src_a_e));
mux3 #(32) fwd_b_mux (.d0(rd2_e), .d1(result_w), .d2(alu_result_m), .sel(forward_be), .y(write_data_e));
mux2 #(32) src_b_mux (.d0(write_data_e), .d1(imm_ext_e), .sel(alu_src_e), .y(src_b_e));

alu the_alu (.src_a(src_a_e), .src_b(src_b_e), .alu_ctrl(alu_control_e),
             .alu_result(alu_result_e), .zero_flag(zero_e));

adder pc_target_add (.a(pc_e), .b(imm_ext_e), .y(pc_target_e));

// jalr target = rs1+imm (alu_result_e, since ALUSrcE=1 selects imm as SrcB
// for jalr); jal/beq target = pc+imm (pc_target_e). Fixes a bug in the
// original single-cycle design, which always used pc+imm even for jalr.
assign pc_target_src_e   = jump_e & alu_src_e;
mux2 #(32) jump_target_mux (.d0(pc_target_e), .d1(alu_result_e), .sel(pc_target_src_e), .y(pc_target_final_e));

assign pc_src_e = (branch_e & (funct3_e[0] ? ~zero_e : zero_e)) | jump_e;

mux2 #(32) auipc_lui_mux (.d0(pc_target_e), .d1(imm_ext_e), .sel(op5_e), .y(auipc_lui_result_e));

// =========================================================================
// EX/MEM pipeline register
// =========================================================================
wire        reg_write_m;
wire [1:0]  result_src_m;
wire [31:0] alu_result_m, write_data_m, pc_plus4_m, auipc_lui_result_m;
wire [4:0]  rd_m;
wire [2:0]  funct3_m;

flopenrc #(140) ex_mem_reg (
    .clk(clk), .reset(reset), .en(1'b1), .clear(1'b0),
    .d({reg_write_e, result_src_e, mem_write_e,
        alu_result_e, write_data_e, rd_e, pc_plus4_e, auipc_lui_result_e, funct3_e}),
    .q({reg_write_m, result_src_m, mem_write_m,
        alu_result_m, write_data_m, rd_m, pc_plus4_m, auipc_lui_result_m, funct3_m})
);

assign mem_wr_addr_m = alu_result_m;
assign mem_wr_data_m = write_data_m;

// =========================================================================
// MEM stage - sign/zero-extend the raw memory read per load width
// =========================================================================
wire [31:0] read_data_ext_m;

mux8 #(32) load_extend_mux (
    .d0({{24{read_data_m[7]}},  read_data_m[7:0]}),   // lb
    .d1({{16{read_data_m[15]}}, read_data_m[15:0]}),   // lh
    .d2(read_data_m),                                   // lw
    .d3({24'b0, read_data_m[7:0]}),                     // lbu
    .d4({16'b0, read_data_m[15:0]}),                    // lhu
    .sel(funct3_m),
    .y(read_data_ext_m)
);

// =========================================================================
// MEM/WB pipeline register
// =========================================================================
wire        reg_write_w;
wire [1:0]  result_src_w;
wire [31:0] alu_result_w, read_data_w, pc_plus4_w, auipc_lui_result_w;
wire [4:0]  rd_w;

flopenrc #(136) mem_wb_reg (
    .clk(clk), .reset(reset), .en(1'b1), .clear(1'b0),
    .d({reg_write_m, result_src_m,
        alu_result_m, read_data_ext_m, rd_m, pc_plus4_m, auipc_lui_result_m}),
    .q({reg_write_w, result_src_w,
        alu_result_w, read_data_w, rd_w, pc_plus4_w, auipc_lui_result_w})
);

// =========================================================================
// WB stage
// =========================================================================
mux4 #(32) result_mux (
    .d0(alu_result_w), .d1(read_data_w), .d2(pc_plus4_w), .d3(auipc_lui_result_w),
    .sel(result_src_w), .y(result_w)
);

// =========================================================================
// Hazard unit
// =========================================================================
hazard_unit hu (
    .rs1_d(rs1_d), .rs2_d(rs2_d),
    .rs1_e(rs1_e), .rs2_e(rs2_e), .rd_e(rd_e),
    .rd_m(rd_m), .rd_w(rd_w),
    .reg_write_m(reg_write_m), .reg_write_w(reg_write_w),
    .result_src_e0(result_src_e[0]),
    .pc_src_e(pc_src_e),
    .forward_ae(forward_ae), .forward_be(forward_be),
    .stall_f(stall_f), .stall_d(stall_d),
    .flush_d(flush_d), .flush_e(flush_e)
);

endmodule
