require 'rails'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe PostgresDatabaseInterface do

  if not postgres_test_db_config
    it "WARN: Skipping Postgres tests because no database found. Use spec/config/database.yml to configure one."
  else
    before do
      @conn = open_postgres_connection(postgres_test_db_config)
      # TODO: Get connection (@conn), pass it to PostgresDatabaseInterface and the DSL.
      @db = PostgresDatabaseInterface.new
      fresh_tables(@conn)
    end
  end


  def open_postgres_connection(conf)
  end


  def postgres_test_db_config
    y = YAML.load(File.open(File.join(File.expand(__FILE__), 'config', 'database.yml')))
    y['postgres']
  rescue Errno::ENOENT
    return nil
  end

  def fresh_tables(conn)
    # TODO: This won't work because of foreign keys:
    table_names = conn.select_values("SELECT table_name FROM information_schema.tables WHERE table_catalog = #{database_name} AND table_schema NOT IN ('pg_catalog', 'information_schema')").join(", ")
    conn.execute("DROP TABLE #{table_names} CASCADE")
    conn.execute <<-EOQ
        CREATE TABLE publishers (
            id integer PRIMARY KEY,
            name varchar(255)
        )
    EOQ
    conn.execute <<-EOQ
        CREATE TABLE authors (
            id integer PRIMARY KEY,
            name varchar(255)
        )
    EOQ
    conn.execute <<-EOQ
        CREATE TABLE books (
            id integer PRIMARY KEY,
            name varchar(255),
            author_id integer,
            coauthor_id integer,
            publisher_id integer,
            isbn  varchar(255),
            publication_year integer
        )
    EOQ
  end

  def start_with(db, indexes=[], foreign_keys=[], constraints=[])
    indexes.each { |idx| db.execute_add_index(idx) }
    foreign_keys.each { |fk| db.execute_add_foreign_key(fk) }
    constraints.each { |chk| db.execute_add_constraint(chk) }
  end

end

