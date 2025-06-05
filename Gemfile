source 'https://rubygems.org'

ruby '3.4.4'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails'
# Use postgres as the database for Active Record
gem 'pg'
# Use Puma as the app server
gem 'puma'
gem 'aws-record'
gem 'httparty'
gem 'rubyzip'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'
# Use Redis adapter to run Action Cable in production
# gem 'redis'
# Use ActiveModel has_secure_password
# gem 'bcrypt'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end

group :development do
  gem 'listen'
  gem 'annotate'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen'
  gem 'rubocop', require: false
end

group :test do
  gem 'faker'
  gem 'simplecov', require: false
  gem 'minitest'
  gem 'shoulda-matchers'
  gem 'database_cleaner'
  gem 'rails-controller-testing'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
