namespace :data do
  desc "Download and migrate TSE data into DB"
  task :import, [:skip_download] => :environment do |t, args|
    DataImporter.new.call(skip_download: args[:skip_download])
  end
end
