
=begin
def drop_all_tables(conn, database_name)
  table_names = conn.select_values("SELECT table_name FROM information_schema.tables WHERE table_catalog = '#{database_name}' AND table_schema NOT IN ('pg_catalog', 'information_schema')")
  table_names.each do |t|
    conn.execute("DROP TABLE IF EXISTS #{t} CASCADE")
  end
end
=end

def fresh_tables(conn, database_name)
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
      CREATE TABLE shelves (
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
          publication_year integer,
          shelf_id integer
      )
  EOQ
end

def start_with(db, indexes=[], foreign_keys=[], constraints=[])
  indexes.each { |idx| db.execute_add_index(idx) }
  foreign_keys.each { |fk| db.execute_add_foreign_key(fk) }
  constraints.each { |chk| db.execute_add_constraint(chk) }
end

shared_examples_for "DatabaseInterface" do

  it "should create indexes on a fresh database" do
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, :shelf_id
      index :books, :isbn, :unique => true
      # Not supported by MYSQL:
      # index :books, :publisher_id, :where => 'publication_year IS NOT NULL'
    end
    @db.lookup_all_indexes.size.should == 2
    @db.lookup_all_indexes.keys.sort.should == ['index_books_on_isbn', 'index_books_on_shelf_id']
  end

  it "should create foreign keys on a fresh database" do
    DBLeftovers::Definition.define :db_interface => @db do
      foreign_key :books, :shelf_id, :shelves
      foreign_key :books, :publisher_id, :publishers, :id, :on_delete => :set_null
      foreign_key :books, :author_id, :authors, :id, :on_delete => :cascade
    end
    @db.lookup_all_foreign_keys.size.should == 3
    @db.lookup_all_foreign_keys.keys.sort.should == ['fk_books_author_id', 'fk_books_publisher_id', 'fk_books_shelf_id']
  end

end
