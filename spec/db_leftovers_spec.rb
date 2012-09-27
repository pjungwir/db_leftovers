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
    @@sqls << sql
  end

  def self.saw_sql(sql)
    # puts sqls.join("\n\n\n")
    # Don't fail if only the whitespace is different:
    sqls.map{|x| x.gsub(/\s+/m, ' ').strip}.include?(
      sql.gsub(/\s+/m, ' ').strip
    )
  end

  def self.starts_with(indexes, foreign_keys, constraints={})
    # Convert symbols to strings:
    @@indexes = indexes.inject({}) do |h, (k, v)| h[k.to_s] = v; h end
    @@foreign_keys = foreign_keys.inject({}) do |h, (k, v)| h[k.to_s] = v; h end
    @@constraints = constraints.inject({}) do |h, (k, v)| h[k.to_s] = v; h end
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
    DBLeftovers::DatabaseInterface.starts_with({}, {})
    DBLeftovers::Definition.define do
    end
    DBLeftovers::DatabaseInterface.sqls.should be_empty
  end

  it "should allow an empty table definition" do
    DBLeftovers::DatabaseInterface.starts_with({}, {})
    DBLeftovers::Definition.define do
      table :books do
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should be_empty
  end

  it "should create indexes on an empty database" do
    DBLeftovers::DatabaseInterface.starts_with({}, {})
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
    DBLeftovers::DatabaseInterface.starts_with({}, {})
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
    DBLeftovers::DatabaseInterface.starts_with({}, {})
    DBLeftovers::Definition.define do
      foreign_key :books, :shelf_id, :shelves
      foreign_key :books, :publisher_id, :publishers, :id, :set_null => true
      foreign_key :books, :author_id, :authors, :id, :cascade => true
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
    DBLeftovers::DatabaseInterface.starts_with({}, {})
    DBLeftovers::Definition.define do
      table :books do
        foreign_key :shelf_id, :shelves
        foreign_key :publisher_id, :publishers, :id, :set_null => true
        foreign_key :author_id, :authors, :id, :cascade => true
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
    DBLeftovers::DatabaseInterface.starts_with({
      :index_books_on_shelf_id => DBLeftovers::Index.new(:books, :index_id),
      :index_books_on_publisher_id => DBLeftovers::Index.new(
        :books, :publisher_id, :where => 'published')
    }, {})
    DBLeftovers::Definition.define do
      index :books, :shelf_id
      index :books, :publisher_id, :where => 'published'
    end
    DBLeftovers::DatabaseInterface.sqls.should have(0).items
  end




  it "should not create table-prefixed indexes when they already exist" do
    DBLeftovers::DatabaseInterface.starts_with({
      :index_books_on_shelf_id => DBLeftovers::Index.new(:books, :index_id),
      :index_books_on_publisher_id => DBLeftovers::Index.new(
        :books, :publisher_id, :where => 'published')
    }, {})
    DBLeftovers::Definition.define do
      table :books do
        index :shelf_id
        index :publisher_id, :where => 'published'
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(0).items
  end




  it "should not create foreign keys when they already exist" do
    DBLeftovers::DatabaseInterface.starts_with({}, {
      :fk_books_shelf_id => DBLeftovers::ForeignKey.new('fk_books_shelf_id',
                                                        'books', 'shelf_id', 'shelves', 'id')
    })
    DBLeftovers::Definition.define do
      foreign_key :books, :shelf_id, :shelves
    end
    DBLeftovers::DatabaseInterface.sqls.should have(0).items
  end



  it "should not create table-prefixed foreign keys when they already exist" do
    DBLeftovers::DatabaseInterface.starts_with({}, {
      :fk_books_shelf_id => DBLeftovers::ForeignKey.new('fk_books_shelf_id',
                                                        'books', 'shelf_id', 'shelves', 'id')
    })
    DBLeftovers::Definition.define do
      table :books do
        foreign_key :shelf_id, :shelves
      end
    end
    DBLeftovers::DatabaseInterface.sqls.should have(0).items
  end



  it "should drop indexes when they are removed from the definition" do
    DBLeftovers::DatabaseInterface.starts_with({
      :index_books_on_shelf_id => DBLeftovers::Index.new(:books, :index_id),
      :index_books_on_publisher_id => DBLeftovers::Index.new(
        :books, :publisher_id, :where => 'published')
    }, {})
    DBLeftovers::Definition.define do
      index :books, :shelf_id
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        DROP INDEX index_books_on_publisher_id
    EOQ
  end



  it "should drop foreign keys when they are removed from the definition" do
    DBLeftovers::DatabaseInterface.starts_with({}, {
      :fk_books_shelf_id => DBLeftovers::ForeignKey.new('fk_books_shelf_id',
                                                        'books', 'shelf_id', 'shelves', 'id'),
      :fk_books_author_id => DBLeftovers::ForeignKey.new('fk_books_author_id',
                                                         'books', 'author_id', 'authors', 'id')
    })
    DBLeftovers::Definition.define do
      foreign_key :books, :shelf_id, :shelves
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        ALTER TABLE books DROP CONSTRAINT fk_books_author_id
    EOQ
  end



  it "should support creating multi-column indexes" do
    DBLeftovers::DatabaseInterface.starts_with({}, {})
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
    DBLeftovers::DatabaseInterface.starts_with({
      :index_books_on_year_and_title => DBLeftovers::Index.new(:books, [:year, :title])
    }, {})
    DBLeftovers::Definition.define do
    end
    DBLeftovers::DatabaseInterface.sqls.should have(1).item
    DBLeftovers::DatabaseInterface.should have_seen_sql <<-EOQ
        DROP INDEX index_books_on_year_and_title
    EOQ
  end

  

  it "should allow mixing indexes and foreign keys in the same table" do
    DBLeftovers::DatabaseInterface.starts_with({}, {})
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
  end

end
