require 'rails'
require 'active_record'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

def drop_all_postgres_tables(conn, database_name)
  table_names = conn.select_values("SELECT table_name FROM information_schema.tables WHERE table_catalog = '#{database_name}' AND table_schema NOT IN ('pg_catalog', 'information_schema')")
  # puts "Postgres drop_all_tables #{table_names.join(',')}"
  if table_names.size > 0
    conn.execute("DROP TABLE #{table_names.join(",")} CASCADE")
  end
end

def postgres_config
  test_database_yml(RUBY_PLATFORM == 'java' ? 'jdbcpostgres' : 'postgres')
end

describe DBLeftovers::PostgresDatabaseInterface do

  if not postgres_config
    it "WARN: Skipping Postgres tests because no database found. Use spec/config/database.yml to configure one."
  else
    before do
       y = postgres_config
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

    it "should not create indexes with a WHERE clause when they already exist" do
      starts_with(@db, [
        DBLeftovers::Index.new(:books, :shelf_id),
        DBLeftovers::Index.new(:books, :publisher_id, :where => 'publication_year IS NOT NULL')
      ])
      DBLeftovers::Definition.define :db_interface => @db do
        index :books, :shelf_id
        index :books, :publisher_id, :where => 'publication_year IS NOT NULL'
      end
      @db.lookup_all_indexes.size.should == 2
    end



    it "should redefine indexes when they have a new WHERE clause" do
      starts_with(@db, [
        DBLeftovers::Index.new(:books, :shelf_id),
        DBLeftovers::Index.new(:books, :publisher_id, :where => 'publication_year IS NOT NULL'),
        DBLeftovers::Index.new(:books, :isbn)
      ])
      DBLeftovers::Definition.define :db_interface => @db do
        index :books, :shelf_id, :where => 'name IS NOT NULL'
        index :books, :publisher_id, :where => 'publication_year > 1900'
        index :books, :isbn
      end
      @db.lookup_all_indexes.size.should == 3
      @db.lookup_all_indexes['index_books_on_shelf_id'].where_clause.should == 'name IS NOT NULL'
      @db.lookup_all_indexes['index_books_on_publisher_id'].where_clause.should == 'publication_year > 1900'
    end



    it "should create CHECK constraints on an empty database" do
      starts_with(@db, [], [], [])
      DBLeftovers::Definition.define :db_interface => @db do
        check :books, :books_have_positive_pages, 'pages_count > 0'
      end
      @db.lookup_all_constraints.size.should == 1
      @db.lookup_all_constraints['books_have_positive_pages'].check.should == 'pages_count > 0'
    end



    it "should remove obsolete CHECK constraints" do
      starts_with(@db, [], [], [
        DBLeftovers::Constraint.new(:books_have_positive_pages, :books, 'pages_count > 0')
      ])
      DBLeftovers::Definition.define :db_interface => @db do
      end
      @db.lookup_all_constraints.size.should == 0
    end



    it "should drop and re-create changed CHECK constraints" do
      starts_with(@db, [], [], [
        DBLeftovers::Constraint.new(:books_have_positive_pages, :books, 'pages_count > 0')
      ])
      DBLeftovers::Definition.define :db_interface => @db do
        check :books, :books_have_positive_pages, 'pages_count > 12'
      end
      @db.lookup_all_constraints.size.should == 1
      @db.lookup_all_constraints['books_have_positive_pages'].check.should == 'pages_count > 12'
    end

    it "should allow functional indexes specified as a string" do
      DBLeftovers::Definition.define :db_interface => @db do
        index :authors, 'lower(name)'
      end
      @db.lookup_all_indexes.size.should == 1
      @db.lookup_all_indexes.keys.sort.should == ['index_authors_on_lower_name']
    end

    it "should allow functional indexes specified with an option" do
      DBLeftovers::Definition.define :db_interface => @db do
        index :authors, [], function: 'lower(name)'
      end
      @db.lookup_all_indexes.size.should == 1
      @db.lookup_all_indexes.keys.sort.should == ['index_authors_on_lower_name']
    end

  end
end

