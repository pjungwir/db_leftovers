require 'rails'
require 'active_record'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

def drop_all_postgres_tables(conn, database_name)
  table_names = conn.select_values("SELECT table_name FROM information_schema.tables WHERE table_catalog = '#{database_name}' AND table_schema NOT IN ('pg_catalog', 'information_schema')")
  puts "Postgres drop_all_tables #{table_names.join(',')}"
  if table_names.size > 0
    conn.execute("DROP TABLE #{table_names.join(",")} CASCADE")
  end
end

describe DBLeftovers::PostgresDatabaseInterface do

  if not test_database_yml('postgres')
    it "WARN: Skipping Postgres tests because no database found. Use spec/config/database.yml to configure one."
  else
    before do
       y = test_database_yml('postgres')
      @conn = test_db_connection(nil, y)
      @db = DBLeftovers::PostgresDatabaseInterface.new(@conn)
      drop_all_postgres_tables(@conn, y['database'])
      fresh_tables(@conn, y['database'])
    end

    it_behaves_like "DatabaseInterface"

    it "should create indexes with a WHERE clause" do
      DBLeftovers::Definition.define :db_interface => @db do
        index :books, :publisher_id, :where => 'publication_year IS NOT NULL'
      end
      @db.lookup_all_indexes.size.should == 1
      @db.lookup_all_indexes.keys.sort.should == ['index_books_on_publisher_id']
    end

  end
end

