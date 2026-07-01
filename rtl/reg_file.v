// reg_file.v - 32x32 register file, x0 hardwired to 0.
// Write happens in the Writeback (WB) stage; both read ports are
// combinational and are read in the Decode (ID) stage.
//
// Added an explicit write-through bypass: if the WB-stage write and an
// ID-stage read target the same register in the same cycle, the read
// returns the value being written *this* cycle rather than the stale
// stored value. This is required in a 5-stage pipeline because WB and ID
// can legitimately overlap on the same register (the "WB doesn't need a
// forwarding-unit path" case) -- without it, results computed by an
// instruction in WB would be missed by an instruction two cycles behind it
// in ID depending on relative event ordering in simulation.

module reg_file #(parameter DATA_WIDTH = 32) (
    input                          clk,
    input                          write_en_w,
    input      [4:0]               rs1_addr_d, rs2_addr_d, rd_addr_w,
    input      [DATA_WIDTH-1:0]    write_data_w,
    output     [DATA_WIDTH-1:0]    rd1_d, rd2_d
);

reg [DATA_WIDTH-1:0] regs [0:31];

integer i;
initial begin
    for (i = 0; i < 32; i = i + 1)
        regs[i] = 0;
end

// synchronous write
always @(posedge clk) begin
    if (write_en_w) regs[rd_addr_w] <= write_data_w;
end

// combinational read with same-cycle write-through bypass, x0 hardwired 0
assign rd1_d = (rs1_addr_d == 5'd0) ? 32'd0 :
               (write_en_w && (rs1_addr_d == rd_addr_w)) ? write_data_w :
               regs[rs1_addr_d];

assign rd2_d = (rs2_addr_d == 5'd0) ? 32'd0 :
               (write_en_w && (rs2_addr_d == rd_addr_w)) ? write_data_w :
               regs[rs2_addr_d];

endmodule
