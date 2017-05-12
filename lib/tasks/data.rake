namespace :data do
  desc "Download and migrate TSE data into DB"
  task :import, [:skip_download, :skip_extract] => :environment do |t, args|
    DataImporter.new(skip_download: args[:skip_download], skip_extract: args[:skip_extract]).call
  end
end
