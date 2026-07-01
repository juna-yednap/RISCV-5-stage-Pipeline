// alu_decoder.v - generates the 4-bit ALU control signal from opcode/funct
// bits. Purely combinational, lives in the Decode (ID) stage.
//
// Bug fix vs original: the R-type SUB case assigned a 3-bit literal
// (3'b001) into a 4-bit reg, which zero-extended incorrectly and produced
// ALUControl = 4'b0001 only by accident of bit position -- rewritten
// explicitly and correctly below.

module alu_decoder (
    input            op_b5,      // opcode[5]: 1 = R-type, 0 = I-type ALU op
    input      [2:0] funct3_d,
    input            funct7_b5_d,
    input      [1:0] alu_op_d,
    output reg [3:0] alu_control_d
);

localparam ALU_ADD  = 4'b0000;
localparam ALU_SUB  = 4'b0001;
localparam ALU_AND  = 4'b0010;
localparam ALU_OR   = 4'b0011;
localparam ALU_XOR  = 4'b0110;
localparam ALU_SLL  = 4'b0111;
localparam ALU_SRL  = 4'b1000;
localparam ALU_SRA  = 4'b1001;
localparam ALU_SLT  = 4'b0101;
localparam ALU_SLTU = 4'b1010;

always @(*) begin
    case (alu_op_d)
        2'b00: alu_control_d = ALU_ADD;   // loads/stores/jal/jalr address calc
        2'b01: alu_control_d = ALU_SUB;   // branch (beq) compare
        default: begin                     // R-type / I-type ALU ops
            case (funct3_d)
                3'b000:  alu_control_d = (funct7_b5_d & op_b5) ? ALU_SUB : ALU_ADD; // sub / add,addi
                3'b001:  alu_control_d = ALU_SLL;
                3'b010:  alu_control_d = ALU_SLT;
                3'b011:  alu_control_d = ALU_SLTU;
                3'b100:  alu_control_d = ALU_XOR;
                3'b101:  alu_control_d = (funct7_b5_d) ? ALU_SRA : ALU_SRL;
                3'b110:  alu_control_d = ALU_OR;
                3'b111:  alu_control_d = ALU_AND;
                default: alu_control_d = ALU_ADD; // safe default, e.g. for bubbles
            endcase
        end
    endcase
end

endmodule
