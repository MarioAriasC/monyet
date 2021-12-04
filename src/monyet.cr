# TODO: Write documentation for `Monyet`
require "./benchmarks"
require "option_parser"

module Monyet
  VERSION = "0.1.0"

  option_parser = OptionParser.parse do |parser|
    parser.on "-v", "--version", "Show version" do
      p VERSION
      exit
    end
    parser.on "-h", "--help", "Show help" do
      puts parser
      exit
    end
    parser.on "--crystal", "Runs crystal version" do
      Benchmarks.crystal
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
  end
end
