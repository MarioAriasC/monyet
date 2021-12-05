require "./spec_helper"

describe "VM" do
  it "integer arithmetic" do
    [
      {"1", 1},
      {"2", 2},
      {"1 + 2", 3},
      {"1 - 2", -1},
      {"1 * 2", 2},
      {"4 / 2", 2},
      {"50 / 2 * 2 + 10 - 5", 55},
      {"5 + 5 + 5 + 5 - 10", 10},
      {"2 * 2 * 2 * 2 * 2", 32},
      {"5 * 2 + 10", 20},
      {"5 + 2 * 10", 25},
      {"5 * (2 + 10)", 60},
      {"-5", -5},
      {"-10", -10},
      {"-50 + 100 + - 50", 0},
      {"(5 + 10 * 2 + 15  / 3) * 2 + - 10", 50},
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "boolean expression" do
    [
      {"true", true},
      {"false", false},
      {"1 < 2", true},
      {"1 > 2", false},
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
      {"!true", false},
      {"!false", true},
      {"!5", false},
      {"!!true", true},
      {"!!false", false},
      {"!!5", true},
      {"!(if (false) { 5; })", true},
    ].each do |input, expected|
      test_vm_result(input, expected)
    end
  end

  it "conditionals" do
    [
      {"if (true) {10}", 10},
      {"if (true) {10} else {20}", 10},
      {"if (false) {10} else {20}", 20},
      {"if (1) {10}", 10},
      {"if (1 < 2) {10}", 10},
      {"if (1 < 2) {10} else {20}", 10},
      {"if (1 > 2) {10} else {20}", 20},
      {"if (1 > 2) {10}", VM_NULL},
      {"if (false) {10}", VM_NULL},
      {"if ((if (false) {10})) {10} else {20}", 20},
    ].each do |input, expected|
      if expected.is_a?(Int32)
        expected = expected.to_i64
      end
      test_vm_result(input, expected)
    end
  end

  it "global let statements" do
    [
      {"let one = 1; one;", 1},
      {"let one = 1; let two = 2; one + two", 3},
      {"let one = 1; let two = one + one; one + two", 3},
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "string expression" do
    [
      { %("monkey"), "monkey" },
      { %("mon" + "key"), "monkey" },
      { %("mon" + "key" + "banana"), "monkeybanana" },
    ].each do |input, expected|
      test_vm_result(input, expected)
    end
  end

  it "array literals" do
    [
      {"[]", [] of Int32},
      {"[1, 2, 3]", [1, 2, 3]},
      {"[1 + 2, 3 * 4, 5 + 6]", [3, 12, 11]},
    ].each do |input, expected|
      test_vm_result(input, expected.map(&.to_i64))
    end
  end

  it "hash literal" do
    [
      {"{}", {} of HashKey => Int64},
      {"{1: 2, 2: 3}", {
        MInteger.new(1).hash_key => 2.to_i64,
        MInteger.new(2).hash_key => 3.to_i64,
      }},
      {"{1 + 1: 2 * 2, 3 + 3: 4 * 4}", {
        MInteger.new(2).hash_key => 4.to_i64,
        MInteger.new(6).hash_key => 16.to_i64,
      }},
    ].each do |input, expected|
      test_vm_result(input, expected)
    end
  end

  it "index expression" do
    [
      {"[1, 2, 3][1]", 2},
      {"[1, 2, 3][0 + 2]", 3},
      {"[[1, 1, 1]][0][0]", 1},
      {"[][0]", VM_NULL},
      {"[1, 2, 3][99]", VM_NULL},
      {"[1][-1]", VM_NULL},
      {"{1: 1, 2: 2}[1]", 1},
      {"{1: 1, 2: 2}[2]", 2},
      {"{1: 1}[0]", VM_NULL},
      {"{}[0]", VM_NULL},
    ].each do |input, expected|
      if expected.is_a?(Int32)
        expected = expected.to_i64
      end
      test_vm_result(input, expected)
    end
  end

  it "calling functions without arguments" do
    [
      {"let fivePlusTen = fn() {5 + 10; };
         fivePlusTen()", 15},
      {"
         let one = fn() { 1; }
         let two = fn() { 2; }
         one() + two()
         ", 3},
      {"let a = fn() { 1 };
        let b = fn () { a() + 1 };
        let c = fn () { b() + 1 };
        c();
        ", 3},
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "functions with return statement" do
    [
      {"let earlyExit = fn() { return 99; 100; };
      earlyExit();", 99},
      {"let earlyExit = fn() { return 99; return 100; };
      earlyExit();", 99},
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "functions without return value" do
    [
      {"let noReturn = fn() {};
      noReturn();", VM_NULL},
      {"let noReturn = fn() {};
      let noReturnTwo = fn() { noReturn(); };
      noReturn();
      noReturnTwo();", VM_NULL},
    ].each do |input, expected|
      test_vm_result(input, expected)
    end
  end

  it "first class functions" do
    [
      {"let returnsOne = fn(){ 1;};
      let returnsOneReturner = fn() {returnsOne;}
      returnsOneReturner()();", 1},
      {"let returnsOneReturner = fn() {
      	let returnsOne = fn() {
      		1;
      	};
      	returnsOne;
      }
      returnsOneReturner()();", 1},
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "calling functions with bindings" do
    [
      {"let one = fn() { let one = 1; one;};
      one();", 1},
      {"let oneAndTwo = fn() {
      	let one = 1;
      	let two = 2;
      	one + two;
      };
      oneAndTwo();", 3},
      {"let oneAndTwo = fn() {
            	let one = 1;
            	let two = 2;
            	one + two;
            };
            let threeAndFour = fn() {
            	let three = 3;
            	let four = 4;
            	three + four;
            };
            oneAndTwo() + threeAndFour();", 10},
      {"let firstFoobar = fn() {
            	let foobar = 50;
            	foobar;
            };

            let secondFoobar = fn() {
            	let foobar = 100;
            	foobar;
            };
            firstFoobar() + secondFoobar();", 150},
      {"let globalSeed = 50;
            let minusOne = fn() {
            	let num = 1;
            	globalSeed - num;
            };
            let minusTwo = fn() {
            	let num = 2;
            	globalSeed - num;
            };
            minusOne() + minusTwo();", 97},
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "calling functions with arguments and bindings" do
    [
      {"let identity = fn(a) { a; };
      identity(4);", 4},
      {"let sum = fn(a, b) { a + b; };
      sum(1, 2);", 3},
      {"let sum = fn(a, b){
      	let c = a + b;
      	c;
      }
      sum(1, 2);", 3},
      {"let sum = fn(a, b){
      	let c = a + b;
      	c;
      }
      sum(1, 2) + sum(3, 4);", 10},
      {"let sum = fn(a, b){
      	let c = a + b;
      	c;
      }
      let outer = fn() {
      	sum(1, 2) + sum(3, 4);
      };
      outer();", 10},
      {"let globalNum = 10;
      let sum = fn(a, b){
      	let c = a + b;
      	c + globalNum;
      }
      let outer = fn() {
      	sum(1, 2) + sum(3, 4) + globalNum;
      };
      outer() + globalNum;", 50},
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "calling functions with wrong arguments" do
    [
      {"fn() {1;}(1);",
       "wrong number of arguments: want=0, got=1"},
      {
        "fn(a) {a;}();",
        "wrong number of arguments: want=1, got=0",
      },
      {
        "fn(a, b) {a + b;}(1);",
        "wrong number of arguments: want=2, got=1",
      },
    ].each do |input, expected|
      program = parse(input)
      compiler = MCompiler.new
      compiler.compile(program)

      vm = VM.new(compiler.bytecode)

      begin
        vm.run
        raise "expected VM error but resulted in none"
      rescue ex : VMException
        expected.should eq(ex.message)
      end
    end
  end

  it "builtin functions" do
    [
      { %(len("")), 0 },
      { %(len("four")), 4 },
      { %(len("hello world")), 11 },
      {
        "len(1)", MError.new(
          "argument to `len` not supported, got Objects::MInteger",
        ),
      },
      {
        %(len("one", "two")), MError.new(
          "wrong number of arguments. got=2, want=1"
        ),
      },
      {"len([1, 2, 3])", 3},
      {"len([])", 0},
      # { %(puts("hello", "world!")), VM_NULL },
      {"first([1, 2, 3])", 1},
      {"first([])", VM_NULL},
      {
        "first(1)", MError.new(
          "argument to `first` must be ARRAY, got Objects::MInteger"
        ),
      },
      {"last([1, 2, 3])", 3},
      {"last([])", VM_NULL},
      {
        "last(1)", MError.new(
          "argument to `last` must be ARRAY, got Objects::MInteger"
        ),
      },
      {"rest([1,2,3])", [2, 3]},
      {"rest([])", VM_NULL},
      {"push([], 1)", [1]},
      {
        "push(1, 1)", MError.new(
          "argument to `push` must be ARRAY, got Objects::MInteger"
        ),
      },
    ].each do |input, expected|
      case expected
      when Array(Int32)
        expected = expected.map(&.to_i64)
      when Int32
        expected = expected.to_i64
      end

      test_vm_result(input, expected)
    end
  end

  it "closures" do
    [
      {
        "let newClosure = fn(a) {
     	fn() {a; };
     };
     let closure = newClosure(99);
     closure();",
        99,
      },
      {
        "let newAdder = fn (a, b) {
         fn(c) { a + b + c };
     };
     let adder = newAdder (1, 2);
     adder(8);",
        11,
      },
      {
        "let newAdder = fn (a, b) {
      let c = a +b;
      fn(d) { c + d };
     };
     let adder = newAdder (1, 2);
     adder(8);",
        11,
      },
      {
        "let newAdderOuter = fn (a, b) {
         let c = a +b;
         fn(d) {
             let e = d +c;
             fn(f) { e + f; };
         };
     };
     let newAdderInner = newAdderOuter (1, 2);
     let adder = newAdderInner (3);
     adder(8);",
        14,
      },
      {
        "let a = 1;
     let newAdderOuter = fn (b) {
         fn(c) {
             fn(d) { a + b + c + d };
         };
     };
     let newAdderInner = newAdderOuter (2);
     let adder = newAdderInner (3);
     adder(8);",
        14,
      },
      {
        "let newClosure = fn (a, b) {
         let one = fn () { a; };
         let two = fn () { b; };
         fn() { one() + two(); };
     };
     let closure = newClosure (9, 90);
     closure();",
        99,
      },
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "recursive functions" do
    [
      {
        "let countDown = fn(x) {
            	if (x == 0) {
            		return 0;
            	} else {
            		countDown(x - 1);
            	};
            }
            countDown(1);",
        0,
      },
      {
        "let countDown = fn(x) {
            	if (x == 0) {
            		return 0;
            	} else {
            		countDown(x - 1);
            	};
            }
            let wrapper = fn() {
            	countDown(1);
            };
            wrapper();",
        0,
      },
      {
        "let wrapper = fn() {
            	let countDown = fn(x) {
            		if (x == 0) {
            			return 0;
            		} else {
            			countDown(x - 1);
            		};
            	};
            	countDown(1);
            };
            wrapper();",
        0,
      },
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end

  it "recursive fibonacci" do
    [
      {"
let fibonacci = fn(x) {
	if (x == 0) {
		return 0;
	} else {
		if (x == 1) {
			return 1;
		} else {
			fibonacci(x - 1) + fibonacci(x - 2);
		}
	}
};
fibonacci(15);", 610},
    ].each do |input, expected|
      test_vm_result(input, expected.to_i64)
    end
  end
end
