require 'faker'
FactoryGirl.define do
  factory :person do |p|
    p.name { Faker::Name.first_name }
    p.last_name_1 { Faker::Name.last_name }
    p.last_name_2 { Faker::Name.last_name }
    p.state { Faker::Address.state }
    p.city { Faker::Address.city }
    p.district { Faker::Address.street_name }
    p.gender { Faker::Number.between(from = 1, to = 2) }
    p.id { Faker::Number.between(from = 1000000, to = 9999999) }
  end
end
