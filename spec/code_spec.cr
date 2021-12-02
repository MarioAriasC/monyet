require "./spec_helper"
require "../src/code"

include Code

describe "Code" do
  it "make" do
    [
      {Opcode::OpConstant, [65534], [Opcode::OpConstant.to_u8, 255.to_u8, 254.to_u8]},
      {Opcode::OpAdd, [] of Int32, [Opcode::OpAdd.to_u8]},
      {Opcode::OpGetLocal, [255], [Opcode::OpGetLocal.to_u8, 255.to_u8]},
    ].each do |op, operands, expected|
      instructions = if !operands.empty?
                       make(op, *Tuple(Int32).from(operands))
                     else
                       make(op)
                     end
      expected.size.should eq(instructions.size)
      expected.each_with_index do |byte, i|
        byte.should eq(instructions[i])
      end
    end
  end
end
