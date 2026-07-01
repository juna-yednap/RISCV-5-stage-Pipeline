// riscv_cpu_wrapper.v - top wrapper for testing the 5-stage pipelined riscv_cpu
// (renamed from t1c_riscv_cpu.v). Same external interface/behavior as the
// original: instr_mem and data_mem are expected to be provided
// externally, exactly as in the original single-cycle testbench setup
// (they were not part of the uploaded module set there either).
//
// Note the address/data signals here are all MEM-stage (mem_wr_addr_m
// etc.), i.e. they reflect the instruction currently in the Memory stage
// of the pipeline, not the instruction most recently fetched.

module riscv_cpu_wrapper (
    input         clk, reset,
    input         ext_mem_write,
    input  [31:0] ext_write_data, ext_data_addr,
    output        mem_write,
    output [31:0] write_data, data_addr, read_data,
    output [31:0] pc, result
);

wire [31:0] instr;
wire [31:0] data_addr_rv32, write_data_rv32;
wire        mem_write_rv32;

// instantiate processor and memories
riscv_cpu rvcpu (
    .clk(clk), .reset(reset),
    .pc_f(pc), .instr_f(instr),
    .mem_write_m(mem_write_rv32),
    .mem_wr_addr_m(data_addr_rv32),
    .mem_wr_data_m(write_data_rv32),
    .read_data_m(read_data),
    .result_w(result)
);

instr_mem instrmem (.pc(pc), .instr(instr));
data_mem  datamem  (.clk(clk), .we(mem_write), .addr(data_addr), .wd(write_data), .rd(read_data));

assign mem_write  = (ext_mem_write && reset) ? 1'b1 : mem_write_rv32;
assign write_data = (ext_mem_write && reset) ? ext_write_data : write_data_rv32;
assign data_addr  = reset ? ext_data_addr : data_addr_rv32;

endmodule
