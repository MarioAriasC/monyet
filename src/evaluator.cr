require "./objects"
require "./ast"

macro error_ret(e)
  if {{e}}.is_error?
    return {{e}}
  end
end

alias MObject = Objects::MObject
alias MInteger = Objects::MInteger
alias MBoolean = Objects::MBoolean
alias MError = Objects::MError
alias MString = Objects::MString
alias MReturnValue = Objects::MReturnValue
alias MFunction = Objects::MFunction
alias MBuiltinFunction = Objects::MBuiltinFunction
alias MArray = Objects::MArray
alias MHash = Objects::MHash
alias MValue = Objects::MValue
alias HashKey = Objects::HashKey
alias HashPair = Objects::HashPair

module Evaluator
  extend self
  include Ast

  NULL     = Objects::MNULL
  MTRUE    = MBoolean.new(true)
  MFALSE   = MBoolean.new(false)
  private BUILTINS = {
    Objects::LEN_NAME   => Objects::LEN_BUILTIN,
    Objects::PUSH_NAME  => Objects::PUSH_BUILTIN,
    Objects::FIRST_NAME => Objects::FIRST_BUILTIN,
    Objects::LAST_NAME  => Objects::LAST_BUILTIN,
    Objects::REST_NAME  => Objects::REST_BUILTIN,
  }

  class Environment
    getter store
    getter outer

    def initialize(@store : Hash(String, MObject), @outer : Environment?)
    end

    def initialize
      initialize({} of String => MObject, nil)
    end

    def initialize(outer : Environment)
      initialize({} of String => MObject, outer)
    end

    def []=(name : String, value : MObject) : MObject
      @store[name] = value
    end

    def []?(name : String) : MObject?
      obj = @store[name]?
      if obj.nil? && !@outer.nil?
        return @outer.not_nil![name]?
      else
        return obj
      end
    end

    # def to_s(io)
    #  io << "Env(store=#{@store}, outer=#{@outer})"
    # end
  end

  def eval(node : Node?, env : Environment) : MObject?
    # pp node
    # pp env
    case node
    when Program
      return eval_program(node.statements, env)
    when ExpressionStatement
      return eval(node.expression?, env)
    when IntegerLiteral
      return MInteger.new(node.value)
    when PrefixExpression
      return eval(node.right?, env).if_not_error do |right|
        eval_prefix_expression(node.operator, right)
      end
    when InfixExpression
      return eval(node.left?, env).if_not_error do |left|
        eval(node.right?, env).if_not_error do |right|
          eval_infix_expression(node.operator, left, right)
        end
      end
    when BooleanLiteral
      return node.value.to_m
    when IfExpression
      return eval_if_expression(node, env)
    when BlockStatement
      return eval_block_statement(node, env)
    when ReturnStatement
      return eval(node.return_value?, env).if_not_error do |value|
        MReturnValue.new(value)
      end
    when LetStatement
      return eval(node.value?, env).if_not_error do |value|
        env[node.name.value] = value
      end
    when CallExpression
      return eval(node.function?, env).if_not_error do |function|
        args = eval_expressions(node.arguments?, env)
        if args.size == 1 && args[0].is_error?
          return args[0]
        else
          apply_function(function, args)
        end
      end
    when Identifier
      return eval_identifier(node, env)
    when FunctionLiteral
      return MFunction.new(node.parameters?, node.body?, env)
    when StringLiteral
      return MString.new(node.value)
    when IndexExpression
      left = eval(node.left?, env)
      error_ret left

      index = eval(node.index?, env)
      error_ret index

      return eval_index_expression(left, index)
    when HashLiteral
      return eval_hash_literal(node, env)
    when ArrayLiteral
      elements = eval_expressions(node.elements?, env)
      if elements.size == 1 && elements[0].is_error?
        return elements[0]
      else
        MArray.new(elements)
      end
    else
      return nil
    end
  end

  private def eval_program(statements : Array(Statement), env : Environment) : MObject?
    result : MObject? = nil
    statements.each do |statement|
      result = eval(statement, env)
      case result
      when MReturnValue
        return result.value
      when MError
        return result
      end
    end
    return result
  end

  private def eval_prefix_expression(operator : String, right : MObject?) : MObject?
    case operator
    when "!"
      return eval_bang_operator_expression(right)
    when "-"
      return eval_minus_prefix_operator_expression(right)
    else
      return MError.new("Unkown operator : #{operator}#{right.type_desc}")
    end
  end

  private def eval_bang_operator_expression(right : MObject?) : MObject
    case right
    when MTRUE
      return MFALSE
    when MFALSE
      return MTRUE
    when NULL
      return MTRUE
    else
      return MFALSE
    end
  end

  private def eval_minus_prefix_operator_expression(right : MObject?) : MObject?
    if right
      case right
      when MInteger
        return -right
      else
        return MError.new("unknown operator: -#{right.type_desc}")
      end
    else
      return nil
    end
  end

  private def eval_infix_expression(operator : String, left : MObject, right : MObject) : MObject
    if left.is_a?(MInteger) && right.is_a?(MInteger)
      return eval_integer_infix_expression(operator, left, right)
    elsif operator == "=="
      return (left == right).to_m
    elsif operator == "!="
      return (left != right).to_m
    elsif left.type_desc != right.type_desc
      return MError.new("type mismatch: #{left.type_desc} #{operator} #{right.type_desc}")
    elsif left.is_a?(MString) && right.is_a?(MString)
      return eval_string_infix_expression(operator, left, right)
    else
      return MError.new("unknown operator: #{left.type_desc} #{operator} #{right.type_desc}")
    end
  end

  private def eval_integer_infix_expression(operator : String, left : MInteger, right : MInteger) : MObject
    case operator
    when "+"
      return left + right
    when "-"
      return left - right
    when "*"
      return left * right
    when "/"
      return left / right
    when "<"
      return (left < right).to_m
    when ">"
      return (left > right).to_m
    when "=="
      return (left == right).to_m
    when "!="
      return (left != right).to_m
    else
      return MError.new("unknown operator: #{left.type_desc} #{operator} #{right.type_desc}")
    end
  end

  private def eval_string_infix_expression(operator : String, left : MString, right : MString) : MObject
    if operator != "+"
      return MError.new("unknown operator: #{left.type_desc} #{operator} #{right.type_desc}")
    else
      return left + right
    end
  end

  private def eval_if_expression(if_expression : IfExpression, env : Environment) : MObject?
    return eval(if_expression.condition?, env).if_not_error do |condition|
      if condition.is_truthy?
        eval(if_expression.consequence?, env)
      elsif !if_expression.alternative?.nil?
        eval(if_expression.alternative?, env)
      else
        NULL
      end
    end
  end

  private def eval_block_statement(block_statement : BlockStatement, env : Environment) : MObject?
    result : MObject? = nil
    block_statement.statements?.not_nil!.each do |statement|
      result = eval(statement, env)
      if !result.nil?
        if result.is_a?(MReturnValue) || result.is_a?(MError)
          return result
        end
      end
    end
    return result
  end

  private def eval_expressions(arguments : Array(Expression?)?, env : Environment) : Array(MObject?)
    return arguments.not_nil!.map do |argument|
      evaluated = eval(argument, env)
      if evaluated.is_error?
        return [evaluated]
      end
      evaluated
    end
  end

  private def eval_identifier(identifier : Identifier, env : Environment) : MObject
    value = env[identifier.value]?
    if value.nil?
      builtin = BUILTINS[identifier.value]?
      if builtin.nil?
        return MError.new("identifier not found: #{identifier.value}")
      else
        return builtin
      end
    else
      return value
    end
  end

  private def eval_index_expression(left : MObject?, index : MObject?) : MObject?
    if left.is_a?(MArray) && index.is_a?(MInteger)
      return eval_array_index_expression(left, index)
    elsif left.is_a?(MHash)
      return eval_hash_index_expression(left, index.not_nil!)
    else
      return MError.new("index operator not supported: #{left.type_desc}")
    end
  end

  private def eval_array_index_expression(array : MArray, index : MInteger) : MObject?
    elements = array.elements
    i = index.value
    max = elements.size - 1

    if (i < 0 || i > max)
      return NULL
    end

    return elements[i]?
  end

  private def eval_hash_index_expression(hash : MHash, index : MObject) : MObject
    case index
    when MValue
      pair = hash.pairs[index.hash_key]?
      if !pair.nil?
        return pair.value
      else
        return NULL
      end
    else
      return MError.new("unusable as a hash key: #{index.type_desc}")
    end
  end

  private def eval_hash_literal(node : HashLiteral, env : Environment) : MObject?
    pairs = {} of HashKey => HashPair

    node.pairs.each do |key_node, value_node|
      key = eval(key_node, env)
      error_ret key

      case key
      when MValue
        value = eval(value_node, env)
        error_ret value
        pairs[key.hash_key] = HashPair.new(key, value.not_nil!)
      else
        return MError.new("unusable as hash key: #{key.type_desc}")
      end
    end

    return MHash.new(pairs)
  end

  private def apply_function(function : MObject, args : Array(MObject?)) : MObject?
    case function
    when MFunction
      extend_env = extend_function_env(function, args)
      evaluated = eval(function.body?, extend_env)
      return unwrap_return_value(evaluated)
    when MBuiltinFunction
      result = function.fn.call(args)
      if result
        return result
      else
        return NULL
      end
    else
      return MError.new("not a function: #{function.type_desc}")
    end
  end

  private def extend_function_env(function : MFunction, args : Array(MObject?)) : Environment
    env = Environment.new(function.env)
    if !function.parameters?.nil?
      function.parameters?.not_nil!.each_with_index do |identifier, i|
        env[identifier.value] = args[i].not_nil!
      end
    end
    return env
  end

  private def unwrap_return_value(obj : MObject?) : MObject?
    case obj
    when MReturnValue
      return obj.value
    else
      return obj
    end
  end
end

module Objects
  abstract class MObject
    def is_truthy? : Bool
      case self
      when Evaluator::NULL
        return false
      when Evaluator::MTRUE
        return true
      when Evaluator::MFALSE
        return false
      else
        return true
      end
    end

    def is_error? : Bool
      self.is_a?(MError)
    end
  end
end

struct Nil
  def if_not_error(&body : Objects::MObject -> Objects::MObject?) : Objects::MObject?
    return self
  end

  def is_truthy : Bool
    return true
  end

  def is_error? : Bool
    false
  end

  def type_desc : String
    "nil"
  end

  def is_truthy? : Bool
    false
  end
end

struct Bool
  def to_m : Objects::MBoolean
    if self
      Evaluator::MTRUE
    else
      Evaluator::MFALSE
    end
  end
end
