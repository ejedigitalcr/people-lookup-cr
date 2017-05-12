json.status response.status
if @person.present?
  json.partial! "people/person", person: @person
end
