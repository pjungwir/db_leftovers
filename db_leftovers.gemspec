$:.push File.dirname(__FILE__) + '/lib'
require 'db_leftovers/version'

Gem::Specification.new do |s|
  s.name = "db_leftovers"
  s.version = DbLeftovers::VERSION
  s.date = "2013-01-15"

  s.summary = "Used to define indexes and foreign keys for your Rails app"
  s.description = "        Define indexes and foreign keys for your Rails app\n        in one place using an easy-to-read DSL,\n        then run a rake task to bring your database up-to-date.\n"

  s.authors = ["Paul A. Jungwirth"]
  s.homepage = "http://github.com/pjungwir/db_leftovers"
  s.email = "pj@illuminatedcomputing.com"

  s.licenses = ["MIT"]

  s.require_paths = ["lib"]
  s.executables = []
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,fixtures}/*`.split("\n")

  s.add_runtime_dependency 'rails', '>= 3.0.0'
  s.add_development_dependency 'rspec', '~> 2.4.0'
  s.add_development_dependency 'bundler', '>= 0'

end

