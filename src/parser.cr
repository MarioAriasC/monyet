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

  alias PrefixParser = -> Expression?
  alias InfixParser = Expression? -> Expression?

  class Parser
    @errors = [] of String
    @cur_token : Token
    @peek_token : Token
    @prefix_parsers = {} of TokenType => PrefixParser
    @infix_parsers = {} of TokenType => InfixParser

    getter errors

    macro rexp?(r)
      return {{r}}.as(Expression?)
    end

    def initialize(@lexer : Lexer)
      @cur_token = Token.new(ILLEGAL, "")
      @peek_token = Token.new(ILLEGAL, "")
      next_token
      next_token

      @prefix_parsers[INT] = ->parse_integer_literal
      @prefix_parsers[TRUE] = ->parse_boolean_literal
      @prefix_parsers[FALSE] = ->parse_boolean_literal
      @prefix_parsers[IDENT] = ->parse_identifier
      @prefix_parsers[BANG] = ->parse_prefix_expression
      @prefix_parsers[MINUS] = ->parse_prefix_expression
      @prefix_parsers[LPAREN] = ->parse_group_expression
      @prefix_parsers[IF] = ->parse_if_expression
      @prefix_parsers[FUNCTION] = ->parse_function_literal
      @prefix_parsers[LBRACKET] = ->parse_array_literal
      @prefix_parsers[STRING] = ->parse_string_literal
      @prefix_parsers[LBRACE] = ->parse_hash_literal

      @infix_parsers[PLUS] = ->parse_infix_expression(Expression?)
      @infix_parsers[MINUS] = ->parse_infix_expression(Expression?)
      @infix_parsers[SLASH] = ->parse_infix_expression(Expression?)
      @infix_parsers[ASTERISK] = ->parse_infix_expression(Expression?)
      @infix_parsers[EQ] = ->parse_infix_expression(Expression?)
      @infix_parsers[NOT_EQ] = ->parse_infix_expression(Expression?)
      @infix_parsers[LT] = ->parse_infix_expression(Expression?)
      @infix_parsers[GT] = ->parse_infix_expression(Expression?)
      @infix_parsers[LPAREN] = ->parse_call_expression(Expression?)
      @infix_parsers[LBRACKET] = ->parse_index_expression(Expression?)
    end

    def parse_program : Program
      statements = [] of Statement
      while @cur_token.type != EOF
        statement = parse_statement
        if statement
          statements << statement
        end
        next_token
      end
      return Program.new(statements)
    end

    private def parse_statement : Statement?
      case @cur_token.type
      when LET
        return parse_let_statement
      when RETURN
        return parse_return_statement
      else
        return parse_expression_statement
      end
    end

    private def next_token
      @cur_token = @peek_token
      @peek_token = @lexer.next_token
    end

    private def parse_integer_literal
      token = @cur_token
      begin
        value = token.literal.to_i64
        rexp? IntegerLiteral.new(token, value)
      rescue ex : ArgumentError
        @errors << "could not parse #{token.literal} as integer"
        return nil
      end
    end

    private def parse_boolean_literal
      rexp? BooleanLiteral.new(@cur_token, cur_token_is(TRUE))
    end

    private def parse_identifier
      rexp? Identifier.new(@cur_token, @cur_token.literal)
    end

    private def parse_prefix_expression
      token = @cur_token
      operator = token.literal

      next_token

      right = parse_expression(Precedence::Prefix)
      rexp? PrefixExpression.new(token, operator, right)
    end

    private def cur_token_is(type : TokenType) : Bool
      return @cur_token.type == type
    end

    private def parse_expression(precedence : Precedence) : Expression?
      prefix = @prefix_parsers[@cur_token.type]?
      if prefix == nil
        no_prefix_parse_error(@cur_token.type)
        return nil
      end
      left = prefix.as(PrefixParser).call
      while !peek_token_is?(SEMICOLON) && precedence < peek_precedence
        infix = @infix_parsers[@peek_token.type]?
        if infix == nil
          return left
        end
        next_token
        left = infix.as(InfixParser).call(left)
      end
      return left
    end

    private def parse_group_expression : Expression?
      next_token

      exp = parse_expression(Precedence::Lowest)

      ex_peek RPAREN

      return exp
    end

    macro ex_peek(token)
      if !expect_peek?({{token}})
        return nil
      end
    end

    private def parse_if_expression
      token = @cur_token

      ex_peek LPAREN
      next_token

      condition = parse_expression(Precedence::Lowest)

      ex_peek RPAREN

      ex_peek LBRACE
      consequence = parse_block_statement

      alternative = if peek_token_is?(ELSE)
                      next_token
                      ex_peek LBRACE
                      parse_block_statement
                    else
                      nil
                    end
      rexp? IfExpression.new(token, condition, consequence, alternative)
    end

    private def parse_block_statement : BlockStatement
      token = @cur_token
      statements = [] of Statement?

      next_token

      while !cur_token_is(RBRACE) && !cur_token_is(EOF)
        statement = parse_statement
        if statement
          statements << statement
        end
        next_token
      end

      return BlockStatement.new(token, statements)
    end

    private def parse_let_statement
      token = @cur_token
      ex_peek IDENT
      name = Identifier.new(@cur_token, @cur_token.literal)
      ex_peek ASSIGN
      next_token
      value = parse_expression(Precedence::Lowest)

      if value.is_a?(FunctionLiteral)
        value.as(FunctionLiteral).name = name.value
      end

      if peek_token_is?(SEMICOLON)
        next_token
      end

      return LetStatement.new(token, name, value)
    end

    private def parse_return_statement
      token = @cur_token
      next_token
      return_value = parse_expression(Precedence::Lowest)
      while peek_token_is?(SEMICOLON)
        next_token
      end
      return ReturnStatement.new(token, return_value)
    end

    private def parse_expression_statement
      token = @cur_token
      expression = parse_expression(Precedence::Lowest)
      if peek_token_is?(SEMICOLON)
        next_token
      end
      return ExpressionStatement.new(token, expression)
    end

    private def parse_infix_expression(left : Expression?) : Expression?
      token = @cur_token
      operator = token.literal

      precedence = cur_precedence
      next_token
      right = parse_expression(precedence)
      rexp? InfixExpression.new(token, left, operator, right)
    end

    private def parse_function_literal
      token = @cur_token
      ex_peek LPAREN
      parameters = parse_function_parameters
      ex_peek LBRACE
      body = parse_block_statement
      rexp? FunctionLiteral.new(token, parameters, body)
    end

    private def parse_function_parameters
      parameters = [] of Identifier
      if peek_token_is? RPAREN
        next_token
        return parameters
      end

      next_token
      token = @cur_token
      parameters << Identifier.new(token, token.literal)

      while peek_token_is? COMMA
        next_token
        next_token
        inner_token = @cur_token
        parameters << Identifier.new(inner_token, inner_token.literal)
      end

      ex_peek RPAREN
      return parameters
    end

    private def parse_call_expression(expression : Expression?)
      token = @cur_token
      arguments = parse_expression_list(RPAREN)
      rexp? CallExpression.new(token, expression, arguments)
    end

    private def parse_expression_list(end_type : TokenType)
      arguments = [] of Expression?
      if peek_token_is? end_type
        next_token
        return arguments
      end

      next_token
      arguments << parse_expression(Precedence::Lowest)

      while peek_token_is? COMMA
        next_token
        next_token

        arguments << parse_expression(Precedence::Lowest)
      end

      ex_peek end_type
      return arguments
    end

    private def parse_index_expression(left : Expression?)
      token = @cur_token
      next_token

      index = parse_expression(Precedence::Lowest)
      ex_peek RBRACKET

      rexp? IndexExpression.new(token, left, index)
    end

    private def parse_hash_literal
      token = @cur_token
      pairs = {} of Expression => Expression
      while !peek_token_is?(RBRACE)
        next_token
        key = parse_expression(Precedence::Lowest)
        ex_peek COLON
        next_token
        value = parse_expression(Precedence::Lowest)
        pairs[key.not_nil!] = value.not_nil!
        if (!peek_token_is?(RBRACE) && !expect_peek?(COMMA))
          return nil
        end
      end
      ex_peek RBRACE
      rexp? HashLiteral.new(token, pairs)
    end

    private def parse_array_literal
      token = @cur_token
      rexp? ArrayLiteral.new(token, parse_expression_list(RBRACKET))
    end

    private def parse_string_literal
      rexp? StringLiteral.new(@cur_token, @cur_token.literal)
    end

    private def no_prefix_parse_error(type : TokenType)
      @errors << "no prefix parser for #{type} function"
    end

    private def peek_token_is?(type : TokenType) : Bool
      @peek_token.type == type
    end

    private def expect_peek?(type : TokenType) : Bool
      if peek_token_is?(type)
        next_token
        true
      else
        peek_error(type)
        false
      end
    end

    private def peek_error(type : TokenType)
      @errors << "Expected next token to be #{type}, got #{@peek_token.type} instead"
    end

    private def cur_precedence : Precedence
      find_precedence(@cur_token.type)
    end

    private def peek_precedence : Precedence
      find_precedence(@peek_token.type)
    end

    private def find_precedence(token_type : TokenType) : Precedence
      PRECEDENCES[token_type]?.or_else(Precedence::Lowest)
    end
  end
end
