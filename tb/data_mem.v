// data_mem.v - word-addressed data memory for simulation only.
// Synchronous write (posedge clk when we=1), combinational read.

module data_mem #(
    parameter DEPTH = 256   // number of 32-bit words
) (
    input         clk,
    input         we,
    input  [31:0] addr,
    input  [31:0] wd,
    output [31:0] rd
);

    reg [31:0] RAM [0:DEPTH-1];

    initial begin
        integer i;
        for (i = 0; i < DEPTH; i = i + 1)
            RAM[i] = 32'h0;
    end

    assign rd = RAM[addr[31:2]];

    always @(posedge clk)
        if (we) RAM[addr[31:2]] <= wd;

endmodule
