// imm_extend.v - immediate sign/zero extension, lives in the Decode (ID)
// stage. Port width fixed from [1:0] to [2:0] to actually match the 5
// immediate formats it decodes (I, S, B, J, U) -- see main_decoder.v.

module imm_extend (
    input      [31:7] instr_d,
    input      [ 2:0] imm_src_d,
    output reg [31:0] imm_ext_d
);

always @(*) begin
    case (imm_src_d)
        // I-type (loads, I-type ALU, jalr)
        3'b000:  imm_ext_d = {{20{instr_d[31]}}, instr_d[31:20]};
        // S-type (stores)
        3'b001:  imm_ext_d = {{20{instr_d[31]}}, instr_d[31:25], instr_d[11:7]};
        // B-type (branches)
        3'b010:  imm_ext_d = {{20{instr_d[31]}}, instr_d[7], instr_d[30:25], instr_d[11:8], 1'b0};
        // J-type (jal)
        3'b011:  imm_ext_d = {{12{instr_d[31]}}, instr_d[19:12], instr_d[20], instr_d[30:21], 1'b0};
        // U-type (lui, auipc)
        3'b100:  imm_ext_d = {instr_d[31:12], 12'b0};
        default: imm_ext_d = 32'b0; // safe default (e.g. for bubbles), never X
    endcase
end

endmodule
