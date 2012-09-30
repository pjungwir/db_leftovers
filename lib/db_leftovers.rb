require 'db_leftovers/generic_database_interface.rb'
require 'db_leftovers/postgres_database_interface.rb'
require 'db_leftovers/mysql_database_interface.rb'
require 'db_leftovers/index.rb'
require 'db_leftovers/foreign_key.rb'
require 'db_leftovers/constraint.rb'
require 'db_leftovers/table_dsl.rb'
require 'db_leftovers/dsl.rb'
require 'db_leftovers/definition.rb'

module DBLeftovers

  class RakeTie < Rails::Railtie
    rake_tasks do
      load 'tasks/leftovers.rake'
    end
  end

end

