namespace :db do

  desc "Set up indexes and foreign keys"
  task :leftovers, [] => [:environment] do
    load File.join(::Rails.root.to_s, 'config', 'db_leftovers.rb')
  end

  desc "Drop all the indexes"
  task :drop_indexes, [] => [:environment] do
    DBLeftovers::Definition.define(:do_indexes => true, :do_foreign_keys => false) do
    end
  end

  desc "Drop all the foreign keys"
  task :drop_foreign_keys, [] => [:environment] do
    DBLeftovers::Definition.define(:do_indexes => false, :do_foreign_keys => true) do
    end
  end

end
