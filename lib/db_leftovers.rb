require 'db_leftovers/dsl.rb'

module DBLeftovers

  class RakeTie < Rails::Railtie
    rake_tasks do
      load 'tasks/leftovers.rake'
    end
  end

end

