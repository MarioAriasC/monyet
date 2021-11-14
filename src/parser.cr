require "./lexer"
require "./token"
require "./ast"

module Parsers
  extend self
  include Lexers
  include Tokens
  include Ast

  enum Precedence
    Lowest
    Equals
    LessGreater
    Sum
    Product
    Prefix
    Call
    Index
  end

  PRECEDENCES = {
    EQ       => Precedence::Equals,
    NOT_EQ   => Precedence::Equals,
    LT       => Precedence::LessGreater,
    GT       => Precedence::LessGreater,
    PLUS     => Precedence::Sum,
    MINUS    => Precedence::Sum,
    SLASH    => Precedence::Product,
    ASTERISK => Precedence::Product,
    LPAREN   => Precedence::Call,
    LBRACKET => Precedence::Index,
  }

  class Parser
    @errors = [] of String
    @cur_token : Token
    @peek_token : Token
    @prefix_parsers : Hash(TokenType, -> Expression?)
    @infix_parsers : Hash(TokenType, Expression? -> Expression?)

    def initialize(@lexer : Lexer)
    end
  end
end
