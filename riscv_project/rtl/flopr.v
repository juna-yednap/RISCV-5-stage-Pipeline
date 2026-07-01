// flopr.v - simple resettable D flip-flop (was reset_ff.v).
// Used for the PC register when it doesn't need to stall.
module flopr #(parameter WIDTH = 8) (
    input                   clk, reset,
    input      [WIDTH-1:0]  d,
    output reg [WIDTH-1:0]  q
);

always @(posedge clk or posedge reset) begin
    if (reset) q <= 0;
    else       q <= d;
end

endmodule
