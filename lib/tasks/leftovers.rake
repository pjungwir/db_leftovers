namespace :db do

  desc "Set up indexes, foreign keys, and constraints"
  task :leftovers, [] => [:environment] do
    ENV['DB_LEFTOVERS_VERBOSE'] = ENV['VERBOSE'] || ENV['DB_LEFTOVERS_VERBOSE']
    load File.join(::Rails.root.to_s, 'config', 'db_leftovers.rb')
  end

  desc "Drop all the indexes"
  task :drop_indexes, [] => [:environment] do
    DBLeftovers::Definition.define(:do_indexes => true, :do_foreign_keys => false, :do_constraints => false) do
    end
  end

  desc "Drop all the foreign keys"
  task :drop_foreign_keys, [] => [:environment] do
    DBLeftovers::Definition.define(:do_indexes => false, :do_foreign_keys => true, :do_constraints => false) do
    end
  end

  desc "Drop all the constraints"
  task :drop_constraints, [] => [:environment] do
    DBLeftovers::Definition.define(:do_indexes => false, :do_foreign_keys => false, :do_constraints => true) do
    end
  end

end
