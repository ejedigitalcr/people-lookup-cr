json.person do
  json.extract! person, :id, :name, :last_name_1, :last_name_2, :gender, :state, :city, :district
end
json.url person_url(person, format: :json)
