require "./objects"
require "./code"
require "./symbols"
require "./ast"

macro emit_end
  pos = add_instruction(ins)
  set_last_instruction(op, pos)
  return pos
end

module Compilers
  extend self

  # include Objects
  include Symbols
  include Code
  include Ast

  struct EmittedInstruction
    property op
    getter position

    def initialize(@op : Opcode = Opcode::OpConstant, @position : Int32 = 0)
    end
  end

  class CompilationScope
    property instructions
    property last_instruction
    property previous_instruction

    def initialize(@instructions : Instructions = [] of UInt8, @last_instruction = EmittedInstruction.new, @previous_instruction = EmittedInstruction.new)
    end
  end

  struct MCompiler
    property symbol_table
    @scopes = [CompilationScope.new]
    getter scope_index : Int32 = 0

    def initialize(@constants = [] of MObject, @symbol_table = SymbolTable.new)
      Objects::BUILTINS.each_with_index do |t, i|
        @symbol_table.define_builtin(i, t[0]) # name
      end
    end

    def compile(node : Node)
      case node
      when Program
        node.statements.each { |statement| compile(statement) }
      when ExpressionStatement
        compile(node.expression?.not_nil!)
        emit(Opcode::OpPop)
      when InfixExpression
        if node.operator == "<"
          compile(node.right?.not_nil!)
          compile(node.left?.not_nil!)
          emit(Opcode::OpGreaterThan)
          return
        end
        compile(node.left?.not_nil!)
        compile(node.right?.not_nil!)
        case node.operator
        when "+"
          emit(Opcode::OpAdd)
        when "-"
          emit(Opcode::OpSub)
        when "*"
          emit(Opcode::OpMul)
        when "/"
          emit(Opcode::OpDiv)
        when ">"
          emit(Opcode::OpGreaterThan)
        when "=="
          emit(Opcode::OpEqual)
        when "!="
          emit(Opcode::OpNotEqual)
        else
          raise MCompilerException.new("unknown operator #{node.operator}")
        end
      when IntegerLiteral
        emit(Opcode::OpConstant, add_constant(MInteger.new(node.value)))
      when PrefixExpression
        compile(node.right?.not_nil!)
        case node.operator
        when "!"
          emit(Opcode::OpBang)
        when "-"
          emit(Opcode::OpMinus)
        else
          raise MCompilerException.new("unknown operator #{node.operator}")
        end
      when BooleanLiteral
        if node.value
          emit(Opcode::OpTrue)
        else
          emit(Opcode::OpFalse)
        end
      when IfExpression
        compile(node.condition?.not_nil!)
        jump_not_truthy_pos = emit(Opcode::OpJumpNotTruthy, 9999)
        compile(node.consequence?.not_nil!)
        if is_last_instruction_pop?
          remove_last_pop
        end
        jump_pos = emit(Opcode::OpJump, 9999)
        after_consequence_pos = current_instructions.size
        change_operand(jump_not_truthy_pos, after_consequence_pos)
        if node.alternative?.nil?
          emit(Opcode::OpNull)
        else
          compile(node.alternative?.not_nil!)
          if is_last_instruction_pop?
            remove_last_pop
          end
        end
        after_alternative_pos = current_instructions.size
        change_operand(jump_pos, after_alternative_pos)
      when BlockStatement
        node.statements?.not_nil!.each do |statement|
          compile(statement.not_nil!)
        end
      when LetStatement
        symbol = @symbol_table.define(node.name.value)
        compile(node.value?.not_nil!)
        if symbol.scope == SymbolScope::Global
          emit(Opcode::OpSetGlobal, symbol.index)
        else
          emit(Opcode::OpSetLocal, symbol.index)
        end
      when Identifier
        symbol = @symbol_table.resolve(node.value)
        load_symbol(symbol)
      when StringLiteral
        emit(Opcode::OpConstant, add_constant(MString.new(node.value)))
      when ArrayLiteral
        node.elements?.not_nil!.each { |element| compile(element.not_nil!) }
        emit(Opcode::OpArray, node.elements?.not_nil!.size)
      when HashLiteral
        keys = node.pairs.keys.sort!
        keys.each do |key|
          compile(key)
          compile(node.pairs[key])
        end
        emit(Opcode::OpHash, node.pairs.size * 2)
      when IndexExpression
        compile(node.left?.not_nil!)
        compile(node.index?.not_nil!)
        emit(Opcode::OpIndex)
      when FunctionLiteral
        enter_scope
        if (!node.name.empty?)
          @symbol_table.define_function_name(node.name)
        end
        parameters = node.parameters?
        if !parameters.nil?
          parameters.each { |parameter| @symbol_table.define(parameter.value) }
        end
        compile(node.body?.not_nil!)
        if is_last_instruction_pop?
          replace_last_pop_with_return
        end
        if !last_instruction_is?(Opcode::OpReturnValue)
          emit(Opcode::OpReturn)
        end
        free_symbols = @symbol_table.free_symbols
        num_locals = @symbol_table.num_definitions
        instructions = leave_scope
        free_symbols.each { |s| load_symbol(s) }

        compiled_fn = Objects::MCompiledFunction.new(instructions: instructions, num_locals: num_locals, num_parameters: node.parameters?.not_nil!.size)
        emit(Opcode::OpClosure, add_constant(compiled_fn), free_symbols.size)
      when ReturnStatement
        compile(node.return_value?.not_nil!)
        emit(Opcode::OpReturnValue)
      when CallExpression
        compile(node.function?.not_nil!)
        arguments = node.arguments?.not_nil!
        arguments.each { |arg| compile(arg.not_nil!) }
        emit(Opcode::OpCall, arguments.size)
      else
        raise MCompilerException.new("cannot process node of value :#{node} and type #{typeof(node)}")
      end
    end

    def bytecode : Bytecode
      return Bytecode.new(current_instructions, @constants)
    end

    def current_scope : CompilationScope
      return @scopes[@scope_index]
    end

    private def current_instructions : Instructions
      return current_scope.instructions
    end

    def emit(op : Opcode) : Int32
      ins = Code.make(op)
      emit_end
    end

    def emit(op : Opcode, *operands : Int32) : Int32
      ins = Code.make(op, *operands)
      emit_end
    end

    def enter_scope
      @scopes << CompilationScope.new
      @symbol_table = SymbolTable.new(outer: @symbol_table)
      @scope_index += 1
    end

    def leave_scope
      instructions = current_instructions
      @scopes.pop
      @scope_index -= 1
      @symbol_table = @symbol_table.outer.not_nil!
      return instructions
    end

    private def replace_last_pop_with_return
      last_pos = current_scope.last_instruction.position
      replace_instruction(last_pos, Code.make(Opcode::OpReturnValue))
      current_scope.last_instruction.op = Opcode::OpReturnValue
    end

    private def add_instruction(ins : Instructions) : Int32
      pos = current_instructions.size
      current_scope
      current_scope.instructions += ins
      return pos
    end

    private def remove_last_pop
      last = current_scope.last_instruction
      previous = current_scope.previous_instruction
      old = current_instructions
      new = Code.onset(old, last.position)
      current_scope.instructions = new
      current_scope.last_instruction = previous
    end

    private def set_last_instruction(op : Opcode, position : Int32)
      previous = current_scope.last_instruction
      last = EmittedInstruction.new(op, position)
      current_scope.previous_instruction = previous
      current_scope.last_instruction = last
    end

    private def add_constant(obj : MObject) : Int
      @constants << obj
      return @constants.size - 1
    end

    private def is_last_instruction_pop? : Bool
      return last_instruction_is?(Opcode::OpPop)
    end

    private def last_instruction_is?(op : Opcode) : Bool
      return current_scope.last_instruction.op == op
    end

    private def change_operand(op_pos : Int32, operand : Int32)
      op = current_instructions[op_pos]
      new = Code.make(Opcode.new(op.to_i), operand)
      replace_instruction(op_pos, new)
    end

    private def replace_instruction(pos : Int32, new : Instructions)
      new.each_index do |i|
        current_instructions[pos + i] = new[i]
      end
    end

    private def load_symbol(symbol : Symbols::Symbol)
      opcode = Opcode::OpNull
      case symbol.scope
      when Symbols::SymbolScope::Global
        opcode = Opcode::OpGetGlobal
      when Symbols::SymbolScope::Local
        opcode = Opcode::OpGetLocal
      when Symbols::SymbolScope::Builtin
        opcode = Opcode::OpGetBuiltin
      when Symbols::SymbolScope::Free
        opcode = Opcode::OpGetFree
      when Symbols::SymbolScope::Function
        opcode = Opcode::OpCurrentClosure
      end
      if opcode != Opcode::OpCurrentClosure
        emit(opcode, symbol.index)
      else
        emit(opcode)
      end
    end
  end

  struct Bytecode
    getter instructions
    getter constants

    def initialize(@instructions : Instructions, @constants : Array(MObject))
    end
  end

  class MCompilerException < Exception
  end
end
