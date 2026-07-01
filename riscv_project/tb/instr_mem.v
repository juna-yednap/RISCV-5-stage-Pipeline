// instr_mem.v - word-addressed instruction memory for simulation only.
//
// Contents are loaded from a plain-text file of one 32-bit hex instruction
// per line (e.g. "00500093"), using $readmemh. The file path is picked up
// at run time via the +MEMFILE=<path> plusarg so the same compiled sim
// binary can be reused for any program, no recompile needed. Falls back to
// programs/default.txt if no plusarg is given.

module instr_mem #(
    parameter DEPTH = 256   // number of 32-bit words
) (
    input  [31:0] pc,
    output [31:0] instr
);

    reg [31:0] RAM [0:DEPTH-1];
    reg [1023:0] memfile;

    initial begin
        integer i;
        for (i = 0; i < DEPTH; i = i + 1)
            RAM[i] = 32'h0000_0013; // default-fill with NOP (addi x0,x0,0)

        if (!$value$plusargs("MEMFILE=%s", memfile))
            memfile = "programs/default.txt";

        $readmemh(memfile, RAM);
        $display("[instr_mem] loaded program: %0s", memfile);
    end

    // byte address -> word index
    assign instr = RAM[pc[31:2]];

endmodule
