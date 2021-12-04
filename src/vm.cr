require "./code"
require "./compiler"
require "./objects"

macro execute_build_and_push(col)
  num_elements = Code.read_int(ins, ip + 1)
  current_frame.ip += 2
  {{col}} = build_{{col}}(@sp - num_elements, @sp)
  @sp -= num_elements
  push({{col}})
end

module Vm
  extend self
  include Compilers

  class Frame
    property ip : Int32 = -1
    getter cl
    getter base_pointer

    def initialize(@cl : Objects::MClosure, @base_pointer : Int32)
    end

    def instructions : Instructions
      return @cl.fn.instructions
    end
  end

  private STACK_SIZE     = 2048
  private MAX_FRAME_SIZE = 1024

  private VM_TRUE  = MBoolean.new(true)
  private VM_FALSE = MBoolean.new(false)
  private VM_NULL  = Objects::MNULL

  class VM
    @constants = [] of MObject
    @stack = Array(MObject?).new(STACK_SIZE) { nil }
    @sp = 0
    @frames = Array(Vm::Frame?).new(MAX_FRAME_SIZE) { nil }
    @frame_index = 1
    @globals = [] of MObject

    def initialize(@bytecode : Bytecode)
      @constants = @bytecode.constants
      main_fn = Objects::MCompiledFunction.new(@bytecode.instructions)
      main_closure = Objects::MClosure.new(main_fn)
      main_frame = Frame.new(main_closure, 0)
      @frames[0] = main_frame
    end

    def run
      ip : Int32
      ins : Instructions
      op : Opcode
      while current_frame.ip < current_frame.instructions.size - 1
        current_frame.ip += 1
        ip = current_frame.ip
        ins = current_frame.instructions
        op = Opcode.new(ins[ip].to_i)
        case op
        when Opcode::OpConstant
          const_index = Code.read_int(ins, ip + 1)
          current_frame.ip += 2
          push(@constants[const_index])
        when Opcode::OpPop
          pop
        when Opcode::OpAdd, Opcode::OpSub, Opcode::OpMul, Opcode::OpDiv
          execute_binary_operation(op)
        when Opcode::OpMinus
          execute_minus_operator
        when Opcode::OpTrue
          push(VM_TRUE)
        when Opcode::OpFalse
          push(VM_FALSE)
        when Opcode::OpEqual, Opcode::OpNotEqual, Opcode::OpGreaterThan
          execute_comparison(op)
        when Opcode::OpBang
          execute_bang_operator
        when Opcode::OpJumpNotTruthy
          pos = Code.read_int(ins, ip + 1)
          current_frame.ip += 2
          condition = pop
          if !condition.is_truthy?
            current_frame.ip = pos - 1
          end
        when Opcode::OpNull
          push(VM_NULL)
        when Opcode::OpJump
          pos = Code.read_int(ins, ip + 1)
          current_frame.ip = pos - 1
        when Opcode::OpSetGlobal
          global_index = Code.read_int(ins, ip + 1)
          current_frame.ip += 2
          if global_index == @globals.size
            @globals << pop.not_nil!
          else
            @globals[global_index] = pop.not_nil!
          end
        when Opcode::OpGetGlobal
          global_index = Code.read_int(ins, ip + 1)
          current_frame.ip += 2
          push(@globals[global_index])
        when Opcode::OpArray
          execute_build_and_push array
        when Opcode::OpHash
          execute_build_and_push hash
        when Opcode::OpIndex
          index = pop
          left = pop
          execute_index_expression(left.not_nil!, index.not_nil!)
        when Opcode::OpClosure
          const_index = Code.read_int(ins, ip + 1)
          num_free = Code.read_byte(ins, ip + 3)
          current_frame.ip += 3
          push_closure(const_index, num_free.to_i)
        when Opcode::OpCall
          num_args = Code.read_byte(ins, ip + 1)
          current_frame.ip += 1
          execute_call(num_args.to_i)
        when Opcode::OpReturnValue
          return_value = pop
          frame = pop_frame
          @sp = frame.base_pointer - 1
          push(return_value.not_nil!)
        when Opcode::OpReturn
          frame = pop_frame
          @sp = frame.base_pointer - 1
          push(VM_NULL)
        when Opcode::OpSetLocal
          local_index = Code.read_byte(ins, ip + 1)
          current_frame.ip += 1
          frame = current_frame
          @stack[frame.base_pointer + local_index.to_i] = pop
        when Opcode::OpGetLocal
          local_index = Code.read_byte(ins, ip + 1)
          current_frame.ip += 1
          frame = current_frame
          push(@stack[frame.base_pointer + local_index.to_i].not_nil!)
        when Opcode::OpGetBuiltin
          built_index = Code.read_byte(ins, ip + 1)
          current_frame.ip += 1
          built = Objects::BUILTINS[built_index.to_i]
          push(built[1])
        when Opcode::OpGetFree
          free_index = Code.read_byte(ins, ip + 1)
          current_frame.ip += 1
          current_closure = current_frame.cl
          push(current_closure.free[free_index.to_i])
        when Opcode::OpCurrentClosure
          current_closure = current_frame.cl
          push(current_closure)
        else
          raise VMException.new("Unsupported op #{op}")
        end
      end
    end

    def last_popped_stack_elem? : MObject?
      return @stack[@sp]?
    end

    private def current_frame : Vm::Frame
      return @frames[@frame_index - 1].not_nil!
    end

    private def push(obj : MObject)
      if @sp > STACK_SIZE
        raise VMException.new("stack overflow")
      end
      @stack[@sp] = obj
      @sp += 1
    end

    private def pop : MObject?
      return stack_pop.also { @sp -= 1 }
    end

    private def stack_pop : MObject?
      if @sp == 0
        return nil
      else
        return @stack[@sp - 1]
      end
    end

    private def execute_binary_operation(op : Opcode)
      right = pop
      left = pop
      if left.is_a?(MInteger) && right.is_a?(MInteger)
        execute_binary_integer_operation(op, left, right)
      elsif left.is_a?(MString) && right.is_a?(MString)
        execute_binary_string_operation(op, left, right)
      else
        raise VMException.new("unsupported types for binary operation: #{left.type_desc} #{right.type_desc}")
      end
    end

    private def execute_binary_integer_operation(op : Opcode, left : MInteger, right : MInteger)
      case op
      when Opcode::OpAdd
        push(left + right)
      when Opcode::OpSub
        push(left - right)
      when Opcode::OpMul
        push(left * right)
      when Opcode::OpDiv
        push(left / right)
      else
        raise VMException.new("unkwon integer operator #{op}")
      end
    end

    private def execute_binary_string_operation(op : Opcode, left : MString, right : MString)
      if op == Opcode::OpAdd
        push(MString.new(left.value + right.value))
      else
        raise VMException.new("unkwon string operator #{op}")
      end
    end

    private def execute_minus_operator
      operand = pop
      if operand.is_a?(MInteger)
        push(MInteger.new(-operand.value))
      else
        raise VMException.new("unsupported type for negation: #{operand.type_desc}")
      end
    end

    private def execute_comparison(op : Opcode)
      right = pop
      left = pop
      if left.is_a?(MInteger) && right.is_a?(MInteger)
        execute_binary_integer_comparisson(op, left, right)
      else
        case op
        when Opcode::OpEqual
          push((left == right).to_m)
        when Opcode::OpNotEqual
          push((left != right).to_m)
        else
          raise VMException.new("unkown operator #{op} (#{left.type_desc} #{right.type_desc})")
        end
      end
    end

    private def execute_binary_integer_comparisson(op : Opcode, left : MInteger, right : MInteger)
      left_value = left.value
      right_value = right.value
      case op
      when Opcode::OpEqual
        push((left == right).to_m)
      when Opcode::OpNotEqual
        push((left != right).to_m)
      when Opcode::OpGreaterThan
        push((left > right).to_m)
      else
        raise VMException.new("unkown operator #{op}")
      end
    end

    private def execute_bang_operator
      case pop
      when VM_TRUE
        push(VM_FALSE)
      when VM_FALSE
        push(VM_TRUE)
      when VM_NULL
        push(VM_TRUE)
      else
        push(VM_FALSE)
      end
    end

    private def build_array(start_index : Int32, end_index : Int32) : MObject
      elements = Array(MObject?).new(end_index - start_index) { nil }
      i = start_index
      while i < end_index
        elements[i - start_index] = @stack[i]
        i += 1
      end
      return MArray.new(elements)
    end

    private def build_hash(start_index : Int32, end_index : Int32) : MObject
      hashed_pairs = {} of HashKey => HashPair
      (start_index...end_index).step(by: 2) do |i|
        key = @stack[i]
        value = @stack[i + 1]
        if key.nil? || key.nil?
          next
        end
        pair = HashPair.new(key, value.not_nil!)
        case key
        when MValue
          hashed_pairs[key.hash_key] = pair
        else
          raise VMException.new("unusable as hash key: #{key.type_desc}")
        end
      end
      return MHash.new(hashed_pairs)
    end

    private def execute_index_expression(left : MObject, index : MObject)
      if left.is_a?(MArray) && index.is_a?(MInteger)
        execute_array_index(left, index)
      elsif left.is_a?(MHash)
        execute_hash_index(left, index)
      else
        raise VMException.new("index operator not supported #{left.type_desc}")
      end
    end

    private def execute_array_index(array : MArray, index : MInteger)
      i = index.value
      max = array.elements.size - 1.to_i64
      if i < 0 || i > max
        push(VM_NULL)
      else
        push(array.elements[i.to_i].not_nil!)
      end
    end

    private def execute_hash_index(hash : MHash, index : MObject)
      case index
      when MValue
        pair = hash.pairs[index.hash_key]?
        if pair.nil?
          push(VM_NULL)
        else
          push(pair.value)
        end
      else
        raise VMException.new("unusable as hash key: #{index.type_desc}")
      end
    end

    private def push_closure(const_index : Int32, num_free : Int32)
      constant = @constants[const_index]
      if constant.is_a?(Objects::MCompiledFunction)
        free = Array.new(num_free) { |i| @stack[@sp - num_free - i].not_nil! }
        @sp -= num_free
        closure = Objects::MClosure.new(constant, free)
        push(closure)
      else
        raise VMException.new("not a function #{constant}")
      end
    end

    private def execute_call(num_args : Int32)
      callee = @stack[@sp - 1 - num_args]
      case callee
      when Objects::MClosure
        call_closure(callee, num_args)
      when Objects::MBuiltinFunction
        call_builtin(callee, num_args)
      else
        raise VMException.new("calling non-function or non-builtin")
      end
    end

    private def call_closure(cl : Objects::MClosure, num_args : Int32)
      if cl.fn.num_parameters != num_args
        raise VMException.new("wrong number of arguments: want=#{cl.fn.num_parameters}, got=#{num_args}")
      end
      frame = Frame.new(cl, @sp - num_args)
      push_frame(frame)
      @sp = frame.base_pointer + cl.fn.num_locals
    end

    private def call_builtin(builtin : MBuiltinFunction, num_args : Int32)
      args = @stack[(@sp - num_args)...@sp]
      result = builtin.fn.call(args)
      @sp = @sp - num_args - 1
      if !result.nil?
        push(result)
      else
        push(VM_NULL)
      end
    end

    private def push_frame(frame : Frame)
      @frames[@frame_index] = frame
      @frame_index += 1
    end

    private def pop_frame : Frame
      @frame_index -= 1
      return @frames[@frame_index].not_nil!
    end
  end

  class VMException < Exception
  end
end
