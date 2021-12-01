require "string_pool"
require "./evaluator"
require "./ast"

macro define_type_desc
  def type_desc : String
    return {{ @type.stringify }}
  end
end

module Objects
  extend self
  include Ast
  MNULL = MNull.new

  private POOL = StringPool.new

  enum HashType
    Integer
    Boolean
    String
  end

  struct HashKey
    getter hash_type
    getter value

    def initialize(@hash_type : HashType, @value : UInt64)
    end
  end

  struct HashPair
    getter key
    getter value

    def initialize(@key : MObject, @value : MObject)
    end
  end

  abstract class MObject
    abstract def type_desc : String
    abstract def inspect : String

    def if_not_error(& : MObject -> MObject?) : MObject?
      case self
      when MError
        return self
      else
        return yield self
      end
    end
  end

  abstract class MValue(T) < MObject
    getter value

    def initialize(@value : T)
    end

    def inspect : String
      return "#{@value}"
    end

    abstract def hash_type : HashType

    abstract def hash_key : HashKey
  end

  class MInteger < MValue(Int64)
    def hash_type : HashType
      return HashType::Integer
    end

    def - : self
      return MInteger.new(-@value)
    end

    def +(other : MInteger)
      return MInteger.new(@value + other.value)
    end

    def -(other : MInteger)
      return MInteger.new(@value - other.value)
    end

    def *(other : MInteger)
      return MInteger.new(@value * other.value)
    end

    def /(other : MInteger)
      return MInteger.new((@value / other.value).to_i64)
    end

    def <(other : MInteger)
      return @value < other.value
    end

    def >(other : MInteger)
      return @value > other.value
    end

    def same?(other : MInteger)
      return @value == other.value
    end

    define_type_desc

    def hash_key : HashKey
      return HashKey.new(hash_type, @value.to_u64)
    end
  end

  class MReturnValue < MObject
    getter value

    def initialize(@value : MObject)
    end

    def inspect : String
      return @value.inspect
    end

    define_type_desc
  end

  class MError < MObject
    getter message

    def initialize(@message : String)
    end

    def inspect : String
      return "ERROR: #{@message}"
    end

    def to_s(io)
      io << "MError(message=#{@message})"
    end

    define_type_desc
  end

  class MNull < MObject
    def inspect : String
      return "null"
    end

    define_type_desc
  end

  class MBoolean < MValue(Bool)
    def hash_type : HashType
      return HashType::Boolean
    end

    def same?(other)
      case other
      when MBoolean
        return other.value == @value
      else
        return false
      end
    end

    # def object_id
    #  @value.object_id
    # end

    define_type_desc

    def hash_key : HashKey
      return HashKey.new(hash_type, (@value ? 1 : 0).to_u64)
    end
  end

  class MString < MValue(String)
    def +(other : MString) : MString
      return MString.new(value + other.value)
    end

    def hash_type : HashType
      return HashType::String
    end

    define_type_desc

    def hash_key : HashKey
      @value = POOL.get(@value)
      return HashKey.new(hash_type, @value.object_id)
    end
  end

  class MFunction < MObject
    getter? parameters
    getter? body
    getter env

    def initialize(@parameters : Array(Identifier)?, @body : BlockStatement?, @env : Evaluator::Environment)
    end

    def inspect : String
      parameters = ""
      if !@parameters.nil?
        parameters = @parameters.not_nil!.map { |parameter| "#{parameter}" }.join(", ")
      end
      return "fn(#{parameters}) {\n\t#{@body}\n}"
    end

    define_type_desc
  end

  alias BuiltinFunction = Array(MObject?) -> MObject?

  class MBuiltinFunction < MObject
    getter fn

    def initialize(@fn : BuiltinFunction)
    end

    def inspect : String
      return "builtin function"
    end

    define_type_desc
  end

  class MArray < MObject
    getter elements

    def initialize(@elements : Array(MObject?))
    end

    def inspect : String
      return "[#{elements.join(", ")}]"
    end

    define_type_desc
  end

  class MHash < MObject
    getter pairs

    def initialize(@pairs : Hash(HashKey, HashPair))
    end

    def inspect : String
      return "{#{@pairs.values.map { |pair| "#{pair.key.inspect}: #{pair.value.inspect}" }}}"
    end

    define_type_desc
  end

  private def arg_size_check(expected_size : Int32, args : Array(MObject?), &body : BuiltinFunction) : MObject?
    length = args.size
    if length != expected_size
      return MError.new("wrong number of arguments. got=#{length}, want=#{expected_size}")
    else
      return body.call(args)
    end
  end

  private def array_check(builtin_name : String, args : Array(MObject?), &body : (MArray, Int32) -> MObject?) : MObject?
    if !args[0].is_a?(MArray)
      return MError.new("argument to `#{builtin_name}` must be ARRAY, got #{args[0].type_desc}")
    else
      array = args[0].as(MArray)
      return body.call(array, array.elements.size)
    end
  end

  private def len(args : Array(MObject?)) : MObject?
    return arg_size_check(1, args) do |arguments|
      arg = arguments[0]
      case arg
      when MString
        MInteger.new(arg.value.size.to_i64)
      when MArray
        MInteger.new(arg.elements.size.to_i64)
      else
        MError.new("argument to `len` not supported, got #{arg.type_desc}")
      end
    end
  end

  private def push(args : Array(MObject?)) : MObject?
    return arg_size_check(2, args) do |arguments|
      array_check(PUSH_NAME, arguments) do |array, _|
        MArray.new(array.elements << args[1])
      end
    end
  end

  private def first(args : Array(MObject?)) : MObject?
    return arg_size_check(1, args) do |arguments|
      array_check(FIRST_NAME, arguments) do |array, length|
        if length > 0
          array.elements[0]
        else
          nil
        end
      end
    end
  end

  private def last(args : Array(MObject?)) : MObject?
    return arg_size_check(1, args) do |arguments|
      array_check(LAST_NAME, arguments) do |array, length|
        if length > 0
          array.elements.last
        else
          nil
        end
      end
    end
  end

  private def rest(args : Array(MObject?)) : MObject?
    return arg_size_check(1, args) do |arguments|
      array_check(REST_NAME, arguments) do |array, length|
        if length > 0
          array.elements.delete_at(0)
          MArray.new(array.elements)
        else
          nil
        end
      end
    end
  end

  LEN_NAME      = "len"
  PUSH_NAME     = "push"
  FIRST_NAME    = "first"
  LAST_NAME     = "last"
  REST_NAME     = "rest"
  LEN_BUILTIN   = MBuiltinFunction.new(->len(Array(MObject?)))
  PUSH_BUILTIN  = MBuiltinFunction.new(->push(Array(MObject?)))
  FIRST_BUILTIN = MBuiltinFunction.new(->first(Array(MObject?)))
  LAST_BUILTIN  = MBuiltinFunction.new(->last(Array(MObject?)))
  REST_BUILTIN  = MBuiltinFunction.new(->rest(Array(MObject?)))
end
