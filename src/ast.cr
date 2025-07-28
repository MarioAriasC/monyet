require "./token"

macro def_mask
    def mask : UInt8
      Mask::{{ @type.name[5..] }}.value
    end
  end

module Ast
  extend self
  include Tokens

  enum Mask : UInt8
    Identifier
    IntegerLiteral
    InfixExpression
    BlockStatement
    ExpressionStatement
    IfExpression
    CallExpression
    ReturnStatement
    PrefixExpression
    BooleanLiteral
    LetStatement
    FunctionLiteral
    StringLiteral
    IndexExpression
    HashLiteral
    ArrayLiteral
    NULL
  end

  abstract class Node
    abstract def token_literal : String
    abstract def to_s(io)
    abstract def mask : UInt8
  end

  abstract class Statement < Node
  end

  abstract class Expression < Node
    def <=>(other : Expression)
      "#{self}" <=> "#{other}"
    end
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

  class Program
    getter statements

    def initialize(@statements : Array(Statement))
    end

    def token_literal : String
      if @statements.empty
        ""
      else
        @statements.first(1).token_literal
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

    def_mask
  end

  class LetStatement < Statement
    include TokenHolder

    getter name
    getter? value

    def initialize(@token : Token, @name : Identifier, @value : Expression?)
    end

    def to_s(io)
      io << "#{token_literal} #{@name} = #{@value.or_else("")};"
    end

    def_mask
  end

  class IntegerLiteral < Expression
    include TokenHolder
    include LiteralExpression
    getter value

    def initialize(@token : Token, @value : Int64)
    end

    def_mask
  end

  class BooleanLiteral < Expression
    include TokenHolder
    include LiteralExpression
    getter value

    def initialize(@token : Token, @value : Bool)
    end

    def_mask
  end

  class ReturnStatement < Statement
    include TokenHolder
    getter? return_value

    def initialize(@token : Token, @return_value : Expression?)
    end

    def to_s(io)
      io << "#{token_literal} #{@return_value.or_else("")};"
    end

    def_mask
  end

  class ExpressionStatement < Statement
    include TokenHolder
    getter? expression

    def initialize(@token : Token, @expression : Expression?)
    end

    def to_s(io)
      io << "#{@expression.or_else("")}"
    end

    def_mask
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

    def_mask
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

    def_mask
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

    def_mask
  end

  class BlockStatement < Statement
    include TokenHolder
    getter? statements

    def initialize(@token : Token, @statements : Array(Statement?)?)
    end

    def to_s(io)
      io << "#{@statements.or_else([] of String).join("")}"
    end

    def_mask
  end

  class IfExpression < Expression
    include TokenHolder

    getter? condition
    getter? consequence
    getter? alternative

    def initialize(@token : Token, @condition : Expression?, @consequence : BlockStatement?, @alternative : BlockStatement?)
    end

    def to_s(io)
      io << "if(#{@condition}) #{@consequence} #{@alternative ? "else #{@alternative}" : ""}"
    end

    def_mask
  end

  class FunctionLiteral < Expression
    include TokenHolder
    getter? parameters
    getter? body
    property name

    def initialize(@token : Token, @parameters : Array(Identifier)?, @body : BlockStatement?, @name : String = "")
    end

    def to_s(io)
      io << "#{token_literal}#{@name.empty? ? "" : "<#{@name}>"}(#{@parameters.or_else([] of String).join(", ")}) {#{@body}}"
    end

    def_mask
  end

  class StringLiteral < Expression
    include TokenHolder

    getter value

    def initialize(@token : Token, @value : String)
    end

    def to_s(io)
      io << @value
    end

    def_mask
  end

  class ArrayLiteral < Expression
    include TokenHolder

    getter? elements

    def initialize(@token : Token, @elements : Array(Expression?)?)
    end

    def to_s(io)
      io << "[#{@elements.or_else([] of String).join(", ")}]"
    end

    def_mask
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

    def_mask
  end

  class HashLiteral < Expression
    include TokenHolder

    getter pairs

    def initialize(@token : Token, @pairs : Hash(Expression, Expression))
    end

    def to_s(io)
      io << "{#{@pairs.map { |key, value| "#{key}:#{value}" }.join(", ")}}"
    end

    def_mask
  end
end
