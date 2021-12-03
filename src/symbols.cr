module Symbols
  extend self
  enum SymbolScope
    Global
    Local
    Builtin
    Free
    Function
  end

  struct Symbol
    getter name
    getter scope
    getter index

    def initialize(@name : String, @scope : SymbolScope, @index : Int32)
    end
  end

  class SymbolTable
    property num_definitions : Int32 = 0
    @free_symbols = [] of Symbol

    getter free_symbols
    getter outer

    def initialize(@store : Hash(String, Symbol) = {} of String => Symbol, @outer : SymbolTable? = nil)
    end

    def define(name : String) : Symbol
      scope = if @outer.nil?
                SymbolScope::Global
              else
                SymbolScope::Local
              end
      symbol = Symbol.new(name, scope, @num_definitions)
      @store[name] = symbol
      @num_definitions += 1
      return symbol
    end

    def resolve(name : String) : Symbol
      symbol = @store[name]?
      if symbol.nil?
        if @outer.nil?
          raise SymbolException.new("undefined variable #{name}")
        else
          symbol = @outer.not_nil!.resolve(name)
          if symbol.scope == SymbolScope::Global || symbol.scope == SymbolScope::Builtin
            return symbol
          else
            return define_free(symbol)
          end
        end
      else
        return symbol
      end
    end

    def define_builtin(index : Int32, name : String) : Symbol
      stored = @store[name]?
      if stored.nil?
        symbol = Symbol.new(name, SymbolScope::Builtin, index)
        @store[name] = symbol
        return symbol
      else
        return stored
      end
    end

    def define_function_name(name : String) : Symbol
      symbol = Symbol.new(name, SymbolScope::Function, 0)
      @store[name] = symbol
      return symbol
    end

    private def define_free(original : Symbol) : Symbol
      @free_symbols << original
      symbol = Symbol.new(original.name, SymbolScope::Free, @free_symbols.size - 1)
      @store[original.name] = symbol
      return symbol
    end
  end

  class SymbolException < Exception
  end
end
