# TODO: Write documentation for `Monyet`
require "./benchmarks"
require "./objects"
require "./symbols"
require "./lexer"
require "option_parser"

module Monyet
  extend self
  VERSION = "0.1.0"

  private MONKEY_FACE = %(            __,__
   .--.  .-"     "-.  .--.
  / .. \\/  .-. .-.  \\/ .. \\
 | |  '|  /   Y   \\  |'  | |
 | \\   \\  \\ 0 | 0 /  /   / |
  \\ '- ,\\.-"""""""-./, -' /
   ''-' /_   ^ ^   _\\ '-''
       |  \\._   _./  |
       \\   \\ '~' /   /
        '._ '-=-' _.'
           '-----'
)

  private PROMPT = ">>>"

  private def print_parser_errors(errors : Array(String))
    puts(MONKEY_FACE)
    puts("Woops! we ran into some monkey business here!")
    puts(" parse errors:")
    errors.each do |error|
      puts("\t#{error}")
    end
  end

  private def start
    puts("Welcome to the monyet language")
    puts("Feel free to type any command")
    constants = [] of Objects::MObject
    globals = [] of Objects::MObject
    symbol_table = Symbols::SymbolTable.new
    Objects::BUILTINS.each_with_index do |(name, _), i|
      symbol_table.define_builtin(i, name)
    end
    loop do
      puts("#{PROMPT} ")
      code = read_line
      if code != ""
        lexer = Lexers::Lexer.new(code)
        parser = Parsers::Parser.new(lexer)
        program = parser.parse_program
        if parser.errors.empty?
          begin
            compiler = Compilers::MCompiler.new(constants, symbol_table)
            compiler.compile(program)
            bytecode = compiler.bytecode
            constants = bytecode.constants
            machine = Vm::VM.new(bytecode, globals)
            machine.run
            stack_top = machine.last_popped_stack_elem?
            puts(stack_top.inspect)
          rescue ex : Compilers::MCompilerException
            puts("Woops! Compilation failed:\n#{ex.message}")
          rescue ex : Vm::VMException
            puts("Woops! Execution bytecode failed:\n#{ex.message}")
          rescue ex
            puts("Woops!:\n#{ex.message}")
          end
        else
          print_parser_errors(parser.errors)
        end
      end
    end
  end

  OptionParser.parse do |parser|
    parser.on "-v", "--version", "Show version" do
      p VERSION
      exit
    end
    parser.on "-h", "--help", "Show help" do
      puts parser
      exit
    end
    parser.on "--crystal", "Runs crystal version" do
      Benchmarks.crystal(35)
    end
    parser.on "--eval", "Runs eval version" do
      Benchmarks.eval(Benchmarks::SLOW_INPUT)
    end
    parser.on "--eval-fast", "Runs eval fast version" do
      Benchmarks.eval(Benchmarks::FAST_INPUT)
    end
    parser.on "--vm", "Runs vm version" do
      Benchmarks.vm(Benchmarks::SLOW_INPUT)
    end
    parser.on "--vm-fast", "Runs vm fast version" do
      Benchmarks.vm(Benchmarks::FAST_INPUT)
    end
    parser.on "--repl", "REPL" do
      start
    end
  end
end
