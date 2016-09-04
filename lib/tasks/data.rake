namespace :data do
  desc "Download and migrate TSE data into DB"
  task import: :environment do
    DataImporter.new.call
  end
end
