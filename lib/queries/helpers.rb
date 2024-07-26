module Queries::Helpers

  # @params params
  # @params attribute [Symbol]
  # @return [Boolean, nil]
  def boolean_param(params, attribute)
    return nil if attribute.nil? || params[attribute].nil?
    case params[attribute].class.name
    when 'TrueClass', 'FalseClass'
      params[attribute]
    when 'String'
      params[attribute].downcase == 'true' ? true : false
    when 'Symbol'
      params[attribute].to_s.downcase == 'true' ? true : false
    else
      puts Rainbow(params[attribute].class.name.to_s).purple
      raise
    end
  end

  # @params params
  # @params attribute [Symbol]
  # @return [Boolean, nil]
  def integer_param(params, attribute)
    return nil if attribute.nil? || params[attribute].nil?

    [params[attribute]].flatten.each do |v|
      next if Utilities::Strings.only_integer(v)
      raise TaxonWorks::Error::API, "values of #{attribute} must be integers (provided: #{params[attribute]})"
    end
    params[attribute]
  end

end
