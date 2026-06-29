class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def iso_time(value)
    value&.iso8601
  end
end
