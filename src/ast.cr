require "./token"

module Ast
  extend self
  include Tokens

  abstract class Node
    abstract def token_literal : String
    abstract def to_s(io)
  end

  abstract class Statement < Node
  end

  abstract class Expression < Node
  end

  module TokenHolder
    getter token

    def token_literal : String
      @token.literal
    end
  end

  module LiteralExpression
    def to_s(io)
      io << @token.literal
    end
  end

  class Program < Node
    getter statements

    def initialize(@statements : Array(Statement))
    end

    def token_literal : String
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

  class Identifier < Expression
    include TokenHolder
    getter value

    def initialize(@token : Token, @value : String)
    end

    def to_s(io)
      io << @value
    end
  end

  class LetStatement < Statement
    include TokenHolder

    getter name
    getter? value

    def initialize(@token : Token, @name : Identifier, @value : Expression?)
    end

    def to_s(io)
      io << "#{token_literal} #{@name} #{@value.or_else("")}"
    end
  end

  class IntegerLiteral < Expression
    include TokenHolder
    include LiteralExpression
    getter value

    def initialize(@token : Token, @value : Int64)
    end
  end

  class BoolLiteral < Expression
    include TokenHolder
    include LiteralExpression
    getter value

    def initialize(@token : Token, @value : Bool)
    end
  end

  class ReturnStatement < Statement
    include TokenHolder
    getter? return_value

    def initialize(@token : Token, @return_value : Expression?)
    end

    def to_s(io)
      io << "#{token_literal} #{@return_value.or_else("")}"
    end
  end

  class ExpressionStatement < Statement
    include TokenHolder
    getter? expression

    def initialize(@token : Token, @expression : Expression?)
    end

    def to_s(io)
      io << "#{@expression.or_else("")}"
    end
  end

  class PrefixExpression < Expression
    include TokenHolder
    getter operator
    getter? right

    def initialize(@token : Token, @operator : String, @right : Expression?)
    end

    def to_s(io)
      io << "(#{@operator}#{@right})"
    end
  end

  class InfixExpression < Expression
    include TokenHolder
    getter? left
    getter operator
    getter? right

    def initialize(@token : Token, @left : Expression?, @operator : String, @right : Expression?)
    end

    def to_s(io)
      io << "(#{@left} #{@operator} #{@right})"
    end
  end

  class CallExpression < Expression
    include TokenHolder
    getter? function
    getter? arguments

    def initialize(@token : Token, @function : Expression?, @arguments : Array(Expression?)?)
    end

    def to_s(io)
      io << "#{@function}(#{@arguments.or_else([] of String).join(", ")})"
    end
  end

  class BlockStatement < Statement
    include TokenHolder
    getter? statements

    def initialize(@token : Token, @statements : Array(Statement?)?)
    end

    def to_s(io)
      io << "#{@statements.or_else([] of String).join}"
    end
  end

  class IfExpression < Expression
    include TokenHolder

    getter? condition
    getter? consequence
    getter? alternative

    def initialize(@token : Token, @condition : Expression?, @consequence : BlockStatement?, @alternative : BlockStatement?)
    end

    def to_s(io)
      io << "if#{@condition} #{@consequence} #{@alternative ? "else #{@alternative}" : ""}"
    end
  end

  class FunctionLiteral < Expression
    include TokenHolder
    getter? parameters
    getter? body
    property name

    def initialize(@token : Token, @parameters : Array(Identifier)?, @body : BlockStatement?, @name : String = "")
    end

    def to_s(io)
      io << "#{token_literal}#{@name.empty? ? "" : "<#{@name}>"}(#{@parameters.or_else([] of String).join(", ")}) #{@body}"
    end
  end

  class StringLiteral < Expression
    include TokenHolder

    getter value

    def initialize(@token : Token, @value : String)
    end

    def to_s(io)
      io << @value
    end
  end

  class ArrayLiteral < Expression
    include TokenHolder

    getter? elements

    def initialize(@token : Token, @elements : Array(Expression?)?)
    end

    def to_s(io)
      io << "[#{@elements.or_else([] of String).join(", ")}]"
    end
  end

  class IndexExpression < Expression
    include TokenHolder

    getter? left
    getter? index

    def initialize(@token : Token, @left : Expression?, @index : Expression?)
    end

    def to_s(io)
      io << "(#{@left}[#{@index}])"
    end
  end

  class HashLiteral < Expression
    include TokenHolder

    getter pairs

    def initialize(@token : Token, @pairs : Hash(Expression, Expression))
    end

    def to_s(io)
      io << "{#{@pairs.each { |key, value| "#{key}:#{value}" }}}"
    end
  end
end
