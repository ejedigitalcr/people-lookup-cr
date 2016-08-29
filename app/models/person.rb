class Person
  include Aws::Record
  set_table_name "people"

  string_attr :id, hash_key: true
  string_attr  :name
  string_attr :last_name_1
  string_attr :last_name_2
  integer_attr :gender
  string_attr :state
  string_attr :city
  string_attr :district

  def self.find_by_id(id)
    find(id: id)
  end

  def to_param
    id
  end
end
