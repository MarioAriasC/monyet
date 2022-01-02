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

  def also(& : self | Nil -> _) : self
    yield self
    return self
  end
end

class String
  def substring(start_index : Int, end_index : Int)
    self[start_index, end_index - start_index]
  end
end
