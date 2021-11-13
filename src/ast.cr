module Ast
  abstract class Node
    abstract def token_literal : String
    abstract def to_s(io)
  end

  abstract class Statement < Node
  end

  abstract class Expression < Node
  end

  class Program < Node
    getter statements

    def initialize(@statements : Array(Statement))
    end

    def token_literal
      if @statements.empty
        return ""
      else
        return @statements.first(1).token_literal
      end
    end

    def to_s(io)
      io << @statements.join("")
    end
  end
end
