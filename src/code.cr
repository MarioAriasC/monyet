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

  DEF_OP_CONSTANT        = "OpConstant".to_definition(2)
  DEF_OP_ADD             = "OpAdd".to_definition
  DEF_OP_POP             = "OpPop".to_definition
  DEF_OP_SUB             = "OpSub".to_definition
  DEF_OP_MUL             = "OpMul".to_definition
  DEF_OP_DIV             = "OpDiv".to_definition
  DEF_OP_TRUE            = "OpTrue".to_definition
  DEF_OP_FALSE           = "OpFalse".to_definition
  DEF_OP_EQUAL           = "OpEqual".to_definition
  DEF_OP_NOT_EQUAL       = "OpNotEqual".to_definition
  DEF_OP_GREATER_THAN    = "OpGreaterThan".to_definition
  DEF_OP_MINUS           = "OpMinus".to_definition
  DEF_OP_BANG            = "OpBang".to_definition
  DEF_OP_JUMP_NOT_TRUTHY = "OpJumpNotTruthy".to_definition(2)
  DEF_OP_JUMP            = "OpJump".to_definition(2)
  DEF_OP_NULL            = "OpNull".to_definition
  DEF_OP_GET_GLOBAL      = "OpGetGlobal".to_definition(2)
  DEF_OP_SET_GLOBAL      = "OpSetGlobal".to_definition(2)
  DEF_OP_ARRAY           = "OpArray".to_definition(2)
  DEF_OP_HASH            = "OpHash".to_definition(2)
  DEF_OP_INDEX           = "OpIndex".to_definition
  DEF_OP_CALL            = "OpCall".to_definition(1)
  DEF_OP_RETURN_VALUE    = "OpReturnValue".to_definition
  DEF_OP_RETURN          = "OpReturn".to_definition
  DEF_OP_GET_LOCAL       = "OpGetLocal".to_definition(1)
  DEF_OP_SET_LOCAL       = "OpSetLocal".to_definition(1)
  DEF_OP_GET_BUILTIN     = "OpGetBuiltin".to_definition(1)
  DEF_OP_CLOSURE         = "OpClosure".to_definition(2, 1)
  DEF_OP_GET_FREE        = "OpGetFree".to_definition(1)
  DEF_OP_CURRENT_CLOSURE = "OpCurrentClosure".to_definition

  {% if flag?(:slice) %}
    alias Instructions = Bytes
  {% else %}
    alias Instructions = Array(UInt8)
  {% end %}

  def lookup(op : Opcode) : Definition
    case op
    when Opcode::OpConstant
      return DEF_OP_CONSTANT
    when Opcode::OpAdd
      return DEF_OP_ADD
    when Opcode::OpPop
      return DEF_OP_POP
    when Opcode::OpSub
      return DEF_OP_SUB
    when Opcode::OpMul
      return DEF_OP_MUL
    when Opcode::OpDiv
      return DEF_OP_DIV
    when Opcode::OpTrue
      return DEF_OP_TRUE
    when Opcode::OpFalse
      return DEF_OP_FALSE
    when Opcode::OpEqual
      return DEF_OP_EQUAL
    when Opcode::OpNotEqual
      return DEF_OP_NOT_EQUAL
    when Opcode::OpGreaterThan
      return DEF_OP_GREATER_THAN
    when Opcode::OpMinus
      return DEF_OP_MINUS
    when Opcode::OpBang
      return DEF_OP_BANG
    when Opcode::OpJumpNotTruthy
      return DEF_OP_JUMP_NOT_TRUTHY
    when Opcode::OpJump
      return DEF_OP_JUMP
    when Opcode::OpNull
      return DEF_OP_NULL
    when Opcode::OpGetGlobal
      return DEF_OP_GET_GLOBAL
    when Opcode::OpSetGlobal
      return DEF_OP_SET_GLOBAL
    when Opcode::OpArray
      return DEF_OP_ARRAY
    when Opcode::OpHash
      return DEF_OP_HASH
    when Opcode::OpIndex
      return DEF_OP_INDEX
    when Opcode::OpCall
      return DEF_OP_CALL
    when Opcode::OpReturnValue
      return DEF_OP_RETURN_VALUE
    when Opcode::OpReturn
      return DEF_OP_RETURN
    when Opcode::OpGetLocal
      return DEF_OP_GET_LOCAL
    when Opcode::OpSetLocal
      return DEF_OP_SET_LOCAL
    when Opcode::OpGetBuiltin
      return DEF_OP_GET_BUILTIN
    when Opcode::OpClosure
      return DEF_OP_CLOSURE
    when Opcode::OpGetFree
      return DEF_OP_GET_FREE
    when Opcode::OpCurrentClosure
      return DEF_OP_CURRENT_CLOSURE
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
    {% if flag?(:slice) %}
      ins[i...(ins.size)]
    {% else %}
      OffsetArray.new(ins, i)
    {% end %}
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
    if int < 0
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
