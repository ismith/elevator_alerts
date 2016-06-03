class Object
  def blank?
    nil? || (is_a?(String) && self == '')
  end
end
