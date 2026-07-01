// flopenrc.v - resettable D flip-flop with clock-enable AND synchronous
// clear. This is the workhorse pipeline-register primitive: one instance
// is used (with the data/control fields concatenated into a single bus)
// for each of IF/ID, ID/EX, EX/MEM, and MEM/WB.
//   reset : asynchronous, clears q immediately (global reset)
//   en    : clock-enable; when low, the register holds its value (stall)
//   clear : synchronous flush; when en is high and clear is high, q is
//           cleared to 0 next edge instead of loading d (used to squash
//           bubbles into the pipeline on a taken branch/jump or load-use
//           hazard)
module flopenrc #(parameter WIDTH = 8) (
    input                   clk, reset, en, clear,
    input      [WIDTH-1:0]  d,
    output reg [WIDTH-1:0]  q
);

always @(posedge clk or posedge reset) begin
    if (reset)   q <= 0;
    else if (en) q <= clear ? 0 : d;
end

endmodule
