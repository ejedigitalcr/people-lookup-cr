require 'zip'

class DataImporter
  REMOTE_ZIP_PATH = "http://www.tse.go.cr/zip/padron/padron_completo.zip"
  IMPORT_PATH = "tmp/data_import"
  ZIP_FILE_PATH = "#{IMPORT_PATH}/data.zip"
  DIGEST_FILE_PATH = "#{IMPORT_PATH}/last_digest.md5"
  PEOPLE_FILE_NAME = "PADRON_COMPLETO.txt"
  PEOPLE_FILE_PATH = "#{IMPORT_PATH}/#{PEOPLE_FILE_NAME}"
  ADDRESSES_FILE_NAME = "Distelec.txt"
  ADDRESSES_FILE_PATH = "#{IMPORT_PATH}/#{ADDRESSES_FILE_NAME}"
  CSV_ENCODING = "iso-8859-1:utf-8"

  IMPORT_PATH2 = "tmp/data_import/old"
  PEOPLE_FILE_PATH2 = "#{IMPORT_PATH2}/#{PEOPLE_FILE_NAME}"
  OLD_ZIP_PATH = "#{ZIP_FILE_PATH}.last"
  OLD_FILE_NAME = "#{IMPORT_PATH2}/PADRON_COMPLETO2.txt"

  class File
    class << self
      # Download a remote file to a local path
      def download(remote_path, local_path)
        file = ::File.new(local_path, "w")
        file.binmode
        file.write(HTTParty.get(remote_path).body)
        file.close
        file
      end

      def open(local_path)
        ::File.new(local_path, "r")
      end

      # Extract a ZIP file into a specific path
      def extract(zip_file, target_path, entries = [])
        Zip::File.open(zip_file) do |file|
          file.each do |entry|
            if entries.empty? || entries.include?(entry.name)
              entry.extract("#{target_path}/#{entry.name}")
            end
          end
        end
      end

      def calculate_digest(file)
        sha256 = Digest::SHA256.file(file)
        sha256.hexdigest
      end
    end
  end

  def set_options(options = {})
    @skip_download = !!options[:skip_download] if options[:skip_download].present?
    @skip_extract = !!options[:skip_extract] if options[:skip_extract].present?
    @verbose = !!options[:verbose] if options[:verbose].present?
    @dry_run = !!options[:dry_run] if options[:dry_run].present?
  end

  def initialize(options = {})
    set_options(options)
  end

  def file_changed?(file_path = ZIP_FILE_PATH)
    @digest ||= DataImporter::File.calculate_digest(file_path)
    changed = true
    if ::File.exist?(DIGEST_FILE_PATH)
      file = ::File.new("#{file_path}.last","r")
      sha256 = DataImporter::File.calculate_digest(file)
      changed = (sha256 != @digest)
    end
    changed
  end

  def update_digest_file(digest = @digest)
    file = ::File.new(DIGEST_FILE_PATH, "w")
    file.write(digest)
    file.close
  end

  def cleanup_import_files
    # Rename ZIP file to keep track of the last version
    ::File.rename(ZIP_FILE_PATH, "#{ZIP_FILE_PATH}.last")
    ::File.delete(PEOPLE_FILE_PATH, ADDRESSES_FILE_PATH)
  end

  # Import steps:
  # - Download ZIP file from TSE and save it to tmp/data_import/data.zip
  # - Calculate ZIP file digest and compare it with the last version stored
  #   in tmp/data_import/last_digest.md5
  # - If digest is different:
  #   - Extract files to tmp/data_import/
  #   - Iterate through tmp/data_import/Distelec.txt and store the address data
  #     in a hash
  #   - Iterate through tmp/data_import/PADRON_COMPLETO.txt and store each row along with
  #     the address data from the hash
  #   - If the import is successful, replace tmp/data_import/last_digest.md5
  #     with the digest from the recently imported file
  def call(options = {})
    set_options(options)

    # Create import path if it doesn't exist
    FileUtils.mkdir_p(IMPORT_PATH)

    if @skip_download
      @file = DataImporter::File.open(ZIP_FILE_PATH)
    else
      log "Downloading #{REMOTE_ZIP_PATH}..."
      @file = DataImporter::File.download(REMOTE_ZIP_PATH, ZIP_FILE_PATH)
    end

    log "Importing file #{ZIP_FILE_PATH}"
    if @skip_download || file_changed?
      unless @skip_extract
        log "Extracting files..."
        DataImporter::File.extract(ZIP_FILE_PATH, IMPORT_PATH,
                                   [PEOPLE_FILE_NAME, ADDRESSES_FILE_NAME])
      end

      counter = 0
      log "Loading addresses..."
      addresses = Hash.new
      CSV.foreach(ADDRESSES_FILE_PATH, encoding: CSV_ENCODING) do |line|
        state = normalize_value(line[1])
        city = normalize_value(line[2])
        district = normalize_value(line[3])
        addresses[line[0]] = { state: state, city: city, district: district }
      end
      log "#{addresses.size} addresses loaded into memory"
      debug "Addresses:\n#{addresses.inspect}"

      record_count = 0
      bulk_size = 1000

      if ::File.exist?(OLD_ZIP_PATH)
        new_version = Hash.new
        CSV.foreach(PEOPLE_FILE_PATH, encoding: CSV_ENCODING) do |line|
          address = addresses[line[1]]
          id = normalize_value(line[0])
          gender = normalize_value(line[2])
          name = normalize_value(line[5])
          last_name_1 = normalize_value(line[6])
          last_name_2 = normalize_value(line[7])
          new_version[id] = { id: id, address: address, gender: gender, name: name, last_name_1: last_name_1, last_name_2: last_name_2 }
        end

        old_version = Hash.new

        log "Extracting old files"
        FileUtils.mkdir_p(IMPORT_PATH2)
        Zip::File.open(OLD_ZIP_PATH) do |file|
          file.each do |entry|
            if entry.name == "PADRON_COMPLETO.txt"
              entry.extract("#{IMPORT_PATH2}/PADRON_COMPLETO.txt")
            end
          end
        end

        ::File.rename("#{IMPORT_PATH2}/PADRON_COMPLETO.txt", "#{IMPORT_PATH2}/PADRON_COMPLETO2.txt")

        log "Comparing new data with old data and saving the differences"
        CSV.foreach(OLD_FILE_NAME, encoding: CSV_ENCODING) do |line|
          address = addresses[line[1]]
          id = normalize_value(line[0])
          gender = normalize_value(line[2])
          name = normalize_value(line[5])
          last_name_1 = normalize_value(line[6])
          last_name_2 = normalize_value(line[7])
          old_version[id] = { id: id, address: address, gender: gender, name: name, last_name_1: last_name_1, last_name_2: last_name_2 }

          compare_and_update(old_version, new_version)

          record_count += 1
          # Print a progress report every 1000 records
          log "#{record_count} records imported" if (record_count % bulk_size) == 0
        end

        ::File.delete(OLD_FILE_NAME)

      else
        log "Saving all data without comparing (there is not a .last zip file)"

        threads = []
        CSV.foreach(PEOPLE_FILE_PATH, encoding: CSV_ENCODING) do |line|
          address = addresses[line[1]]
          id = normalize_value(line[0])
          gender = normalize_value(line[2])
          name = normalize_value(line[5])
          last_name_1 = normalize_value(line[6])
          last_name_2 = normalize_value(line[7])

          person_info = {
            id: id,
            name: name,
            last_name_1: last_name_1,
            last_name_2: last_name_2,
            gender: gender,
            state: address[:state],
            city: address[:city],
            district: address[:district]
          }
          person = Person.new(person_info)
          #debug "Adding/updating person: #{person_info.inspect}"
          unless @dry_run
            threads << Thread.new do
              # Force a record overwrite if it exists
              person.save(force: true)
            end
          end
          record_count += 1
          if (record_count % bulk_size) == 0
            threads.each(&:join)
            # Print a progress report every 1000 records
            log "#{record_count} records imported"
            threads.clear
          end
        end

      end

      log "Updating digest file and final cleanup..."
      update_digest_file
      cleanup_import_files

      log "Import complete!"
    else
      log "Import file hasn't changed, nothing to do."
    end
  end

  private

    def compare_and_update(file1, file2)
      (file1.keys & file2.keys).each do |id|
        file1_info = file1[id]
        file2_info = file2[id]
        if file1_info[:id] == file2_info[:id] &&
          file1_info[:address] == file2_info[:address] &&
          file1_info[:name] == file2_info[:name] &&
          file1_info[:gender] == file2_info[:gender] &&
          file1_info[:last_name_1] == file2_info[:last_name_1] &&
          file1_info[:last_name_2] == file2_info[:last_name_2]
          debug "Person already exists: #{file1_info.inspect}"
        else
          new_person_info = {
            id: file2_info[:id],
            name: file2_info[:name],
            gender: file2_info[:gender],
            last_name_1: file2_info[:last_name_1],
            last_name_2: file2_info[:last_name_2],
            state: file2_info[:address][:state],
            city: file2_info[:address][:city],
            district: file2_info[:address][:district]
          }
          person = Person.new(new_person_info)
          debug "Adding/updating person: #{new_person_info.inspect}"
          # Save person to database
          person.save(force: true) unless @dry_run
        end
      end
    end

    def normalize_value(value)
      return nil if value.blank?
      value.strip.split.map(&:capitalize).join(' ')
    end

    def log(message)
      puts "#{Time.now.to_s} - #{message}"
    end

    def debug(message)
      log(message) if @verbose
    end
end
