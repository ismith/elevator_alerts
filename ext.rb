class Object
  def blank?
    nil? || (is_a?(String) && self == '')
  end

  # Stolen from ActiveSupport.  Can be removed & replaced with &. if we move to ruby 2.3+
  def try(*a, &b)
    try!(*a, &b) if a.empty? || respond_to?(a.first)
  end

  # Stolen from ActiveSupport.  Can be removed & replaced with &. if we move to ruby 2.3+
  def try!(*a, &b)
    if a.empty? && block_given?
      if b.arity = 0
        instance_eval(&b)
      else
        yield self
      end
    else
      public_send(*a, &b)
    end
  end
end
