
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
          shelf_id integer,
          pages_count integer
      )
  EOQ
end

def starts_with(db, indexes=[], foreign_keys=[], constraints=[])
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

  it "should not create indexes when they already exist" do
    starts_with(@db, [
      DBLeftovers::Index.new(:books, :shelf_id),
      DBLeftovers::Index.new(:books, :publisher_id, :unique => true)
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, :shelf_id
      index :books, :publisher_id, :unique => true
    end
    @db.lookup_all_indexes.size.should == 2
  end



  it "should create indexes when they have been redefined" do
    starts_with(@db, [
      DBLeftovers::Index.new(:books, :shelf_id),
      # DBLeftovers::Index.new(:books, :publisher_id, :where => 'published'),
      DBLeftovers::Index.new(:books, :isbn, :unique => true)
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, :shelf_id, :unique => true
      # index :books, :publisher_id
      index :books, :isbn
    end
    @db.lookup_all_indexes.size.should == 2
    @db.lookup_all_indexes['index_books_on_shelf_id'].unique.should == true
    @db.lookup_all_indexes['index_books_on_isbn'].unique.should == false
  end


  it "should drop indexes when they are removed from the definition" do
    starts_with(@db, [
       DBLeftovers::Index.new(:books, :shelf_id),
       DBLeftovers::Index.new(:books, :isbn, :unique => true)
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, :shelf_id
    end
    @db.lookup_all_indexes.size.should == 1
  end



  it "should drop foreign keys when they are removed from the definition" do
    starts_with(@db, [], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id'),
      DBLeftovers::ForeignKey.new('fk_books_author_id', 'books', 'author_id', 'authors', 'id')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      foreign_key :books, :shelf_id, :shelves
    end
    @db.lookup_all_foreign_keys.size.should == 1
  end


  it "should support creating multi-column indexes" do
    starts_with(@db)
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, [:publication_year, :name]
    end
    @db.lookup_all_indexes.size.should == 1
    puts @db.lookup_all_indexes.keys
    @db.lookup_all_indexes.should have_key('index_books_on_publication_year_and_name')
  end

  

  it "should support dropping multi-column indexes" do
    starts_with(@db, [
      DBLeftovers::Index.new(:books, [:publication_year, :name])
    ])
    DBLeftovers::Definition.define :db_interface => @db do
    end
    @db.lookup_all_indexes.size.should == 0
  end


end
