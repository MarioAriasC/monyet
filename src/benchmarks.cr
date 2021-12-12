require "./objects"
require "./evaluator"
require "./parser"
require "./lexer"
require "./compiler"
require "./vm"

module Benchmarks
  extend self
  include Objects
  include Evaluator
  include Vm
  SLOW_INPUT = %(
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
fibonacci(35);)

  FAST_INPUT = fast_input(35)

  def fast_input(size : Int32)
    %(
let fibonacci = fn(x) {
    if (x < 2) {
    	return x;
    } else {
    	fibonacci(x - 1) + fibonacci(x - 2);
    }
};
fibonacci(#{size});)
  end

  def crystal(x : Int32)
    measure("crystal") do
      fibonacci(x.to_i64)
    end
  end

  def eval(input : String)
    env = Environment.new
    measure("eval") do
      eval(parse(input), env).as(MInteger)
    end
  end

  def vm(input : String)
    compiler = Compilers::MCompiler.new
    compiler.compile(parse(input))
    machine = Vm::VM.new(compiler.bytecode)
    measure("vm") do
      machine.run
      machine.last_popped_stack_elem?.not_nil!.as(MInteger)
    end
  end

  private def parse(input : String) : Parsers::Program
    lexer = Lexers::Lexer.new(input)
    parser = Parsers::Parser.new(lexer)
    return parser.parse_program
  end

  private def measure(engine : String, &body : -> MInteger)
    result : MInteger? = nil
    elapsed_time = Time.measure do
      result = body.call
    end
    p "engine=#{engine}, #{result.not_nil!.value.inspect}, duration=#{elapsed_time}"
  end

  private def step(x : Int64) : Int64
    if (x < 2)
      return x
    else
      step(x - 1) + step(x - 2)
    end
  end

  private def fibonacci(x : Int64 = 35) : MInteger
    return MInteger.new(step(x))
  end

  private def fast_fibonacci(x : Int64 = 35) : MInteger
    return MInteger.new(fast_step(x))
  end

  private def fast_step(x : Int64) : Int64
    if x < 2
      return x
    end

    first = 0.to_i64
    second = 1.to_i64
    nth = 1.to_i64
    (2...x).each do |_|
      nth = first + second
      first = second
      second = nth
    end
    return nth.to_i64
  end
end
