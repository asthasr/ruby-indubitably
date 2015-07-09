# encoding: utf-8
# base class for Some and None
class Maybe
  @@none = nil

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

  def or_nil
    or_else(nil)
  end

  def self.concat(list, default = none)
    if default == none
      list.select(&:is_some?).map(&:get)
    else
      list.map { |x| x.or_else(default) }
    end
  end

  def self.empty_value?(value)
    value.nil? || (value.respond_to?(:length) && value.length == 0)
  end

  def self.join?(value)
    return value if value.is_a?(Maybe)
    Maybe(value)
  end

  def self.none
    @@none ||= None.new
  end

  def self.seq(list, default = none)
    Maybe(concat(list, default))
  end
end

# Represents a non-empty value
class Some < Maybe
  alias_method :if, :select

  def initialize(value)
    @value = value
  end

  def get
    @value
  end

  def or_else(*)
    @value
  end

  def if_some(val = nil, &blk)
    Maybe(val.nil? ? blk.call : val)
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

  # This strips the leading underscore if the method is sent with that prefix;
  # this allows us to force dispatch to the contained object. It is inline in
  # two places because this avoids a function call performance hit.
  def method_missing(method_sym, *args, &block)
    method_sym = method_sym.slice(1, method_sym.length) if method_sym[0] == "_"
    map { |value| value.send(method_sym, *args, &block) }
  end

  private

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

  private

  def __enumerable_value
    []
  end
end

# rubocop:disable MethodName
def Maybe(value)
  Maybe.empty_value?(value) ? Maybe.none : Some.new(value)
end

def Some(value)
  Maybe(value)
end

def None
  Maybe.none
end
# rubocop:enable MethodName
