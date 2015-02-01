# encoding: utf-8
class Maybe
  ([:each] + Enumerable.instance_methods).each do |enumerable_method|
    define_method(enumerable_method) do |*args, &block|
      res = __enumerable_value.send(enumerable_method, *args, &block)
      res.respond_to?(:each) ? Maybe(res.first) : res
    end
  end

  def to_ary
    __enumerable_value
  end
  alias_method :to_a, :to_ary

  def ==(other)
    other.class == self.class
  end
  alias_method :eql?, :==

  def self.empty_value?(value)
    value.nil? || (value.respond_to?(:length) && value.length == 0)
  end
end

# Represents a non-empty value
class Some < Maybe
  def initialize(value)
    @value = value
  end

  def get
    @value
  end

  def if(&blk)
    blk.call(@value) ? self : None()
  end

  def or_else(*)
    @value
  end

  # rubocop:disable PredicateName
  def is_some?
    true
  end

  def is_none?
    false
  end
  # rubocop:enable PredicateName

  def join
    @value.is_a?(Maybe) ? @value : self
  end

  def join!
    if @value.is_a?(Some)
      @value.join!
    elsif @value.is_a?(None)
      @value
    else
      self
    end
  end

  def ==(other)
    super && get == other.get
  end
  alias_method :eql?, :==

  def ===(other)
    other && other.class == self.class && @value === other.get
  end

  def method_missing(method_sym, *args, &block)
    map { |value| value.send(__strip_leading_underscore(method_sym), *args, &block) }
  end

  private

  def respond_to_missing?(method_sym, include_private = false)
    @value.respond_to?(__strip_leading_underscore(method_sym), include_private) || super
  end

  def __strip_leading_underscore(method_sym)
    if method_sym[0] == "_"
      method_sym = method_sym.slice(1, method_sym.length)
    end
    method_sym
  end

  def __enumerable_value
    [@value]
  end
end

# Represents an empty value
class None < Maybe
  def get
    fail "No such element"
  end

  def or_else(els = nil)
    block_given? ? yield : els
  end

  # rubocop:disable PredicateName
  def is_some?
    false
  end

  def is_none?
    true
  end
  # rubocop:enable PredicateName

  def method_missing(*)
    self
  end

  def respond_to_missing?(method_name, include_private = false)
    true
  end

  private

  def __enumerable_value
    []
  end
end

# rubocop:disable MethodName
def Maybe(value)
  Maybe.empty_value?(value) ? None() : Some.new(value)
end

def Some(value)
  Maybe(value)
end

def None
  None.new
end
# rubocop:enable MethodName
