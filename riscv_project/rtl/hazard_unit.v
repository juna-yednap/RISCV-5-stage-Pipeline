// hazard_unit.v - detects data hazards (load-use) and control hazards
// (taken branch/jump), and drives:
//   - ForwardAE/ForwardBE : EX-stage operand forwarding select
//   - StallF/StallD       : freeze IF and ID for one cycle on load-use
//   - FlushD/FlushE       : squash IF/ID and ID/EX pipeline regs
//
// This is the standard textbook hazard unit (Harris & Harris): forwarding
// from EX/MEM and MEM/WB into the EX stage ALU inputs, a one-cycle stall
// for load-use hazards, and a two-instruction flush (FlushD covers the
// instruction just fetched, FlushE covers the one already in ID) whenever
// a branch/jump resolves taken in EX.

module hazard_unit (
    input      [4:0] rs1_d, rs2_d,         // ID-stage source regs (for load-use check)
    input      [4:0] rs1_e, rs2_e,         // EX-stage source regs (for forwarding)
    input      [4:0] rd_e,                 // EX-stage dest reg (for load-use check)
    input      [4:0] rd_m, rd_w,           // MEM/WB-stage dest regs (for forwarding)
    input             reg_write_m, reg_write_w,
    input             result_src_e0,       // ResultSrcE[0]: 1 => instruction in EX is a load
    input             pc_src_e,            // taken branch/jump resolved in EX

    output reg [1:0] forward_ae, forward_be,
    output            stall_f, stall_d,
    output            flush_d, flush_e
);

// ----- EX-stage operand forwarding -----
always @(*) begin
    // operand A (rs1)
    if      ((rs1_e != 5'd0) && (rs1_e == rd_m) && reg_write_m) forward_ae = 2'b10; // from EX/MEM
    else if ((rs1_e != 5'd0) && (rs1_e == rd_w) && reg_write_w) forward_ae = 2'b01; // from MEM/WB
    else                                                        forward_ae = 2'b00; // from register file

    // operand B (rs2)
    if      ((rs2_e != 5'd0) && (rs2_e == rd_m) && reg_write_m) forward_be = 2'b10;
    else if ((rs2_e != 5'd0) && (rs2_e == rd_w) && reg_write_w) forward_be = 2'b01;
    else                                                        forward_be = 2'b00;
end

// ----- load-use hazard: stall IF/ID one cycle, bubble into EX -----
wire lw_stall;
assign lw_stall = result_src_e0 && (rd_e != 5'd0) && ((rd_e == rs1_d) || (rd_e == rs2_d));

assign stall_f = lw_stall;
assign stall_d = lw_stall;

// ----- control hazard: flush on taken branch/jump -----
assign flush_d = pc_src_e;
assign flush_e = lw_stall | pc_src_e;

endmodule
