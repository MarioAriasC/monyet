require "./spec_helper"
require "../src/parser"

include Parsers

macro test_branch(if_expression, branch_name, value)
  statements = {{if_expression}}.{{branch_name}}?.not_nil!.statements?.not_nil!
  statements.size.should eq(1)
  check_type_es(statements[0]) do |statement|
    test_identifier(statement.expression?, {{value}})
  end
end

describe "Parser" do
  it "let statements" do
    [
      {"let x = 5;", "x", 5},
      {"let y = true;", "y", true},
      {"let foobar = y;", "foobar", "y"},
    ].each do |input, expected_identifier, expected_value|
      program = create_program(input)
      count_statements(1, program)

      statement = program.statements[0]
      test_let_statement(statement, expected_identifier)

      value = statement.as(LetStatement).value?
      test_literal_expression(value, expected_value)
    end
  end

  it "return statements" do
    [
      {"return 5;", 5},
      {"return true;", true},
      {"return foobar;", "foobar"},
    ].each do |input, expected_value|
      program = create_program(input)
      count_statements(1, program)

      check_type_rt(program.statements[0]) do |return_statement|
        return_statement.token_literal.should eq("return")
        test_literal_expression(return_statement.return_value?, expected_value)
      end
    end
  end

  it "identifier expression" do
    input = "foobar"
    program = create_program(input)
    count_statements(1, program)

    check_type_es(program.statements[0]) do |expression_statement|
      check_type_i(expression_statement.expression?) do |identifier|
        identifier.value.should eq("foobar")
        identifier.token_literal.should eq("foobar")
      end
    end
  end

  it "integer literal" do
    input = "5;"
    program = create_program(input)
    count_statements(1, program)

    check_type_es(program.statements[0]) do |expression_statement|
      literal = expression_statement.expression?
      case literal
      when IntegerLiteral
        integer_literal = literal.as(IntegerLiteral)
        integer_literal.value.should eq(5)
        integer_literal.token_literal.should eq("5")
      else
        raise "expression_statement.expression? not a IntegerLiteral. got=#{typeof(literal)}"
      end
    end
  end

  it "parsing prefix expressions" do
    [
      {"!5;", "!", 5},
      {"-15;", "-", 15},
      {"!true", "!", true},
      {"!false", "!", false},
    ].each do |input, operator, value|
      program = create_program(input)
      count_statements(1, program)
      check_type_es(program.statements[0]) do |expression_statement|
        check_type_pe(expression_statement.expression?) do |prefix_expression|
          prefix_expression.operator.should eq(operator)
          test_literal_expression(prefix_expression.right?, value)
        end
      end
    end
  end

  it "parsing infix expressions", tags: "infix" do
    [
      {"5 + 5;", 5, "+", 5},
      {"5 - 5;", 5, "-", 5},
      {"5 * 5;", 5, "*", 5},
      {"5 / 5;", 5, "/", 5},
      {"5 > 5;", 5, ">", 5},
      {"5 < 5;", 5, "<", 5},
      {"5 == 5;", 5, "==", 5},
      {"5 != 5;", 5, "!=", 5},
      {"true == true", true, "==", true},
      {"true != false", true, "!=", false},
      {"false == false", false, "==", false},
    ].each do |input, left_value, operator, right_value|
      program = create_program(input)
      count_statements(1, program)
      check_type_es(program.statements[0]) do |expression_statement|
        test_infix_expression(expression_statement.expression?, left_value, operator, right_value)
      end
    end
  end

  it "operator precedence" do
    [
      {
        "-a * b",
        "((-a) * b)",
      },
      {
        "!-a",
        "(!(-a))",
      },
      {
        "a + b + c",
        "((a + b) + c)",
      },
      {
        "a + b - c",
        "((a + b) - c)",
      },
      {
        "a * b * c",
        "((a * b) * c)",
      },
      {
        "a * b / c",
        "((a * b) / c)",
      },
      {
        "a + b / c",
        "(a + (b / c))",
      },
      {
        "a + b * c + d / e - f",
        "(((a + (b * c)) + (d / e)) - f)",
      },
      {
        "3 + 4; -5 * 5",
        "(3 + 4)((-5) * 5)",
      },
      {
        "5 > 4 == 3 < 4",
        "((5 > 4) == (3 < 4))",
      },
      {
        "5 < 4 != 3 > 4",
        "((5 < 4) != (3 > 4))",
      },
      {
        "3 + 4 * 5 == 3 * 1 + 4 * 5",
        "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))",
      },
      {
        "true",
        "true",
      },
      {
        "false",
        "false",
      },
      {
        "3 > 5 == false",
        "((3 > 5) == false)",
      },
      {
        "3 < 5 == true",
        "((3 < 5) == true)",
      },
      {
        "1 + (2 + 3) + 4",
        "((1 + (2 + 3)) + 4)",
      },
      {
        "(5 + 5) * 2",
        "((5 + 5) * 2)",
      },
      {
        "2 / (5 + 5)",
        "(2 / (5 + 5))",
      },
      {
        "(5 + 5) * 2 * (5 + 5)",
        "(((5 + 5) * 2) * (5 + 5))",
      },
      {
        "-(5 + 5)",
        "(-(5 + 5))",
      },
      {
        "!(true == true)",
        "(!(true == true))",
      },
      {
        "a + add(b * c) + d",
        "((a + add((b * c))) + d)",
      },
      {
        "add(a, b, 1, 2 * 3, 4 + 5, add(6, 7 * 8))",
        "add(a, b, 1, (2 * 3), (4 + 5), add(6, (7 * 8)))",
      },
      {
        "add(a + b + c * d / f + g)",
        "add((((a + b) + ((c * d) / f)) + g))",
      },
      {
        "a * [1, 2, 3, 4][b * c] * d",
        "((a * ([1, 2, 3, 4][(b * c)])) * d)",
      },
      {
        "add(a * b[2], b[1], 2 * [1, 2][1])",
        "add((a * (b[2])), (b[1]), (2 * ([1, 2][1])))",
      },
    ].each do |input, expected|
      program = create_program(input)
      actual = program.to_s
      actual.should eq(expected)
    end
  end

  it "boolean expression" do
    [
      {"true", true},
      {"false", false},
    ].each do |input, expected_boolean|
      program = create_program(input)
      count_statements(1, program)
      check_type_es(program.statements[0]) do |expression_statement|
        check_type_bl(expression_statement.expression?) do |bool_literal|
          bool_literal.value.should eq(expected_boolean)
        end
      end
    end
  end

  it "if expression" do
    input = "if (x < y) { x }"
    program = create_program(input)
    count_statements(1, program)
    check_type_es(program.statements[0]) do |expression_statement|
      check_type_ife(expression_statement.expression?) do |if_expression|
        test_infix_expression(if_expression.condition?, "x", "<", "y")
        test_branch if_expression, consequence, "x"
        if_expression.alternative?.should eq(nil)
      end
    end
  end

  it "if else expression" do
    input = "if (x < y) { x } else { y }"
    program = create_program(input)
    count_statements(1, program)
    check_type_es(program.statements[0]) do |expression_statement|
      check_type_ife(expression_statement.expression?) do |if_expression|
        test_infix_expression(if_expression.condition?, "x", "<", "y")
        test_branch if_expression, consequence, "x"
        test_branch if_expression, alternative, "y"
      end
    end
  end

  it "function literal parsing" do
    input = "fn(x, y) { x + y;}"
    program = create_program(input)
    check_type_es(program.statements[0]) do |expression_statement|
      check_type_fl(expression_statement.expression?) do |function_literal|
        parameters = function_literal.parameters?.not_nil!
        test_literal_expression(parameters[0], "x")
        test_literal_expression(parameters[1], "y")
        body = function_literal.body?.not_nil!

        statements = body.statements?.not_nil!
        statements.size.should eq(1)
        check_type_es(statements[0]) do |statement|
          test_infix_expression(statement.expression?, "x", "+", "y")
        end
      end
    end
  end

  it "function parameter parsing" do
    [
      {"fn () {}", [] of String},
      {"fn (x) {}", ["x"]},
      {"fn (x, y, z) {}", ["x", "y", "z"]},
    ].each do |input, expected_params|
      program = create_program(input)
      check_type_es(program.statements[0]) do |expression_statement|
        check_type_fl(expression_statement.expression?) do |function_literal|
          parameters = function_literal.parameters?.not_nil!
          parameters.size.should eq(expected_params.size)
          expected_params.each_with_index do |expected_param, i|
            test_literal_expression(parameters[i], expected_param)
          end
        end
      end
    end
  end

  it "call expression parsing" do
    input = "add(1, 2 * 3, 4+5)"
    program = create_program(input)
    count_statements(1, program)
    check_type_es(program.statements[0]) do |expression_statement|
      check_type_ce(expression_statement.expression?) do |call_expression|
        test_identifier(call_expression.function?, "add")
        arguments = call_expression.arguments?.not_nil!

        test_literal_expression(arguments[0], 1)
        test_infix_expression(arguments[1], 2, "*", 3)
        test_infix_expression(arguments[2], 4, "+", 5)
      end
    end
  end

  it "string literal expression" do
    input = "\"hello world\";"
    program = create_program(input)
    count_statements(1, program)
    check_type_es(program.statements[0]) do |expression_statement|
      check_type_sl(expression_statement.expression?) do |string_literal|
        string_literal.value.should eq("hello world")
      end
    end
  end

  it "parsing literal array" do
    input = "[1, 2 * 2, 3 + 3]"
    program = create_program(input)
    check_type_es(program.statements[0]) do |expression_statement|
      check_type_al(expression_statement.expression?) do |array_literal|
        elements = array_literal.elements?.not_nil!
        test_long_literal(elements[0], 1)
        test_infix_expression(elements[1], 2, "*", 2)
        test_infix_expression(elements[2], 3, "+", 3)
      end
    end
  end

  it "parsing index expression" do
    input = "myArray[1 + 1]"
    program = create_program(input)
    check_type_es(program.statements[0]) do |expression_statement|
      check_type_iex(expression_statement.expression?) do |index_expression|
        test_identifier(index_expression.left?, "myArray")
        test_infix_expression(index_expression.index?, 1, "+", 1)
      end
    end
  end

  it "hash literal string keys" do
    input = "{\"one\": 1, \"two\": 2, \"three\": 3}"
    program = create_program(input)
    check_type_es(program.statements[0]) do |expression_statement|
      check_type_hl(expression_statement.expression?) do |hash_literal|
        hash_literal.pairs.size.should eq(3)
        expected = {"one" => 1, "two" => 2, "three" => 3}
        hash_literal.pairs.each do |key, value|
          check_type_sl(key) do |key_literal|
            expected_value = expected[key_literal.to_s]
            test_literal_expression(value, expected_value)
          end
        end
      end
    end
  end

  it "function literal witn name" do
    input = "let myFunction = fn() {};"
    program = create_program(input)
    check_type_lt(program.statements[0]) do |let_statement|
      check_type_fl(let_statement.value?) do |function_literal|
        function_literal.name.should eq("myFunction")
      end
    end
  end
end
