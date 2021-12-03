require "./spec_helper"
require "../src/compiler"

include Compilers

macro mak(op)
  make(Opcode::{{op}})
end

macro mak(op, i)
  make(Opcode::{{op}}, {{i}})
end

macro mak(op, i, j)
  make(Opcode::{{op}}, {{i}}, {{j}})
end

describe "Compiler" do
  it "integer arithmetic" do
    [
      {"1 + 2", [1, 2], [
        mak(OpConstant, 0),
        mak(OpConstant, 1),
        mak(OpAdd),
        mak(OpPop),
      ]},
      {"1; 2", [1, 2], [
        mak(OpConstant, 0),
        mak(OpPop),
        mak(OpConstant, 1),
        mak(OpPop),
      ]},
      {"1 - 2", [1, 2], [
        mak(OpConstant, 0),
        mak(OpConstant, 1),
        mak(OpSub),
        mak(OpPop),
      ]},
      {"1 * 2", [1, 2], [
        mak(OpConstant, 0),
        mak(OpConstant, 1),
        mak(OpMul),
        mak(OpPop),
      ]},
      {"2 / 1", [2, 1], [
        mak(OpConstant, 0),
        mak(OpConstant, 1),
        mak(OpDiv),
        mak(OpPop),
      ]},
      {"-1", [1], [
        mak(OpConstant, 0),
        mak(OpMinus),
        mak(OpPop),
      ]},
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants.map { |i| i.to_i64 }, expected_instructions)
    end
  end

  it "boolean expression" do
    [
      {"true", [] of Int32, [
        mak(OpTrue),
        mak(OpPop),
      ]},
      {"false", [] of Int32, [
        mak(OpFalse),
        mak(OpPop),
      ]},
      {"1 > 2", [1, 2], [
        mak(OpConstant, 0),
        mak(OpConstant, 1),
        mak(OpGreaterThan),
        mak(OpPop),
      ]},
      {"1 < 2", [2, 1], [
        mak(OpConstant, 0),
        mak(OpConstant, 1),
        mak(OpGreaterThan),
        mak(OpPop),
      ]},
      {"1 == 2", [1, 2], [
        mak(OpConstant, 0),
        mak(OpConstant, 1),
        mak(OpEqual),
        mak(OpPop),
      ]},
      {"1 != 2", [1, 2], [
        mak(OpConstant, 0),
        mak(OpConstant, 1),
        mak(OpNotEqual),
        mak(OpPop),
      ]},
      {"true == false", [] of Int32, [
        mak(OpTrue),
        mak(OpFalse),
        mak(OpEqual),
        mak(OpPop),
      ]},
      {"true != false", [] of Int32, [
        mak(OpTrue),
        mak(OpFalse),
        mak(OpNotEqual),
        mak(OpPop),
      ]},
      {"!true", [] of Int32, [
        mak(OpTrue),
        mak(OpBang),
        mak(OpPop),
      ]},
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants.map { |i| i.to_i64 }, expected_instructions)
    end
  end

  it "conditionals" do
    [
      {"if (true) {10}; 3333;", [10, 3333],
       [
         mak(OpTrue),
         mak(OpJumpNotTruthy, 10),
         mak(OpConstant, 0),
         mak(OpJump, 11),
         mak(OpNull),
         mak(OpPop),
         mak(OpConstant, 1),
         mak(OpPop),
       ],
      },
      {"if (true) {10} else {20}; 3333;", [10, 20, 3333],
       [
         mak(OpTrue),
         mak(OpJumpNotTruthy, 10),
         mak(OpConstant, 0),
         mak(OpJump, 13),
         mak(OpConstant, 1),
         mak(OpPop),
         mak(OpConstant, 2),
         mak(OpPop),
       ],
      },
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants.map { |i| i.to_i64 }, expected_instructions)
    end
  end

  it "global let statement" do
    [
      {"let one = 1; let two = 2;", [1, 2], [
        mak(OpConstant, 0),
        mak(OpSetGlobal, 0),
        mak(OpConstant, 1),
        mak(OpSetGlobal, 1),
      ]},
      {"let one = 1; one;", [1], [
        mak(OpConstant, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpPop),
      ]},
      {"let one = 1; let two = one; two;", [1], [
        mak(OpConstant, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpSetGlobal, 1),
        mak(OpGetGlobal, 1),
        mak(OpPop),
      ]},
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants.map { |i| i.to_i64 }, expected_instructions)
    end
  end

  it "string expressions" do
    [
      { %("monkey"), ["monkey"],
       [
         mak(OpConstant, 0),
         mak(OpPop),
       ] },
      { %("mon" + "key"), ["mon", "key"],
       [
         mak(OpConstant, 0),
         mak(OpConstant, 1),
         mak(OpAdd),
         mak(OpPop),
       ] },
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants, expected_instructions)
    end
  end

  it "array literals" do
    [
      {"[]", [] of Int32,
       [
         mak(OpArray, 0),
         mak(OpPop),
       ],
      },
      {"[1, 2, 3]",
       [1, 2, 3],
       [
         mak(OpConstant, 0),
         mak(OpConstant, 1),
         mak(OpConstant, 2),
         mak(OpArray, 3),
         mak(OpPop),
       ]}, {
        "[1 + 2, 3 - 4, 5 * 6]",
        [1, 2, 3, 4, 5, 6],
        [
          mak(OpConstant, 0),
          mak(OpConstant, 1),
          mak(OpAdd),
          mak(OpConstant, 2),
          mak(OpConstant, 3),
          mak(OpSub),
          mak(OpConstant, 4),
          mak(OpConstant, 5),
          mak(OpMul),
          mak(OpArray, 3),
          mak(OpPop),
        ],
      },
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants.map { |i| i.to_i64 }, expected_instructions)
    end
  end

  it "hash literals" do
    [
      {"{}", [] of Int32,
       [
         mak(OpHash, 0),
         mak(OpPop),
       ],
      },
      {
        "{1: 2, 3: 4, 5: 6}",
        [1, 2, 3, 4, 5, 6],
        [
          mak(OpConstant, 0),
          mak(OpConstant, 1),
          mak(OpConstant, 2),
          mak(OpConstant, 3),
          mak(OpConstant, 4),
          mak(OpConstant, 5),
          mak(OpHash, 6),
          mak(OpPop),
        ],
      },
      {
        "{1: 2 + 3, 4: 5 * 6}",
        [1, 2, 3, 4, 5, 6],
        [
          mak(OpConstant, 0),
          mak(OpConstant, 1),
          mak(OpConstant, 2),
          mak(OpAdd),
          mak(OpConstant, 3),
          mak(OpConstant, 4),
          mak(OpConstant, 5),
          mak(OpMul),
          mak(OpHash, 4),
          mak(OpPop),
        ],
      },
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants.map { |i| i.to_i64 }, expected_instructions)
    end
  end

  it "index expression" do
    [
      {
        "[1, 2, 3][1 + 1]",
        [1, 2, 3, 1, 1],
        [
          mak(OpConstant, 0),
          mak(OpConstant, 1),
          mak(OpConstant, 2),
          mak(OpArray, 3),
          mak(OpConstant, 3),
          mak(OpConstant, 4),
          mak(OpAdd),
          mak(OpIndex),
          mak(OpPop),
        ],
      },
      {
        "{1: 2}[2 - 1]",
        [1, 2, 2, 1],
        [
          mak(OpConstant, 0),
          mak(OpConstant, 1),
          mak(OpHash, 2),
          mak(OpConstant, 2),
          mak(OpConstant, 3),
          mak(OpSub),
          mak(OpIndex),
          mak(OpPop),
        ],
      },
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants.map { |i| i.to_i64 }, expected_instructions)
    end
  end

  it "functions" do
    [
      {
        "fn() {return 5 + 10 }",
        [
          5, 10, [
            mak(OpConstant, 0),
            mak(OpConstant, 1),
            mak(OpAdd),
            mak(OpReturnValue),
          ],
        ],
        [
          mak(OpClosure, 2, 0),
          mak(OpPop),
        ],
      }, {
        "fn() { 5 + 10 }",
        [
          5, 10, [
            mak(OpConstant, 0),
            mak(OpConstant, 1),
            mak(OpAdd),
            mak(OpReturnValue),
          ],
        ],
        [
          mak(OpClosure, 2, 0),
          mak(OpPop),
        ],
      }, {
        "fn() {1; 2}",
        [
          1, 2, [
            mak(OpConstant, 0),
            mak(OpPop),
            mak(OpConstant, 1),
            mak(OpReturnValue),
          ],
        ],
        [
          mak(OpClosure, 2, 0),
          mak(OpPop),
        ],
      },
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants, expected_instructions)
    end
  end

  it "functions without return value" do
    [{
      "fn() {}",
      [[
        mak(OpReturn),
      ],
      ],
      [
        mak(OpClosure, 0, 0),
        mak(OpPop),
      ],
    },
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants, expected_instructions)
    end
  end

  it "functions calls" do
    [{
      "fn(){24}();",
      [
        24,
        [
          mak(OpConstant, 0),
          mak(OpReturnValue),
        ],
      ],
      [
        mak(OpClosure, 1, 0),
        mak(OpCall, 0),
        mak(OpPop),
      ],
    }, {
      "let noArg = fn() { 24 };
noArg();",
      [
        24,
        [
          mak(OpConstant, 0),
          mak(OpReturnValue),
        ],
      ],
      [
        mak(OpClosure, 1, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpCall, 0),
        mak(OpPop),
      ],
    }, {
      "let oneArg = fn(a) {};
oneArg(24);",
      [
        [
          mak(OpReturn),
        ],
        24,
      ],
      [
        mak(OpClosure, 0, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpConstant, 1),
        mak(OpCall, 1),
        mak(OpPop),
      ],
    }, {
      "
let manyArg = fn(a, b, c){};
manyArg(24, 25, 26);
                ",
      [
        [
          mak(OpReturn),
        ],
        24, 25, 26,
      ],
      [
        mak(OpClosure, 0, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpConstant, 1),
        mak(OpConstant, 2),
        mak(OpConstant, 3),
        mak(OpCall, 3),
        mak(OpPop),
      ],
    }, {
      "
let oneArg = fn(a) {a};
oneArg(24);
                ",
      [
        [
          mak(OpGetLocal, 0),
          mak(OpReturnValue),
        ], 24,
      ],
      [
        mak(OpClosure, 0, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpConstant, 1),
        mak(OpCall, 1),
        mak(OpPop),
      ],
    }, {
      "
let manyArgs = fn(a, b, c) {a; b; c};
manyArgs(24, 25, 26);
                ",
      [
        [
          mak(OpGetLocal, 0),
          mak(OpPop),
          mak(OpGetLocal, 1),
          mak(OpPop),
          mak(OpGetLocal, 2),
          mak(OpReturnValue),
        ], 24, 25, 26,
      ],
      [
        mak(OpClosure, 0, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpConstant, 1),
        mak(OpConstant, 2),
        mak(OpConstant, 3),
        mak(OpCall, 3),
        mak(OpPop),
      ],
    }].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants, expected_instructions)
    end
  end

  it "compiler scopes" do
    compiler = MCompiler.new
    test_scope_index_size(compiler, 0)
    global_symbol_table = compiler.symbol_table
    compiler.emit(Opcode::OpMul)

    compiler.enter_scope
    test_scope_index_size(compiler, 1)

    compiler.emit(Opcode::OpSub)

    test_scope_instructions_size(compiler, 1)

    last = compiler.current_scope.last_instruction

    Opcode::OpSub.should eq(last.op)

    global_symbol_table.should eq(compiler.symbol_table.outer)

    compiler.leave_scope
    test_scope_index_size(compiler, 0)

    global_symbol_table.should eq(compiler.symbol_table)

    compiler.symbol_table.outer.should be_nil

    compiler.emit(Opcode::OpAdd)

    test_scope_instructions_size(compiler, 2)

    last = compiler.current_scope.last_instruction
    Opcode::OpAdd.should eq(last.op)

    previous = compiler.current_scope.previous_instruction
    Opcode::OpMul.should eq(previous.op)
  end

  it "let statements scopes" do
    [
      {"
let num = 55;
fn() { num }
            ", [
        55, [
          mak(OpGetGlobal, 0),
          mak(OpReturnValue),
        ],
      ],
       [
         mak(OpConstant, 0),
         mak(OpSetGlobal, 0),
         mak(OpClosure, 1, 0),
         mak(OpPop),
       ]}, {
        "fn() {
            	let num = 55;
            	num
            }",
        [
          55,
          [
            mak(OpConstant, 0),
            mak(OpSetLocal, 0),
            mak(OpGetLocal, 0),
            mak(OpReturnValue),
          ],
        ],
        [
          mak(OpClosure, 1, 0),
          mak(OpPop),
        ],
      }, {
        "fn() {
	let a = 55;
	let b = 77;
	a + b;
}", [
          55, 77, [
            mak(OpConstant, 0),
            mak(OpSetLocal, 0),
            mak(OpConstant, 1),
            mak(OpSetLocal, 1),
            mak(OpGetLocal, 0),
            mak(OpGetLocal, 1),
            mak(OpAdd),
            mak(OpReturnValue),
          ],
        ],
        [
          mak(OpClosure, 2, 0),
          mak(OpPop),
        ],
      },
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants, expected_instructions)
    end
  end

  it "buitlins" do
    [
      {"
len([]);
push([], 1);
            ", [1],
       [
         mak(OpGetBuiltin, 0),
         mak(OpArray, 0),
         mak(OpCall, 1),
         mak(OpPop),
         mak(OpGetBuiltin, 5),
         mak(OpArray, 0),
         mak(OpConstant, 0),
         mak(OpCall, 2),
         mak(OpPop),
       ]},
      {"fn() { len([])}",
       [
         [
           mak(OpGetBuiltin, 0),
           mak(OpArray, 0),
           mak(OpCall, 1),
           mak(OpReturnValue),
         ],
       ],
       [
         mak(OpClosure, 0, 0),
         mak(OpPop),
       ]},
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants, expected_instructions)
    end
  end

  it "closures" do
    [{"fn(a) {
                	fn(b){
                		a + b
                	}
                }", [
      [
        mak(OpGetFree, 0),
        mak(OpGetLocal, 0),
        mak(OpAdd),
        mak(OpReturnValue),
      ],
      [
        mak(OpGetLocal, 0),
        mak(OpClosure, 0, 1),
        mak(OpReturnValue),
      ],
    ],
      [
        mak(OpClosure, 1, 0),
        mak(OpPop),
      ]},
     {"fn(a) {
            	fn(b){
            		fn(c) {
            			a + b + c
            		}
            	}
            }", [
       [
         mak(OpGetFree, 0),
         mak(OpGetFree, 1),
         mak(OpAdd),
         mak(OpGetLocal, 0),
         mak(OpAdd),
         mak(OpReturnValue),
       ],
       [
         mak(OpGetFree, 0),
         mak(OpGetLocal, 0),
         mak(OpClosure, 0, 2),
         mak(OpReturnValue),
       ],
       [
         mak(OpGetLocal, 0),
         mak(OpClosure, 1, 1),
         mak(OpReturnValue),
       ],
     ],
      [
        mak(OpClosure, 2, 0),
        mak(OpPop),
      ]},
     {"let global = 55;
       fn() {
       	let a = 66;
       	fn(){
       		let b = 77;
       		fn(){
       			let c = 88;
       			global + a + b + c;
       		}
       	}
       }",
      [
        55, 66, 77, 88,
        [
          mak(OpConstant, 3),
          mak(OpSetLocal, 0),
          mak(OpGetGlobal, 0),
          mak(OpGetFree, 0),
          mak(OpAdd),
          mak(OpGetFree, 1),
          mak(OpAdd),
          mak(OpGetLocal, 0),
          mak(OpAdd),
          mak(OpReturnValue),
        ],
        [
          mak(OpConstant, 2),
          mak(OpSetLocal, 0),
          mak(OpGetFree, 0),
          mak(OpGetLocal, 0),
          mak(OpClosure, 4, 2),
          mak(OpReturnValue),
        ],
        [
          mak(OpConstant, 1),
          mak(OpSetLocal, 0),
          mak(OpGetLocal, 0),
          mak(OpClosure, 5, 1),
          mak(OpReturnValue),
        ],
      ],
      [
        mak(OpConstant, 0),
        mak(OpSetGlobal, 0),
        mak(OpClosure, 6, 0),
        mak(OpPop),
      ]},
    ].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants, expected_instructions)
    end
  end

  it "recursive functions" do
    [{
      "let countDown = fn(x) { countDown(x - 1) };
       countDown(1);",
      [
        1,
        [
          mak(OpCurrentClosure),
          mak(OpGetLocal, 0),
          mak(OpConstant, 0),
          mak(OpSub),
          mak(OpCall, 1),
          mak(OpReturnValue),
        ],
        1,
      ],
      [
        mak(OpClosure, 1, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpConstant, 2),
        mak(OpCall, 1),
        mak(OpPop),
      ],
    }, {
      "let wrapper = fn(){
     	let countDown = fn(x) { countDown(x - 1); };
     	countDown(1);
     };
     wrapper();",
      [
        1,
        [
          mak(OpCurrentClosure),
          mak(OpGetLocal, 0),
          mak(OpConstant, 0),
          mak(OpSub),
          mak(OpCall, 1),
          mak(OpReturnValue),
        ],
        1,
        [
          mak(OpClosure, 1, 0),
          mak(OpSetLocal, 0),
          mak(OpGetLocal, 0),
          mak(OpConstant, 2),
          mak(OpCall, 1),
          mak(OpReturnValue),
        ],
      ],
      [
        mak(OpClosure, 3, 0),
        mak(OpSetGlobal, 0),
        mak(OpGetGlobal, 0),
        mak(OpCall, 0),
        mak(OpPop),
      ],
    }].each do |input, expected_constants, expected_instructions|
      test_compile_result(input, expected_constants, expected_instructions)
    end
  end
end
