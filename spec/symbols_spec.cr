require "./spec_helper"
require "../src/symbols"

include Symbols

macro symb(name, scope, index)
  Symbols::Symbol.new("{{name}}", SymbolScope::{{scope}}, {{index}})
end

describe "Symbols" do
  it "define" do
    expected = {
      "a" => symb(a, Global, 0),
      "b" => symb(b, Global, 1),
      "c" => symb(c, Local, 0),
      "d" => symb(d, Local, 1),
      "e" => symb(e, Local, 0),
      "f" => symb(f, Local, 1),
    }

    global = SymbolTable.new

    test_symbol("a", global, expected)
    test_symbol("b", global, expected)

    first_local = SymbolTable.new(outer: global)

    test_symbol("c", first_local, expected)
    test_symbol("d", first_local, expected)

    second_local = SymbolTable.new(outer: global)
    test_symbol("e", second_local, expected)
    test_symbol("f", second_local, expected)
  end

  it "resolve global" do
    global = SymbolTable.new
    global.define("a")
    global.define("b")

    [
      symb(a, Global, 0),
      symb(b, Global, 1),
    ].each do |symbol|
      begin
        test_symbol(global, symbol)
      rescue ex : SymbolException
        raise ex
      end
    end
  end

  it "resolve local" do
    global = SymbolTable.new
    global.define("a")
    global.define("b")

    local = SymbolTable.new(outer: global)
    local.define("c")
    local.define("d")

    [
      symb(a, Global, 0),
      symb(b, Global, 1),
      symb(c, Local, 0),
      symb(d, Local, 1),
    ].each do |sym|
      test_symbol(local, sym)
    end
  end

  it "resolve nested local" do
    global = SymbolTable.new
    global.define("a")
    global.define("b")

    first_local = SymbolTable.new(outer: global)
    first_local.define("c")
    first_local.define("d")

    second_local = SymbolTable.new(outer: global)
    second_local.define("e")
    second_local.define("f")

    [
      {first_local, [
        symb(a, Global, 0),
        symb(b, Global, 1),
        symb(c, Local, 0),
        symb(d, Local, 1),
      ]},
      {second_local, [
        symb(a, Global, 0),
        symb(b, Global, 1),
        symb(e, Local, 0),
        symb(f, Local, 1),
      ]},
    ].each do |table, symbols|
      symbols.each do |sym|
        test_symbol(table, sym)
      end
    end
  end

  it "define resolve builtins" do
    global = SymbolTable.new
    first_local = SymbolTable.new(outer: global)
    second_local = SymbolTable.new(outer: first_local)

    expected = [
      symb(a, Builtin, 0),
      symb(c, Builtin, 1),
      symb(e, Builtin, 2),
      symb(f, Builtin, 3),
    ]

    expected.each_with_index do |symbol, i|
      global.define_builtin(i, symbol.name)
    end

    [global, first_local, second_local].each do |table|
      expected.each do |symbol|
        result = table.resolve(symbol.name)
        result.should eq(symbol)
      end
    end
  end

  it "resolve free" do
    global = SymbolTable.new
    global.define("a")
    global.define("b")

    first_local = SymbolTable.new(outer: global)
    first_local.define("c")
    first_local.define("d")

    second_local = SymbolTable.new(outer: first_local)
    second_local.define("e")
    second_local.define("f")

    [{first_local,
      [
        symb(a, Global, 0),
        symb(b, Global, 1),
        symb(c, Local, 0),
        symb(d, Local, 1),
      ],
      [] of Symbols::Symbol},
     {second_local,
      [
        symb(a, Global, 0),
        symb(b, Global, 1),
        symb(c, Free, 0),
        symb(d, Free, 1),
        symb(e, Local, 0),
        symb(f, Local, 1),
      ],
      [
        symb(c, Local, 0),
        symb(d, Local, 1),
      ],
     },
    ].each do |table, expected_symbols, expected_free_symbols|
      expected_symbols.each do |sym|
        test_symbol(table, sym)
      end

      table.free_symbols.size.should eq(expected_free_symbols.size)
      expected_free_symbols.each_with_index do |sym, i|
        result = table.free_symbols[i]
        sym.should eq(result)
      end
    end
  end

  it "resolve unresolvable free" do
    global = SymbolTable.new
    global.define("a")

    first_local = SymbolTable.new(outer: global)
    first_local.define("c")

    second_local = SymbolTable.new(outer: first_local)
    second_local.define("e")
    second_local.define("f")

    [
      symb(a, Global, 0),
      symb(c, Free, 0),
      symb(e, Local, 0),
      symb(f, Local, 1),
    ].each do |expected|
      test_symbol(second_local, expected)
    end

    ["b", "d"].each do |unresolvable|
      begin
        second_local.resolve(unresolvable)
        raise "Name #{unresolvable} resolved, but was expected not to"
      rescue ex : SymbolException
      end
    end
  end

  it "define and resolve function name" do
    global = SymbolTable.new
    global.define_function_name("a")
    expected = symb(a, Function, 0)
    test_symbol(global, expected)
  end

  it "shadowing function name" do
    global = SymbolTable.new
    global.define_function_name("a")
    global.define("a")

    expected = symb(a, Global, 0)
    test_symbol(global, expected)
  end
end
