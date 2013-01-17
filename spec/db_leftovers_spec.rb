require 'rails'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe DBLeftovers do

  before do
    @db = DBLeftovers::MockDatabaseInterface.new
  end

  it "should allow an empty definition" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
    end
    @db.sqls.should be_empty
  end

  it "should allow an empty table definition" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
      end
    end
    @db.sqls.should be_empty
  end

  it "should create indexes on an empty database" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, :shelf_id
      index :books, :publisher_id, :where => 'published'
    end
    @db.sqls.size.should == 2
    @db.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_shelf_id
        ON books
        (shelf_id)
    EOQ
    @db.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_publisher_id
        ON books
        (publisher_id)
        WHERE published
    EOQ
  end



  it "should create table-prefixed indexes on an empty database" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        index :shelf_id
        index :publisher_id, :where => 'published'
      end
    end
    @db.sqls.size.should == 2
    @db.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_shelf_id
        ON books
        (shelf_id)
    EOQ
    @db.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_publisher_id
        ON books
        (publisher_id)
        WHERE published
    EOQ
  end



  it "should create foreign keys on an empty database" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      foreign_key :books, :shelf_id, :shelves
      foreign_key :books, :publisher_id, :publishers, :id, :on_delete => :set_null
      foreign_key :books, :author_id, :authors, :id, :on_delete => :cascade
    end
    @db.sqls.should have(3).items
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_shelf_id
        FOREIGN KEY (shelf_id)
        REFERENCES shelves (id)
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_publisher_id
        FOREIGN KEY (publisher_id)
        REFERENCES publishers (id)
        ON DELETE SET NULL
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
        ON DELETE CASCADE
    EOQ
  end



  it "should create table-prefixed foreign keys on an empty database" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        foreign_key :shelf_id, :shelves
        foreign_key :publisher_id, :publishers, :id, :on_delete => :set_null
        foreign_key :author_id, :authors, :id, :on_delete => :cascade
      end
    end
    @db.sqls.should have(3).items
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_shelf_id
        FOREIGN KEY (shelf_id)
        REFERENCES shelves (id)
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_publisher_id
        FOREIGN KEY (publisher_id)
        REFERENCES publishers (id)
        ON DELETE SET NULL
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
        ON DELETE CASCADE
    EOQ
  end

  it "should create foreign keys with optional params inferred" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      foreign_key :books, :shelves
      foreign_key :books, :publishers, :on_delete => :set_null
      foreign_key :books, :publication_country_id, :countries
      foreign_key :books, :co_author_id, :authors, :on_delete => :cascade
    end
    @db.sqls.should have(4).items
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT fk_books_shelf_id FOREIGN KEY (shelf_id) REFERENCES shelves (id)
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT fk_books_publisher_id FOREIGN KEY (publisher_id) REFERENCES publishers (id) ON DELETE SET NULL
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT fk_books_publication_country_id
            FOREIGN KEY (publication_country_id) REFERENCES countries (id)
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT fk_books_co_author_id
            FOREIGN KEY (co_author_id) REFERENCES authors (id) ON DELETE CASCADE
    EOQ
  end

  it "should create foreign keys with optional params inferred and table block" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        foreign_key :shelves
        foreign_key :publishers
        foreign_key :publication_country_id, :countries
        foreign_key :co_author_id, :authors, :on_delete => :cascade
      end
    end
    @db.sqls.should have(4).items
  end

  it "should not create indexes when they already exist" do
    @db.starts_with([
      DBLeftovers::Index.new(:books, :shelf_id),
      DBLeftovers::Index.new(:books, :publisher_id, :where => 'published')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, :shelf_id
      index :books, :publisher_id, :where => 'published'
    end
    @db.sqls.should have(0).items
  end



  it "should create indexes when they have been redefined" do
    @db.starts_with([
      DBLeftovers::Index.new(:books, :shelf_id),
      DBLeftovers::Index.new(:books, :publisher_id, :where => 'published'),
      DBLeftovers::Index.new(:books, :isbn, :unique => true)
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, :shelf_id, :where => 'isbn IS NOT NULL'
      index :books, :publisher_id
      index :books, :isbn
    end
    @db.sqls.should have(6).items
    @db.sqls[0].should =~ /DROP INDEX index_books_on_shelf_id/
    @db.sqls[1].should =~ /CREATE\s+INDEX index_books_on_shelf_id/
  end



  it "should not create table-prefixed indexes when they already exist" do
    @db.starts_with([
      DBLeftovers::Index.new(:books, :shelf_id),
      DBLeftovers::Index.new(:books, :publisher_id, :where => 'published')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        index :shelf_id
        index :publisher_id, :where => 'published'
      end
    end
    @db.sqls.should have(0).items
  end




  it "should not create foreign keys when they already exist" do
    @db.starts_with([], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      foreign_key :books, :shelf_id, :shelves
    end
    @db.sqls.should have(0).items
  end



  it "should not create table-prefixed foreign keys when they already exist" do
    @db.starts_with([], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        foreign_key :shelf_id, :shelves
      end
    end
    @db.sqls.should have(0).items
  end



  it "should drop indexes when they are removed from the definition" do
    @db.starts_with([
       DBLeftovers::Index.new(:books, :shelf_id),
       DBLeftovers::Index.new(:books, :publisher_id, :where => 'published')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, :shelf_id
    end
    @db.sqls.should have(1).item
    @db.should have_seen_sql <<-EOQ
        DROP INDEX index_books_on_publisher_id
    EOQ
  end



  it "should drop foreign keys when they are removed from the definition" do
    @db.starts_with([], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id'),
      DBLeftovers::ForeignKey.new('fk_books_author_id', 'books', 'author_id', 'authors', 'id')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      foreign_key :books, :shelf_id, :shelves
    end
    @db.sqls.should have(1).item
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books DROP CONSTRAINT fk_books_author_id
    EOQ
  end



  it "should create foreign keys when they have been redefined" do
    @db.starts_with([], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id'),
      DBLeftovers::ForeignKey.new('fk_books_author_id', 'books', 'author_id', 'authors', 'id')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        foreign_key :shelf_id, :shelves, :id, :on_delete => :cascade
        foreign_key :author_id, :authors, :id, :on_delete => :set_null
      end
    end
    @db.sqls.should have(4).items
    @db.sqls[0].should =~ /ALTER TABLE books DROP CONSTRAINT fk_books_shelf_id/
    @db.sqls[1].should =~ /ALTER TABLE books ADD CONSTRAINT fk_books_shelf_id/
    @db.sqls[2].should =~ /ALTER TABLE books DROP CONSTRAINT fk_books_author_id/
    @db.sqls[3].should =~ /ALTER TABLE books ADD CONSTRAINT fk_books_author_id/
  end



  it "should support creating multi-column indexes" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      index :books, [:year, :title]
    end
    @db.sqls.should have(1).item
    @db.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_year_and_title
        ON books
        (year, title)
    EOQ
  end

  

  it "should support dropping multi-column indexes" do
    @db.starts_with([
      DBLeftovers::Index.new(:books, [:year, :title])
    ])
    DBLeftovers::Definition.define :db_interface => @db do
    end
    @db.sqls.should have(1).item
    @db.should have_seen_sql <<-EOQ
        DROP INDEX index_books_on_year_and_title
    EOQ
  end

  

  it "should allow mixing indexes and foreign keys in the same table" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        index :author_id
        foreign_key :author_id, :authors, :id
      end
    end
    @db.sqls.should have(2).items
    @db.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_author_id
        ON books
        (author_id)
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
    EOQ
  end



  it "should allow separating indexes and foreign keys from the same table" do
    @db.starts_with
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        index :author_id
      end
      table :books do
        foreign_key :author_id, :authors, :id
      end
    end
    @db.sqls.should have(2).items
    @db.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_author_id
        ON books
        (author_id)
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
    EOQ
  end

  it "should reject invalid foreign key options" do
    lambda {
      DBLeftovers::Definition.define :db_interface => @db do
        foreign_key :books, :author_id, :authors, :id, :icky => :boo_boo
      end
    }.should raise_error(RuntimeError, "Unknown option: icky")
  end

  it "should reject invalid foreign key on_delete values" do
    lambda {
      DBLeftovers::Definition.define :db_interface => @db do
        foreign_key :books, :author_id, :authors, :id, :on_delete => :panic
      end
    }.should raise_error(RuntimeError, "Unknown on_delete option: panic")
  end

  it "should give good a error message if you use the old :set_null option" do
    lambda {
      DBLeftovers::Definition.define :db_interface => @db do
        foreign_key :books, :author_id, :authors, :id, :set_null => true
      end
    }.should raise_error(RuntimeError, "`:set_null => true` should now be `:on_delete => :set_null`")
  end

  it "should give good a error message if you use the old :cascade option" do
    lambda {
      DBLeftovers::Definition.define :db_interface => @db do
        foreign_key :books, :author_id, :authors, :id, :cascade => true
      end
    }.should raise_error(RuntimeError, "`:cascade => true` should now be `:on_delete => :cascade`")
  end

  it "should create CHECK constraints on an empty database" do
    @db.starts_with([], [], [])
    DBLeftovers::Definition.define :db_interface => @db do
      check :books, :books_have_positive_pages, 'pages_count > 0'
    end
    @db.sqls.should have(1).item
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT books_have_positive_pages CHECK (pages_count > 0)
    EOQ
  end

  it "should create CHECK constraints inside a table block" do
    @db.starts_with([], [], [])
    DBLeftovers::Definition.define :db_interface => @db do
      table :books do
        check :books_have_positive_pages, 'pages_count > 0'
      end
    end
    @db.sqls.should have(1).item
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT books_have_positive_pages CHECK (pages_count > 0)
    EOQ
  end

  it "should remove obsolete CHECK constraints" do
    @db.starts_with([], [], [
      DBLeftovers::Constraint.new(:books_have_positive_pages, :books, 'pages_count > 0')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
    end
    @db.sqls.should have(1).item
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books DROP CONSTRAINT books_have_positive_pages
    EOQ
  end

  it "should drop and re-create changed CHECK constraints" do
    @db.starts_with([], [], [
      DBLeftovers::Constraint.new(:books_have_positive_pages, :books, 'pages_count > 0')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      check :books, :books_have_positive_pages, 'pages_count > 12'
    end
    @db.sqls.should have(2).items
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books DROP CONSTRAINT books_have_positive_pages
    EOQ
    @db.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT books_have_positive_pages CHECK (pages_count > 12)
    EOQ
  end

  it "should not try to change anything on an ignored table" do
    @db.starts_with([
      DBLeftovers::Index.new(:books, :shelf_id),
    ], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id'),
      DBLeftovers::ForeignKey.new('fk_books_author_id', 'books', 'author_id', 'authors', 'id')
    ], [
      DBLeftovers::Constraint.new(:books_have_positive_pages, :books, 'pages_count > 0')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      ignore :books
    end
    @db.sqls.should have(0).items
  end

  it "should accept multiple ignored tables" do
    @db.starts_with([
      DBLeftovers::Index.new(:books, :shelf_id),
      DBLeftovers::Index.new(:authors, :last_name),
    ], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id'),
      DBLeftovers::ForeignKey.new('fk_books_author_id', 'books', 'author_id', 'authors', 'id')
    ], [
      DBLeftovers::Constraint.new(:books_have_positive_pages, :books, 'pages_count > 0')
    ])
    DBLeftovers::Definition.define :db_interface => @db do
      ignore :books, :authors
    end
    @db.sqls.should have(0).items
  end

  it "should ignore schema_migrations and delayed_jobs by default" do
    @db.starts_with([
      DBLeftovers::Index.new(:schema_migrations, :foo),
      DBLeftovers::Index.new(:delayed_jobs, :bar),
    ], [], [])
    DBLeftovers::Definition.define :db_interface => @db do
    end
    @db.sqls.should have(0).items
  end

  it "should accept `USING` for indexes" do
    @db.starts_with([], [], [])
    DBLeftovers::Definition.define :db_interface => @db do
      index :libraries, :lonlat, using: 'gist'
    end
    @db.sqls.should have(1).item
    @db.should have_seen_sql <<-EOQ
        CREATE INDEX index_libraries_on_lonlat ON libraries USING gist (lonlat)
    EOQ
  end

end
