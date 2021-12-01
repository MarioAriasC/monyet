require "spec"
require "../src/monyet"
require "../src/parser"
require "../src/ast"
require "../src/lexer"
require "../src/evaluator"
include Parsers
include Lexers
include Evaluator

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
