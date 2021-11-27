module Utils
end

class Object
  def or_else(alternative)
    if self
      self
    else
      alternative
    end
  end

  def not_null
    if self
      yield self
    end
  end

  def not_null!
    if self
      return self
    else
      raise "Nil Value"
    end
  end
end

class String
  def substring(start_index : Int, end_index : Int)
    self[start_index, end_index - start_index]
  end
end
