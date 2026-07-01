// adder.v - simple combinational adder
// Used for: PC+4 (fetch stage) and PC+immediate branch/jump target (execute stage)

module adder #(parameter WIDTH = 32) (
    input  [WIDTH-1:0] a, b,
    output [WIDTH-1:0] y
);

assign y = a + b;

endmodule
