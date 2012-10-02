$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'rspec/matchers'
require 'db_leftovers'

# Requires supporting files with custom matchers and macros, etc.,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|

end


def test_db_connection(adapter, conf)
  # DBI.connect(dbi_uri(adapter, conf), conf['username'], conf['password'])
  # RDBI.connect(adapter, conf)
  ActiveRecord::Base.establish_connection(conf)
  ActiveRecord::Base.connection
end

# def dbi_uri(adapter, conf)
#   "DBI:#{adapter}:#{conf.select{|k,v| k != 'username' and k != 'password'}.map{|k,v| "#{k}=#{v}"}.join(";")}"
# end

def test_database_yml(database)
  y = YAML.load(File.open(File.join(File.expand_path(File.dirname(__FILE__)), 'config', 'database.yml')))
  y[database]
rescue Errno::ENOENT
  return nil
end


