macro ret_ins
  puts typeof(ex)
  puts ex.message
  {% if flag?(:slice) %}
  return Instructions.empty
  {% else %}
  return [] of UInt8
  {% end %}
end

module Code
  extend self
  enum Opcode
    OpConstant
    OpAdd
    OpPop
    OpSub
    OpMul
    OpDiv
    OpTrue
    OpFalse
    OpEqual
    OpNotEqual
    OpGreaterThan
    OpMinus
    OpBang
    OpJumpNotTruthy
    OpJump
    OpNull
    OpGetGlobal
    OpSetGlobal
    OpArray
    OpHash
    OpIndex
    OpCall
    OpReturnValue
    OpReturn
    OpGetLocal
    OpSetLocal
    OpGetBuiltin
    OpClosure
    OpGetFree
    OpCurrentClosure
  end

  class Definition
    getter name
    getter operands_widths

    def initialize(@name : String, @operands_widths : Array(Int32))
    end

    def to_s(io)
      io << "Definition(name=#{@name}, operand_widths=#{@operands_widths})"
    end
  end

  DEFINITIONS = {
    Opcode::OpConstant       => "OpConstant".to_definition(2),
    Opcode::OpAdd            => "OpAdd".to_definition,
    Opcode::OpPop            => "OpPop".to_definition,
    Opcode::OpSub            => "OpSub".to_definition,
    Opcode::OpMul            => "OpMul".to_definition,
    Opcode::OpDiv            => "OpDiv".to_definition,
    Opcode::OpTrue           => "OpTrue".to_definition,
    Opcode::OpFalse          => "OpFalse".to_definition,
    Opcode::OpEqual          => "OpEqual".to_definition,
    Opcode::OpNotEqual       => "OpNotEqual".to_definition,
    Opcode::OpGreaterThan    => "OpGreaterThan".to_definition,
    Opcode::OpMinus          => "OpMinus".to_definition,
    Opcode::OpBang           => "OpBang".to_definition,
    Opcode::OpJumpNotTruthy  => "OpJumpNotTruthy".to_definition(2),
    Opcode::OpJump           => "OpJump".to_definition(2),
    Opcode::OpNull           => "OpNull".to_definition,
    Opcode::OpGetGlobal      => "OpGetGlobal".to_definition(2),
    Opcode::OpSetGlobal      => "OpSetGlobal".to_definition(2),
    Opcode::OpArray          => "OpArray".to_definition(2),
    Opcode::OpHash           => "OpHash".to_definition(2),
    Opcode::OpIndex          => "OpIndex".to_definition,
    Opcode::OpCall           => "OpCall".to_definition(1),
    Opcode::OpReturnValue    => "OpReturnValue".to_definition,
    Opcode::OpReturn         => "OpReturn".to_definition,
    Opcode::OpGetLocal       => "OpGetLocal".to_definition(1),
    Opcode::OpSetLocal       => "OpSetLocal".to_definition(1),
    Opcode::OpGetBuiltin     => "OpGetBuiltin".to_definition(1),
    Opcode::OpClosure        => "OpClosure".to_definition(2, 1),
    Opcode::OpGetFree        => "OpGetFree".to_definition(1),
    Opcode::OpCurrentClosure => "OpCurrentClosure".to_definition,
  }

  {% if flag?(:slice) %}
    alias Instructions = Bytes
  {% else %}
    alias Instructions = Array(UInt8)
  {% end %}

  def lookup(op : Opcode) : Definition
    definition = DEFINITIONS[op]
    if !definition.nil?
      return definition
    else
      raise "opcode #{op} undefined"
    end
  end

  def make(op : Opcode, *operands : Int32) : Instructions
    definition = lookup(op)
    instruction_length = definition.operands_widths.sum + 1
    instruction = Instructions.new(instruction_length, 0)
    instruction[0] = op.to_u8
    offset = 1
    operands.each_with_index do |operand, i|
      width = definition.operands_widths[i]
      case width
      when 2
        instruction[offset] = ((operand.to_u32 >> 8) & 255).to_u8
        instruction[offset + 1] = ((operand.to_u32 >> 0) & 255).to_u8
      when 1
        instruction[offset] = operand.to_u8
      end
      offset += width
    end
    return instruction
  rescue ex
    ret_ins
  end

  def make(op : Opcode) : Instructions
    lookup(op)
    {% if flag?(:slice) %}
      return Instructions[op.to_u8]
    {% else %}
      return [op.to_u8]
    {% end %}
  rescue ex
    ret_ins
  end

  def onset(ins : Instructions, i : Int32) : Instructions
    ins[0..(i - 1)]
  end

  alias MBytes = OffsetArray | Instructions

  private def offset(ins : Instructions, i : Int32) : MBytes
    OffsetArray.new(ins, i)
  end

  def read_int(ins : Instructions, i : Int32) : Int32
    return read_u16(offset(ins, i)).to_i
  end

  private def read_u16(ins : MBytes) : UInt16
    ch1 = read(ins, 0)
    ch2 = read(ins, 1)
    if (ch1 | ch2) < 0
      raise ""
    else
      return ((ch1 << 8) + (ch2 << 0)).to_u16
    end
  end

  private def read(ins : MBytes, position : Int32) : Int32
    return (ins[position] & 255.to_u).to_i
  end

  def read_byte(ins : Instructions, i : Int32) : UInt8
    return read_u8(offset(ins, i))
  end

  private def read_u8(ins : MBytes) : UInt8
    int = read(ins, 0)
    if (int < 0)
      raise "error reading byte"
    else
      return int.to_u8
    end
  end

  struct OffsetArray
    def initialize(@inner : Instructions, @offset : Int32)
    end

    def [](i : Int32) : UInt8
      return @inner[i + @offset]
    end
  end
end

class String
  def to_definition(*operands_with : Int32) : Code::Definition
    return Code::Definition.new(self, operands_with.to_a)
  end

  def to_definition : Code::Definition
    return Code::Definition.new(self, [] of Int32)
  end
end
