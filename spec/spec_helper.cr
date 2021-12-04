require "spec"
require "../src/monyet"
require "../src/parser"
require "../src/ast"
require "../src/lexer"
require "../src/evaluator"
require "../src/symbols"
require "../src/vm"
include Parsers
include Lexers
include Evaluator
include Symbols
include Vms

macro define_check_type(suffix, t)
  def check_type_{{suffix}}(value, &block : {{t}} -> _)
    case value
      when {{t}}
        block.call(value)
      else
        raise "Value is not #{ {{t}} }, got=#{typeof(value)}"
      end
  end
end

macro define_test_object(suffix, t, v)
  def test_object_{{suffix}}(obj : MObject?, expected : {{v}})
    case obj
      when {{t}}
        obj.value.should eq(expected)
      else
        raise "obj is not #{ {{t}} }, got=#{typeof(obj)}, #{obj}"
    end
  end
end

def parse(input : String) : Program
  lexer = Lexer.new(input)
  parser = Parser.new(lexer)
  return parser.parse_program
end

def create_program(input : String) : Program
  lexer = Lexer.new(input)
  parser = Parser.new(lexer)
  program = parser.parse_program
  check_parser_errors(parser)
  return program
end

def check_parser_errors(parser : Parser)
  errors = parser.errors
  if !errors.empty?
    raise "parser has #{errors.size} errors: \n#{errors.join("\n")}"
  end
end

def count_statements(i : Int32, program : Program)
  program.statements.size.should eq(i)
end

define_check_type lt, LetStatement
define_check_type rt, ReturnStatement
define_check_type es, ExpressionStatement
define_check_type pe, PrefixExpression
define_check_type ife, IfExpression
define_check_type fl, FunctionLiteral
define_check_type ce, CallExpression
define_check_type sl, StringLiteral
define_check_type al, ArrayLiteral
define_check_type iex, IndexExpression
define_check_type i, Identifier
define_check_type bl, BooleanLiteral
define_check_type il, IntegerLiteral
define_check_type ie, InfixExpression
define_check_type hl, HashLiteral
define_check_type error, MError
define_check_type fn, MFunction
define_check_type ar, MArray
define_check_type h, MHash

def test_let_statement(statement : Statement, expected_identifier : String)
  statement.token_literal.should eq("let")

  check_type_lt(statement) do |let_statement|
    name = let_statement.name
    name.value.should eq(expected_identifier)
    name.token_literal.should eq(expected_identifier)
  end
end

def test_literal_expression(value : Expression?, expected_value : T) forall T
  case expected_value
  when Int64
    test_long_literal(value, expected_value)
  when Int32
    test_long_literal(value, expected_value.to_i64)
  when String
    test_identifier(value, expected_value)
  when Bool
    test_boolean_literal(value, expected_value)
  else
    raise "type of value not handled. got=#{typeof(expected_value)}"
  end
end

def test_identifier(expression : Expression?, string : String)
  check_type_i(expression) do |exp|
    exp.value.should eq(string)
    exp.token_literal.should eq(string)
  end
end

macro test_literal(exp, v)
  {{exp}}.value.should eq({{v}})
  {{exp}}.token_literal.should eq({{v}}.to_s)
end

def test_boolean_literal(expression : Expression?, b : Bool)
  check_type_bl(expression) do |exp|
    test_literal(exp, b)
  end
end

def test_long_literal(expression : Expression?, l : Int64)
  check_type_il(expression) do |exp|
    test_literal(exp, l)
  end
end

def test_infix_expression(expression : Expression?, left_value, operator : String, right_value)
  check_type_ie(expression) do |infix_expression|
    test_literal_expression(infix_expression.left?, left_value)
    infix_expression.operator.should eq(operator)
    test_literal_expression(infix_expression.right?, right_value)
  end
end

def test_eval(input : String)
  program = create_program(input)
  return Evaluator.eval(program, Environment.new)
end

define_test_object il, MInteger, Int64
define_test_object bl, MBoolean, Bool
define_test_object s, MString, String

def test_nil_object(obj : MObject?)
  obj.not_nil!.should eq(NULL)
end

def test_symbol(name : String, table : Symbols::SymbolTable, expected : Hash(String, Symbols::Symbol))
  symbol = table.define(name)
  expected_symbol = expected[name]
  expected_symbol.should eq(symbol)
end

def test_symbol(table : Symbols::SymbolTable, sym : Symbols::Symbol)
  result = table.resolve(sym.name)
  result.should eq(sym)
end

def test_instructions(expected : Array(Instructions), actual : Instructions)
  concatenated = concat(expected)
  concatenated.size.should eq(actual.size)
  assert_instructions(concatenated, actual)
end

private def assert_instructions(expected : Instructions, actual : Instructions)
  expected.each_with_index do |byte, i|
    byte.should eq(actual[i])
  end
end

def concat(instructions : Array(Instructions)) : Instructions
  return instructions.sum
end

def test_compile_result(input : String, expected_constants : Array, expected_instructions : Array(Instructions))
  program = parse(input)
  compiler = MCompiler.new
  compiler.compile(program)
  bytecode = compiler.bytecode
  test_instructions(expected_instructions, bytecode.instructions)
  test_constants(expected_constants, bytecode.constants)
end

def test_constants(expected : Array, actual : Array(MObject))
  expected.size.should eq(actual.size)
  expected.each_with_index do |constant, i|
    case constant
    when Int64
      test_integer_object(constant, actual[i])
    when String
      test_string_object(constant, actual[i])
    when Array
      act = actual[i]
      case act
      when MCompiledFunction
        test_instructions(constant.as(Array(Instructions)), act.instructions)
      else
        raise "constant #{act} - not a function, got #{act.type_desc}"
      end
    end
  end
end

macro def_test_object(name, expected_type, actual_type)
def test_{{name}}_object(expected : {{expected_type}}, actual : MObject)
  case actual
  when {{actual_type}}
    expected.should eq(actual.value)
  else
    raise "object is not {{actual_type}}, got#{actual.type_desc}"
  end
end
end

def_test_object integer, Int64, MInteger
def_test_object string, String, MString
def_test_object boolean, Bool, MBoolean

def test_scope_index_size(compiler : MCompiler, scope_index : Int32)
  scope_index.should eq(compiler.scope_index)
end

def test_scope_instructions_size(compiler : MCompiler, instructions_size : Int32)
  instructions_size.should eq(compiler.current_scope.instructions.size)
end

def test_vm_result(input : String, expected)
  program = parse(input)
  compiler = MCompiler.new
  compiler.compile(program)
  vm = VM.new(compiler.bytecode)
  vm.run
  stack_elem = vm.last_popped_stack_elem?.not_nil!
  test_expected_object(expected, stack_elem)
end

def test_expected_object(expected, actual : MObject)
  case expected
  when Int64
    test_integer_object(expected, actual)
  when Bool
    test_boolean_object(expected, actual)
  when MNull
    VM_NULL.should eq(actual)
  when String
    test_string_object(expected, actual)
  when Array(Int64)
    check_type_ar(actual) do |array|
      array.elements.size.should eq(expected.size)
      expected.each_with_index do |long, i|
        test_integer_object(long, array.elements[i].not_nil!)
      end
      nil
    end
  when Hash(HashKey, Int64)
    check_type_h(actual) do |hash|
      expected.size.should eq(hash.pairs.size)
      expected.each do |expected_key, expected_value|
        pair = hash.pairs[expected_key]
        pair.should_not be_nil
        test_integer_object(expected_value, pair.value)
      end
      nil
    end
  when MError
    check_type_error(actual) do |error|
      error.message.should eq(expected.message)
      nil
    end
  else
    raise "test not implemented for #{typeof(expected)}"
  end
end
