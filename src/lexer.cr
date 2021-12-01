require "./token"

module Lexers
  include Tokens
  WHITE_SPACES = [' ', '\t', '\n', '\r']

  class Lexer
    @position = 0
    @read_position = 0
    @ch : Char = Char::ZERO

    def initialize(@input : String)
      self.read_char
    end

    private def read_char
      @ch = peak_char
      @position = @read_position
      @read_position = @read_position + 1
    end

    private def peak_char
      if @read_position >= @input.size
        Char::ZERO
      else
        @input[@read_position]
      end
    end

    private def read_value(&predicate : Char -> Bool) : String
      current_position = @position
      while yield @ch
        read_char
      end
      @input.substring(current_position, @position)
    end

    private def read_number : String
      read_value { |ch| ch.number? }
    end

    private def read_identifier : String
      read_value { |ch| ch.is_identifier? }
    end

    private def read_string : String
      start = @position + 1
      while true
        read_char
        if @ch == '"' || @ch == Char::ZERO
          break
        end
      end
      @input.substring(start, @position)
    end

    private def token(token_type : TokenType) : Token
      Token.new(token_type, @ch)
    end

    private def ends_with_equal(one_char : TokenType, two_chars : TokenType, duplicate_chars = true)
      if (peak_char == '=')
        current_char = @ch
        read_char
        value = if duplicate_chars
                  "#{current_char}#{current_char}"
                else
                  "#{current_char}#{@ch}"
                end
        Token.new(two_chars, value)
      else
        token(one_char)
      end
    end

    private def skip_whitespace
      while WHITE_SPACES.any? { |wp| wp == @ch }
        read_char
      end
    end

    def next_token : Token
      skip_whitespace
      read_next_char = true
      r = nil
      case @ch
      when '='
        r = ends_with_equal(ASSIGN, EQ)
      when ';'
        r = token(SEMICOLON)
      when ':'
        r = token(COLON)
      when ','
        r = token(COMMA)
      when '('
        r = token(LPAREN)
      when ')'
        r = token(RPAREN)
      when '{'
        r = token(LBRACE)
      when '}'
        r = token(RBRACE)
      when '['
        r = token(LBRACKET)
      when ']'
        r = token(RBRACKET)
      when '+'
        r = token(PLUS)
      when '-'
        r = token(MINUS)
      when '*'
        r = token(ASTERISK)
      when '/'
        r = token(SLASH)
      when '<'
        r = token(LT)
      when '>'
        r = token(GT)
      when '!'
        r = ends_with_equal(BANG, NOT_EQ, false)
      when '"'
        r = Token.new(STRING, read_string)
      when Char::ZERO
        r = Token.new(EOF, "")
      else
        case
        when @ch.is_identifier?
          identifier = read_identifier
          return Token.new(identifier.lookup_ident, identifier)
        when @ch.number?
          return Token.new(INT, read_number)
        else
          r = Token.new(ILLEGAL, @ch.to_s)
        end
      end
      read_char
      return r
    end
  end
end

struct Char
  def is_identifier? : Bool
    self.letter? || self == '_'
  end
end
