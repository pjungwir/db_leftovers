require 'rails'
require 'active_record'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

def drop_all_mysql_tables(conn, database_name)
  table_names = conn.select_values("SELECT table_name FROM information_schema.tables WHERE table_schema = '#{database_name}'")
  # puts "MySQL drop_all_tables #{table_names.join(',')}"
  conn.execute("SET FOREIGN_KEY_CHECKS = 0")
  table_names.each do |t|
    conn.execute("DROP TABLE IF EXISTS #{t}")   # In MySQL, CASCADE does nothing here.
  end
  conn.execute("SET FOREIGN_KEY_CHECKS = 1")
end

def mysql_config
  test_database_yml(RUBY_PLATFORM == 'java' ? 'jdbcmysql' : 'mysql')
end

describe DBLeftovers::MysqlDatabaseInterface do

  if not mysql_config
    it "WARN: Skipping MySQL tests because no database found. Use spec/config/database.yml to configure one."
  else
    before do
      y = mysql_config
      @conn = test_db_connection(nil, y)
      @db = DBLeftovers::MysqlDatabaseInterface.new(@conn, y['database'])
      drop_all_mysql_tables(@conn, y['database'])
      fresh_tables(@conn, y['database'])
    end

    it_behaves_like "DatabaseInterface"

  end
end

