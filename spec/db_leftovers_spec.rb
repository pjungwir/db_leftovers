require 'rails'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

# DBLeftovers::DatabaseInterface.class_eval do
class DBLeftovers::DatabaseInterface

  def initialize
    @@sqls = []
  end

  def self.sqls
    @@sqls
  end

  def execute_sql(sql)
    @@sqls << DBLeftovers::DatabaseInterface.normal_whitespace(sql)
  end

  def self.saw_sql(sql)
    # puts sqls.join("\n\n\n")
    # Don't fail if only the whitespace is different:
    sqls.include?(normal_whitespace(sql))
  end

  def self.starts_with(indexes=[], foreign_keys=[], constraints=[])
    # Convert symbols to strings:
    @@indexes = Hash[indexes.map{|idx| [idx.index_name, idx]}]
    @@foreign_keys = Hash[foreign_keys.map{|fk| [fk.constraint_name, fk]}]
    @@constraints = Hash[constraints.map{|chk| [chk.constraint_name, chk]}]
  end

  def lookup_all_indexes
    @@indexes
  end

  def lookup_all_foreign_keys
    @@foreign_keys
  end

  def lookup_all_constraints
    @@constraints
  end

  private

  def self.normal_whitespace(sql)
    sql.gsub(/\s/m, ' ').gsub(/  +/, ' ').strip
  end

end

RSpec::Matchers.define :have_seen_sql do |sql|
  match do |db|
    db.saw_sql(sql)
  end

  failure_message_for_should do |db|
    "Should have seen...\n#{sql}\n...but instead saw...\n#{db.sqls.join("\n.....\n")}"
  end
end

describe DBLeftovers do

  it "should allow an empty definition" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
    end
    DBLeftovers::DatabaseInterface.sqls.should be_empty
  end

  it "should allow an empty table definition" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
      table :books do
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should be_empty
  end

  it "should create indexes on an empty database" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
      index :books, :shelf_id
      index :books, :publisher_id, :where => 'published'
    end
    DBLeftovers::DatabaseInterface.sqls.size.should == 2
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_shelf_id
        ON books
        (shelf_id)
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_publisher_id
        ON books
        (publisher_id)
        WHERE published
    EOQ
  end



  it "should create table-prefixed indexes on an empty database" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
      table :books do
        index :shelf_id
        index :publisher_id, :where => 'published'
      end
    end
    DBLeftovers::DatabaseInterface.sqls.size.should == 2
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_shelf_id
        ON books
        (shelf_id)
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_publisher_id
        ON books
        (publisher_id)
        WHERE published
    EOQ
  end



  it "should create foreign keys on an empty database" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
      foreign_key :books, :shelf_id, :shelves
      foreign_key :books, :publisher_id, :publishers, :id, :on_delete => :set_null
      foreign_key :books, :author_id, :authors, :id, :on_delete => :cascade
    end
    DBLeftovers::DatabaseInterface.sqls.should have(3).items
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_shelf_id
        FOREIGN KEY (shelf_id)
        REFERENCES shelves (id)
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_publisher_id
        FOREIGN KEY (publisher_id)
        REFERENCES publishers (id)
        ON DELETE SET NULL
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
        ON DELETE CASCADE
    EOQ
  end



  it "should create table-prefixed foreign keys on an empty database" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
      table :books do
        foreign_key :shelf_id, :shelves
        foreign_key :publisher_id, :publishers, :id, :on_delete => :set_null
        foreign_key :author_id, :authors, :id, :on_delete => :cascade
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(3).items
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_shelf_id
        FOREIGN KEY (shelf_id)
        REFERENCES shelves (id)
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_publisher_id
        FOREIGN KEY (publisher_id)
        REFERENCES publishers (id)
        ON DELETE SET NULL
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
        ON DELETE CASCADE
    EOQ
  end



  it "should not create indexes when they already exist" do
    DBLeftovers::DatabaseInterface.starts_with([
      DBLeftovers::Index.new(:books, :shelf_id),
      DBLeftovers::Index.new(:books, :publisher_id, :where => 'published')
    ])
    DBLeftovers::Definition.define do
      index :books, :shelf_id
      index :books, :publisher_id, :where => 'published'
    end
    DBLeftovers::DatabaseInterface.sqls.should have(0).items
  end



  it "should create indexes when they have been redefined" do
    DBLeftovers::DatabaseInterface.starts_with([
      DBLeftovers::Index.new(:books, :shelf_id),
      DBLeftovers::Index.new(:books, :publisher_id, :where => 'published'),
      DBLeftovers::Index.new(:books, :isbn, :unique => true)
    ])
    DBLeftovers::Definition.define do
      index :books, :shelf_id, :where => 'isbn IS NOT NULL'
      index :books, :publisher_id
      index :books, :isbn
    end
    DBLeftovers::DatabaseInterface.sqls.should have(6).items
    DBLeftovers::DatabaseInterface.sqls[0].should =~ /DROP INDEX index_books_on_shelf_id/
    DBLeftovers::DatabaseInterface.sqls[1].should =~ /CREATE\s+INDEX index_books_on_shelf_id/
  end



  it "should not create table-prefixed indexes when they already exist" do
    DBLeftovers::DatabaseInterface.starts_with([
      DBLeftovers::Index.new(:books, :shelf_id),
      DBLeftovers::Index.new(:books, :publisher_id, :where => 'published')
    ])
    DBLeftovers::Definition.define do
      table :books do
        index :shelf_id
        index :publisher_id, :where => 'published'
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(0).items
  end




  it "should not create foreign keys when they already exist" do
    DBLeftovers::DatabaseInterface.starts_with([], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id')
    ])
    DBLeftovers::Definition.define do
      foreign_key :books, :shelf_id, :shelves
    end
    DBLeftovers::DatabaseInterface.sqls.should have(0).items
  end



  it "should not create table-prefixed foreign keys when they already exist" do
    DBLeftovers::DatabaseInterface.starts_with([], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id')
    ])
    DBLeftovers::Definition.define do
      table :books do
        foreign_key :shelf_id, :shelves
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(0).items
  end



  it "should drop indexes when they are removed from the definition" do
    DBLeftovers::DatabaseInterface.starts_with([
       DBLeftovers::Index.new(:books, :shelf_id),
       DBLeftovers::Index.new(:books, :publisher_id, :where => 'published')
    ])
    DBLeftovers::Definition.define do
      index :books, :shelf_id
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        DROP INDEX index_books_on_publisher_id
    EOQ
  end



  it "should drop foreign keys when they are removed from the definition" do
    DBLeftovers::DatabaseInterface.starts_with([], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id'),
      DBLeftovers::ForeignKey.new('fk_books_author_id', 'books', 'author_id', 'authors', 'id')
    ])
    DBLeftovers::Definition.define do
      foreign_key :books, :shelf_id, :shelves
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books DROP CONSTRAINT fk_books_author_id
    EOQ
  end



  it "should create foreign keys when they have been redefined" do
    DBLeftovers::DatabaseInterface.starts_with([], [
      DBLeftovers::ForeignKey.new('fk_books_shelf_id', 'books', 'shelf_id', 'shelves', 'id'),
      DBLeftovers::ForeignKey.new('fk_books_author_id', 'books', 'author_id', 'authors', 'id')
    ])
    DBLeftovers::Definition.define do
      table :books do
        foreign_key :shelf_id, :shelves, :id, :on_delete => :cascade
        foreign_key :author_id, :authors, :id, :on_delete => :set_null
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(4).items
    DBLeftovers::DatabaseInterface.sqls[0].should =~ /ALTER TABLE books DROP CONSTRAINT fk_books_shelf_id/
    DBLeftovers::DatabaseInterface.sqls[1].should =~ /ALTER TABLE books ADD CONSTRAINT fk_books_shelf_id/
    DBLeftovers::DatabaseInterface.sqls[2].should =~ /ALTER TABLE books DROP CONSTRAINT fk_books_author_id/
    DBLeftovers::DatabaseInterface.sqls[3].should =~ /ALTER TABLE books ADD CONSTRAINT fk_books_author_id/
  end



  it "should support creating multi-column indexes" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
      index :books, [:year, :title]
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_year_and_title
        ON books
        (year, title)
    EOQ
  end

  

  it "should support dropping multi-column indexes" do
    DBLeftovers::DatabaseInterface.starts_with([
      DBLeftovers::Index.new(:books, [:year, :title])
    ])
    DBLeftovers::Definition.define do
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        DROP INDEX index_books_on_year_and_title
    EOQ
  end

  

  it "should allow mixing indexes and foreign keys in the same table" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
      table :books do
        index :author_id
        foreign_key :author_id, :authors, :id
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(2).items
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_author_id
        ON books
        (author_id)
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
    EOQ
  end



  it "should allow separating indexes and foreign keys from the same table" do
    DBLeftovers::DatabaseInterface.starts_with
    DBLeftovers::Definition.define do
      table :books do
        index :author_id
      end
      table :books do
        foreign_key :author_id, :authors, :id
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(2).items
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        CREATE INDEX index_books_on_author_id
        ON books
        (author_id)
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
    EOQ
  end

  it "should reject invalid foreign key options" do
    lambda {
      DBLeftovers::Definition.define do
        foreign_key :books, :author_id, :authors, :id, :icky => :boo_boo
      end
    }.should raise_error(RuntimeError, "Unknown option: icky")
  end

  it "should reject invalid foreign key on_delete values" do
    lambda {
      DBLeftovers::Definition.define do
        foreign_key :books, :author_id, :authors, :id, :on_delete => :panic
      end
    }.should raise_error(RuntimeError, "Unknown on_delete option: panic")
  end

  it "should give good a error message if you use the old :set_null option" do
    lambda {
      DBLeftovers::Definition.define do
        foreign_key :books, :author_id, :authors, :id, :set_null => true
      end
    }.should raise_error(RuntimeError, "`:set_null => true` should now be `:on_delete => :set_null`")
  end

  it "should give good a error message if you use the old :cascade option" do
    lambda {
      DBLeftovers::Definition.define do
        foreign_key :books, :author_id, :authors, :id, :cascade => true
      end
    }.should raise_error(RuntimeError, "`:cascade => true` should now be `:on_delete => :cascade`")
  end

  it "should create CHECK constraints on an empty database" do
    DBLeftovers::DatabaseInterface.starts_with([], [], [])
    DBLeftovers::Definition.define do
      check :books, :books_have_positive_pages, 'pages_count > 0'
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT books_have_positive_pages CHECK (pages_count > 0)
    EOQ
  end

  it "should create CHECK constraints inside a table block" do
    DBLeftovers::DatabaseInterface.starts_with([], [], [])
    DBLeftovers::Definition.define do
      table :books do
        check :books_have_positive_pages, 'pages_count > 0'
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT books_have_positive_pages CHECK (pages_count > 0)
    EOQ
  end

  it "should remove obsolete CHECK constraints" do
    DBLeftovers::DatabaseInterface.starts_with([], [], [
      DBLeftovers::Constraint.new(:books_have_positive_pages, :books, 'pages_count > 0')
    ])
    DBLeftovers::Definition.define do
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books DROP CONSTRAINT books_have_positive_pages
    EOQ
  end

  it "should drop and re-create changed CHECK constraints" do
    DBLeftovers::DatabaseInterface.starts_with([], [], [
      DBLeftovers::Constraint.new(:books_have_positive_pages, :books, 'pages_count > 0')
    ])
    DBLeftovers::Definition.define do
      check :books, :books_have_positive_pages, 'pages_count > 12'
    end
    DBLeftovers::DatabaseInterface.sqls.should have(2).items
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books DROP CONSTRAINT books_have_positive_pages
    EOQ
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books ADD CONSTRAINT books_have_positive_pages CHECK (pages_count > 12)
    EOQ
  end

end
