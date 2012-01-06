require 'db_leftovers/dsl.rb'

module DBLeftovers

  class RakeTie < Rails::Railtie
    rake_tasks do
      load 'takes/leftovers.rake'
    end
  end

end

