require "./spec_helper"
require "../src/evaluator"

include Evaluator

macro test_integer
  evaluated = test_eval(input)
  Tests(MInteger, Int64).new.test_object_value(evaluated, expected.to_i64)
end

macro test_boolean
  evaluated = test_eval(input)
  Tests(MBoolean, Bool).new.test_object_value(evaluated, expected)
end

describe "Evaluator" do
  it "eval integer expression" do
    [
      {"5", 5},
      {"10", 10},
      {"-5", -5},
      {"-10", -10},
      {"5 + 5 + 5 + 5 - 10", 10},
      {"2 * 2 * 2 * 2 * 2", 32},
      {"-50 + 100 + -50", 0},
      {"5 * 2 + 10", 20},
      {"5 + 2 * 10", 25},
      {"20 + 2 * -10", 0},
      {"50 / 2 * 2 + 10", 60},
      {"2 * (5 + 10)", 30},
      {"3 * 3 * 3 + 10", 37},
      {"3 * (3 * 3) + 10", 37},
      {"(5 + 10 * 2 + 15 / 3) * 2 + -10", 50},
    ].each do |input, expected|
      test_integer
    end
  end

  it "eval boolean expression" do
    [
      {"true", true},
      {"false", false},
      {"1 < 2", true},
      {"1 > 2", false},
      {"1 < 1", false},
      {"1 > 1", false},
      {"1 == 1", true},
      {"1 != 1", false},
      {"1 == 2", false},
      {"1 != 2", true},
      {"true == true", true},
      {"false == false", true},
      {"true == false", false},
      {"true != false", true},
      {"false != true", true},
      {"(1 < 2) == true", true},
      {"(1 < 2) == false", false},
      {"(1 > 2) == true", false},
      {"(1 > 2) == false", true},
    ].each do |input, expected|
      test_boolean
    end
  end

  it "bang operator" do
    [
      {"!true", false},
      {"!false", true},
      {"!5", false},
      {"!!true", true},
      {"!!false", false},
      {"!!5", true},
    ].each do |input, expected|
      test_boolean
    end
  end

  it "if else expression" do
    [
      {"if (true) { 10 }", 10},
      {"if (false) { 10 }", nil},
      {"if (1) { 10 }", 10},
      {"if (1 < 2) { 10 }", 10},
      {"if (1 > 2) { 10 }", nil},
      {"if (1 > 2) { 10 } else { 20 }", 20},
      {"if (1 < 2) { 10 } else { 20 }", 10},
    ].each do |input, expected|
      evaluated = test_eval(input)
      if !expected.nil?
        Tests(MInteger, Int64).new.test_object_value(evaluated, expected.to_i64)
      else
        test_nil_object(evaluated)
      end
    end
  end

  it "return statement" do
    [
      {"return 10;", 10},
      {"return 10; 9;", 10},
      {"return 2 * 5; 9;", 10},
      {"9; return 2 * 5; 9;", 10},
      {"if (10 > 1) {
          if (10 > 1) {
            return 10;
          }

          return 1;
          }", 10},
      {"let f = fn(x) {
                return x;
                x + 10;
              };
              f(10);", 10},
      {"let f = fn(x) {
                 let result = x + 10;
                 return result;
                 return 10;
              };
              f(10);", 20},
    ].each do |input, expected|
      test_integer
    end
  end

  it "error handling" do
    [
      {"5 + true;", "type mismatch: Objects::MInteger + Objects::MBoolean"},
      {"5 + true; 5;", "type mismatch: Objects::MInteger + Objects::MBoolean"},
      {"-true", "unknown operator: -Objects::MBoolean"},
      {"true + false;", "unknown operator: Objects::MBoolean + Objects::MBoolean"},
      {
        "true + false + true + false;",
        "unknown operator: Objects::MBoolean + Objects::MBoolean",
      },
      {
        "5; true + false; 5",
        "unknown operator: Objects::MBoolean + Objects::MBoolean",
      },
      {
        "if (10 > 1) { true + false; }",
        "unknown operator: Objects::MBoolean + Objects::MBoolean",
      },
      {
        "
            if (10 > 1) {
              if (10 > 1) {
                return true + false;
              }

              return 1;
            }
            ",
        "unknown operator: Objects::MBoolean + Objects::MBoolean",
      },
      {
        "foobar",
        "identifier not found: foobar",
      },
      {
        %("Hello" - "World"),
        "unknown operator: Objects::MString - Objects::MString",
      },
      {
        %({"name": "Monkey"}[fn(x) {x}];),
        "unusable as a hash key: Objects::MFunction",
      },
    ].each do |input, expected|
      evaluated = test_eval(input)
      Checks(MError).new.check_type(evaluated) do |error|
        error.message.should eq(expected)
      end
    end
  end

  it "let statement" do
    [
      {"let a = 5; a;", 5},
      {"let a = 5 * 5; a;", 25},
      {"let a = 5; let b = a; b;", 5},
      {"let a = 5; let b = a; let c = a + b + 5; c;", 15},
    ].each do |input, expected|
      test_integer
    end
  end

  it "function object" do
    input = "fn(x) { x + 2; };"
    evaluated = test_eval(input)
    Checks(MFunction).new.check_type(evaluated) do |fn|
      parameters = fn.parameters?.not_nil!
      parameters.size.should eq(1)
      parameters[0].to_s.should eq("x")
      fn.body?.not_nil!.to_s.should eq("(x + 2)")
    end
  end

  it "funciton application" do
    [
      {"let identity = fn(x) { x; }; identity(5);", 5},
      {"let identity = fn(x) { return x; }; identity(5);", 5},
      {"let double = fn(x) { x * 2; }; double(5);", 10},
      {"let add = fn(x, y) { x + y; }; add(5, 5);", 10},
      {"let add = fn(x, y) { x + y; }; add(5 + 5, add(5, 5));", 20},
      {"fn(x) { x; }(5)", 5},
    ].each do |input, expected|
      test_integer
    end
  end

  it "enclosing environments" do
    input = "let first = 10;
          let second = 10;
          let third = 10;

          let ourFunction = fn(first) {
            let second = 20;

            first + second + third;
          };

          ourFunction(20) + first + second;"
    Tests(MInteger, Int64).new.test_object_value(test_eval(input), 70.to_i64)
  end

  it "string literal" do
    Tests(MString, String).new.test_object_value(test_eval(%("Hello World!")), "Hello World!")
  end

  it "string concatenation" do
    Tests(MString, String).new.test_object_value(test_eval(%("Hello" + " " + "World!")), "Hello World!")
  end

  it "builtin functions" do
    [
      { %(len("")), 0 },
      { %(len("four")), 4 },
      { %(len("hello world")), 11 },
      {"len(1)", "argument to `len` not supported, got Objects::MInteger"},
      { %(len("one", "two")), "wrong number of arguments. got=2, want=1" },
      {"len([1, 2, 3])", 3},
      {"len([])", 0},
      {"push([], 1)", [1]},
      {"push(1, 1)", "argument to `push` must be ARRAY, got Objects::MInteger"},
      {"first([1, 2, 3])", 1},
      {"first([])", nil},
      {"first(1)", "argument to `first` must be ARRAY, got Objects::MInteger"},
      {"last([1, 2, 3])", 3},
      {"last([])", nil},
      {"last(1)", "argument to `last` must be ARRAY, got Objects::MInteger"},
      {"rest([1, 2, 3])", [2, 3]},
      {"rest([])", nil},
    ].each do |input, expected|
      evaluated = test_eval(input)
      case expected
      when Nil
        test_nil_object(evaluated)
      when Int32
        Tests(MInteger, Int64).new.test_object_value(evaluated, expected.to_i64)
      when String
        Checks(MError).new.check_type(evaluated) do |error|
          error.message.should eq(expected)
        end
      when Array(Int32)
        Checks(MArray).new.check_type(evaluated) do |array|
          expected.size.should eq(array.elements.size)
          expected.each_with_index do |element, i|
            Tests(MInteger, Int64).new.test_object_value(array.elements[i], element.to_i64)
          end
        end
      end
    end
  end

  it "array literal" do
    evaluated = test_eval("[1, 2 * 2, 3 + 3]")
    result = evaluated.as(MArray)
    result.elements.size.should eq(3)
    [1, 4, 6].each_with_index do |v, i|
      Tests(MInteger, Int64).new.test_object_value(result.elements[i], v.to_i64)
    end
  end

  it "array index expression" do
    [
      {
        "[1, 2, 3][0]",
        1,
      },
      {
        "[1, 2, 3][1]",
        2,
      },
      {
        "[1, 2, 3][2]",
        3,
      },
      {
        "let i = 0; [1][i];",
        1,
      },
      {
        "[1, 2, 3][1 + 1];",
        3,
      },
      {
        "let myArray = [1, 2, 3]; myArray[2];",
        3,
      },
      {
        "let myArray = [1, 2, 3]; myArray[0] + myArray[1] + myArray[2];",
        6,
      },
      {
        "let myArray = [1, 2, 3]; let i = myArray[0]; myArray[i]",
        2,
      },
      {
        "[1, 2, 3][3]",
        nil,
      },
      {
        "[1, 2, 3][-1]",
        nil,
      },
    ].each do |input, expected|
      evaluated = test_eval(input)
      case expected
      when Int32
        Tests(MInteger, Int64).new.test_object_value(evaluated, expected.to_i64)
      else
        test_nil_object(evaluated)
      end
    end
  end

  it "hash literals" do
    input = %(
      let two = "two";
      	{
      		"one": 10 - 9,
      		two: 1 + 1,
      		"thr" + "ee": 6 / 2,
      		4: 4,
      		true: 5,
      		false: 6
      	})
    evaluated = test_eval(input)
    Checks(MHash).new.check_type(evaluated) do |result|
      expected = {
        MString.new("one").hash_key   => 1,
        MString.new("two").hash_key   => 2,
        MString.new("three").hash_key => 3,
        MInteger.new(4).hash_key      => 4,
        MTRUE.hash_key                => 5,
        MFALSE.hash_key               => 6,
      }
      expected.size.should eq(result.pairs.size)
      expected.each do |expected_key, expected_value|
        pair = result.pairs[expected_key]?
        pair.should_not be_nil
        Tests(MInteger, Int64).new.test_object_value(pair.not_nil!.value, expected_value.to_i64)
      end
    end
  end

  it "hash index expressions" do
    [
      { %({"foo": 5}["foo"]), 5 },
      { %({"foo": 5}["bar"]), nil },
      { %(let key = "foo";{"foo": 5}[key]), 5 },
      { %({}["foo"]), nil },
      {"{5:5}[5]", 5},
      {"{true:5}[true]", 5},
      {"{false:5}[false]", 5},
    ].each do |input, expected|
      evaluated = test_eval(input)
      case expected
      when Int32
        Tests(MInteger, Int64).new.test_object_value(evaluated, expected.to_i64)
      else
        test_nil_object(evaluated)
      end
    end
  end
end
