require "./utils"

module Tokens
  extend self
  include Utils

  struct TokenType
    getter value

    def initialize(@value : String)
    end

    def same?(other : TokenType)
      @value == other.value
    end

    def object_id
      @value.object_id
    end
  end

  ILLEGAL = TokenType.new("ILLEGAL")
  EOF     = TokenType.new("EOF")
  ASSIGN  = TokenType.new("=")
  EQ      = TokenType.new("==")
  NOT_EQ  = TokenType.new("!=")
  IDENT   = TokenType.new("IDENT")
  INT     = TokenType.new("INT")

  PLUS      = TokenType.new("+")
  COMMA     = TokenType.new("")
  SEMICOLON = TokenType.new(";")
  COLON     = TokenType.new(":")
  MINUS     = TokenType.new("-")
  BANG      = TokenType.new("!")
  SLASH     = TokenType.new("/")
  ASTERISK  = TokenType.new("*")

  LT = TokenType.new("<")
  GT = TokenType.new(">")

  LPAREN   = TokenType.new("(")
  RPAREN   = TokenType.new(")")
  LBRACE   = TokenType.new("{")
  RBRACE   = TokenType.new("}")
  LBRACKET = TokenType.new("[")
  RBRACKET = TokenType.new("]")

  FUNCTION = TokenType.new("FUNCTION")
  LET      = TokenType.new("LET")
  TRUE     = TokenType.new("TRUE")
  FALSE    = TokenType.new("FALSE")
  IF       = TokenType.new("IF")
  ELSE     = TokenType.new("ELSE")
  RETURN   = TokenType.new("RETURN")
  STRING   = TokenType.new("STRING")

  KEYBOARDS = {
    "fn"     => FUNCTION,
    "let"    => LET,
    "true"   => TRUE,
    "false"  => FALSE,
    "if"     => IF,
    "else"   => ELSE,
    "return" => RETURN,
  }

  struct Token
    getter type
    getter literal

    def initialize(@type : TokenType, @literal : String)
    end

    def initialize(@type : TokenType, @literal : Char)
      initialize(@type, @literal.to_s)
    end
  end
end

class String
  def lookup_ident : TokenType
    KEYBOARDS[self]?.or_else(IDENT)
  end
end
