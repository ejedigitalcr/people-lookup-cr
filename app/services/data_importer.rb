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

  def initialize(options = {})
    @skip_download = options[:skip_download]
    @skip_extract = options[:skip_extract]
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

      counter3 = 0
      newVersion = Hash.new
      CSV.foreach(PEOPLE_FILE_PATH, encoding: CSV_ENCODING) do |line|
        address = addresses[line[1]]
        id = normalize_value(line[0])
        gender = normalize_value(line[2])
        name = normalize_value(line[5])
        last_name_1 = normalize_value(line[6])
        last_name_2 = normalize_value(line[7])
        newVersion[id] = { id: id, address: address, gender: gender, name: name, last_name_1: last_name_1, last_name_2: last_name_2 }

        if counter3 == 200 || counter3 == 500
          puts "loading new data"
        elsif counter3 == 700
          puts "end of test of 700 people"
          break
        end
        counter3 += 1
      end

      if ::File.exist?(OLD_ZIP_PATH)
        puts "existe"
        counter2 = 0
        oldVersion = Hash.new

        FileUtils.mkdir_p(IMPORT_PATH2)

        Zip::File.open(OLD_ZIP_PATH) do |file|
          file.each do |entry|
            if entry.name == "PADRON_COMPLETO.txt"
              entry.extract("#{IMPORT_PATH2}/PADRON_COMPLETO.txt")
              log "Extracting old file"
              
            end
          end
        end

        ::File.rename("#{IMPORT_PATH2}/PADRON_COMPLETO.txt", "#{IMPORT_PATH2}/PADRON_COMPLETO2.txt")

        CSV.foreach(OLD_FILE_NAME, encoding: CSV_ENCODING) do |line|
          address = addresses[line[1]]
          id = normalize_value(line[0])
          gender = normalize_value(line[2])
          name = normalize_value(line[5])
          last_name_1 = normalize_value(line[6])
          last_name_2 = normalize_value(line[7])
          oldVersion[id] = { id: id, address: address, gender: gender, name: name, last_name_1: last_name_1, last_name_2: last_name_2 }
  
          if counter2 == 200 || counter2 == 500
            puts "datos de la versiion antigua ingresandose"
          elsif counter2 == 700
            puts "fin de archivo antiguo probado"
            break
          end
          counter2 += 1

          compare(oldVersion, newVersion)
          
        end

        ::File.delete(OLD_FILE_NAME)

      else
        FileUtils.mkdir_p(IMPORT_PATH2)

        log "saving all data, without compare. There is not a .last zip file"

        log "#{addresses.size} addresses loaded into memory"

        #save all, without compare
        record_count = 0
        CSV.foreach(PEOPLE_FILE_PATH, encoding: CSV_ENCODING) do |line|
          address = addresses[line[1]]
          id = normalize_value(line[0])

          name = normalize_value(line[5])
          last_name_1 = normalize_value(line[6])
          last_name_2 = normalize_value(line[7])
          gender = normalize_value(line[2])

          person = Person.new(
            id: id,
            name: name,
            last_name_1: last_name_1,
            last_name_2: last_name_2,
            gender: gender,
            state: address[:state],
            city: address[:city],
            district: address[:district]
          )
    
          if record_count == 250 || record_count == 500
            puts "datos nuevos ingresandose"
          elsif record_count == 700
            puts "fin de archivo probado"
            break
          end
          record_count += 1
    
          # Force a record overwrite if it exists
          #person.save(force: true)
          #record_count += 1
          # Print a progress report every 100000 records
          # log "#{record_count} records imported" if (record_count % 1000) == 0
        end

      end

      log "Updating digest file..."
      update_digest_file
      cleanup_import_files

      log "Import complete!"
    else
      log "Import file hasn't changed, nothing to do."
    end
  end

  private

    def compare(file1, file2)
      existe = false
      count = 0
      count2 = 0
      (file1.keys & file2.keys).each do |line|
        if (file1[line][:id] == file2[line][:id] && file1[line][:address] == file2[line][:address] && file1[line][:name] == file2[line][:name] &&
          file1[line][:gender] == file2[line][:gender] && file1[line][:last_name_1] == file2[line][:last_name_1] && file1[line][:last_name_2] == file2[line][:last_name_2]) then
          existe = true
          count += 1
          puts "Person already exist"
        else
          existe = false
          count2 += 1

          person = Person.new(
            id: file2[line][:id],
            name: file2[line][:name],
            gender: file2[line][:gender],
            last_name_1: file2[line][:last_name_1],
            last_name_2: file2[line][:last_name_2],
          )
          puts "Adding new Person: #{person.id}"
          #save people to database

        end
        puts "BOOLEAN: #{existe} + contador1: + #{count} + contador2: + #{count2}"
      end
    end

    def normalize_value(value)
      return nil if value.blank?
      value.strip.split.map(&:capitalize).join(' ')
    end

    def log(message)
      puts "#{Time.now.to_s} - #{message}"
    end
end
