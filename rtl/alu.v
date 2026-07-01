// alu.v - ALU, lives in the Execute (EX) stage of the pipeline
// Cleaned up: removed dangling/undeclared wires from the original file
// (notzero, bltf, bgef, bltuf, bgeuf were assigned but never declared as
// ports or nets, and were unused by the rest of the design).

module alu #(parameter WIDTH = 32) (
    input      [WIDTH-1:0] src_a, src_b,   // ALU operands (was a, b)
    input      [3:0]       alu_ctrl,       // ALU control
    output reg [WIDTH-1:0] alu_result,     // ALU result (was alu_out)
    output                 zero_flag       // result == 0 (used for BEQ)
);

always @(*) begin
    case (alu_ctrl)
        4'b0000: alu_result = src_a + src_b;               // ADD / ADDI / loads / stores
        4'b0001: alu_result = src_a + ~src_b + 1'b1;        // SUB (also used for BEQ compare)
        4'b0010: alu_result = src_a & src_b;                // AND / ANDI
        4'b0011: alu_result = src_a | src_b;                // OR  / ORI
        4'b0110: alu_result = src_a ^ src_b;                // XOR
        4'b0111: alu_result = src_a << src_b;               // SLL
        4'b1000: alu_result = src_a >> src_b;               // SRL
        4'b1001: alu_result = src_a >>> src_b;              // SRA
        4'b1010: alu_result = (src_a < src_b) ? 32'd1 : 32'd0;                 // SLTU
        4'b0101: alu_result = ($signed(src_a) < $signed(src_b)) ? 32'd1 : 32'd0; // SLT
        default: alu_result = 32'd0;
    endcase
end

assign zero_flag = (alu_result == 32'd0);

endmodule
