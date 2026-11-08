macro ret_ins(ex)
  puts typeof(ex)
  puts ex.message
  return [] of UInt8
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

  alias Instructions = Array(UInt8)

  def lookup(op : Opcode) : Definition
    case op
    when Opcode::OpConstant
      DEF_OP_CONSTANT
    when Opcode::OpAdd
      DEF_OP_ADD
    when Opcode::OpPop
      DEF_OP_POP
    when Opcode::OpSub
      DEF_OP_SUB
    when Opcode::OpMul
      DEF_OP_MUL
    when Opcode::OpDiv
      DEF_OP_DIV
    when Opcode::OpTrue
      DEF_OP_TRUE
    when Opcode::OpFalse
      DEF_OP_FALSE
    when Opcode::OpEqual
      DEF_OP_EQUAL
    when Opcode::OpNotEqual
      DEF_OP_NOT_EQUAL
    when Opcode::OpGreaterThan
      DEF_OP_GREATER_THAN
    when Opcode::OpMinus
      DEF_OP_MINUS
    when Opcode::OpBang
      DEF_OP_BANG
    when Opcode::OpJumpNotTruthy
      DEF_OP_JUMP_NOT_TRUTHY
    when Opcode::OpJump
      DEF_OP_JUMP
    when Opcode::OpNull
      DEF_OP_NULL
    when Opcode::OpGetGlobal
      DEF_OP_GET_GLOBAL
    when Opcode::OpSetGlobal
      DEF_OP_SET_GLOBAL
    when Opcode::OpArray
      DEF_OP_ARRAY
    when Opcode::OpHash
      DEF_OP_HASH
    when Opcode::OpIndex
      DEF_OP_INDEX
    when Opcode::OpCall
      DEF_OP_CALL
    when Opcode::OpReturnValue
      DEF_OP_RETURN_VALUE
    when Opcode::OpReturn
      DEF_OP_RETURN
    when Opcode::OpGetLocal
      DEF_OP_GET_LOCAL
    when Opcode::OpSetLocal
      DEF_OP_SET_LOCAL
    when Opcode::OpGetBuiltin
      DEF_OP_GET_BUILTIN
    when Opcode::OpClosure
      DEF_OP_CLOSURE
    when Opcode::OpGetFree
      DEF_OP_GET_FREE
    when Opcode::OpCurrentClosure
      DEF_OP_CURRENT_CLOSURE
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
    instruction
  rescue ex
    ret_ins(ex)
  end

  def make(op : Opcode) : Instructions
    lookup(op)
    [op.to_u8]
  rescue ex
    ret_ins(ex)
  end

  def onset(ins : Instructions, i : Int32) : Instructions
    ins[0..(i - 1)]
  end

  private def offset(ins : Instructions, i : Int32) : OffsetArray
    OffsetArray.new(ins, i)
  end

  def read_int(ins : Instructions, i : Int32) : Int32
    read_u16(offset(ins, i)).to_i
  end

  private def read_u16(ins : OffsetArray) : UInt16
    ch1 = read(ins, 0)
    ch2 = read(ins, 1)
    if (ch1 | ch2) < 0
      raise ""
    else
      ((ch1 << 8) + (ch2 << 0)).to_u16
    end
  end

  private def read(ins : OffsetArray, position : Int32) : Int32
    (ins[position] & 255.to_u).to_i
  end

  def read_byte(ins : Instructions, i : Int32) : UInt8
    read_u8(offset(ins, i))
  end

  private def read_u8(ins : OffsetArray) : UInt8
    int = read(ins, 0)
    if int < 0
      raise "error reading byte"
    else
      int.to_u8
    end
  end

  struct OffsetArray
    def initialize(@inner : Instructions, @offset : Int32)
    end

    def [](i : Int32) : UInt8
      @inner[i + @offset]
    end
  end
end

class String
  def to_definition(*operands_with : Int32) : Code::Definition
    Code::Definition.new(self, operands_with.to_a)
  end

  def to_definition : Code::Definition
    Code::Definition.new(self, [] of Int32)
  end
end
