// mux3.v - 3-to-1 multiplexer (also reused as the EX-stage forwarding mux:
// sel = 00 -> d0 (register file value), 01 -> d1 (WB-stage result),
// 10 -> d2 (EX/MEM-stage ALU result))
module mux3 #(parameter WIDTH = 8) (
    input  [WIDTH-1:0] d0, d1, d2,
    input  [1:0]        sel,
    output [WIDTH-1:0] y
);

assign y = sel[1] ? d2 : (sel[0] ? d1 : d0);

endmodule
