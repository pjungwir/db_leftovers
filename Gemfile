source "http://rubygems.org"
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

gem 'rails', '>= 3.0.0'
# gem 'rake'
# gem 'activemodel', '= 3.0.11'
# gem 'activesupport', '= 3.0.11'

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "rspec", "~> 2.4.0"
  gem "bundler"
end

group :test do
  gem 'activerecord-postgresql-adapter', :platforms => :ruby
  gem 'activerecord-mysql2-adapter', :platforms => :ruby
  gem 'activerecord-jdbcpostgresql-adapter', :platforms => :jruby
  gem 'activerecord-jdbcmysql-adapter', :platforms => :jruby
end
