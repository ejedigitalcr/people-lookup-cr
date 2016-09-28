class Person
  include Aws::Record
  include ActiveModel::Validations

  validates :id, :name, :last_name_1, :last_name_2, presence: true
  validates :gender, inclusion: { in: [1, 2] }

  set_table_name "people"

  string_attr :id, hash_key: true
  string_attr :name
  string_attr :last_name_1
  string_attr :last_name_2
  integer_attr :gender
  string_attr :state
  string_attr :city
  string_attr :district

  def self.find_by_id(id)
    find(id: id)
  end

  def self.find_by_id!(id)
    person = find_by_id(id)
    raise  ApplicationRecord::RecordNotFoundError if person.nil?
    person
  end

  def to_param
    id
  end

end
