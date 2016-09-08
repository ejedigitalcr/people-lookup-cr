class ApplicationRecord < ActiveRecord::Base
  class RecordNotFoundError < Exception; end

  self.abstract_class = true
end
