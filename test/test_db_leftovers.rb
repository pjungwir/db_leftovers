require 'rails'
require 'helper'

DBLeftovers::DatabaseInterface.class_eval do

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
    sqls.map{|x| x.gsub(/\s+/m, ' ').strip}.include?(
      sql.gsub(/\s+/m, ' ').strip
    )
  end

end

class TestDbLeftovers < Test::Unit::TestCase

  should "allow an empty definition" do
    DBLeftovers::DatabaseInterface.class_eval do
      def lookup_all_indexes
        {}
      end
      def lookup_all_foreign_keys
        {}
      end
    end
    DBLeftovers::Definition.define do
    end
    assert DBLeftovers::DatabaseInterface.sqls.empty?
  end

  should "create indexes on an empty database" do
    DBLeftovers::DatabaseInterface.class_eval do
      def lookup_all_indexes
        {}
      end
      def lookup_all_foreign_keys
        {}
      end
    end
    DBLeftovers::Definition.define do
      index :books, :shelf_id
      index :books, :publisher_id, :where => 'published'
    end
    assert_equal DBLeftovers::DatabaseInterface.sqls.size, 2
    assert DBLeftovers::DatabaseInterface.saw_sql <<-EOQ
        CREATE INDEX index_books_on_shelf_id
        ON books
        (shelf_id)
    EOQ
    assert DBLeftovers::DatabaseInterface.saw_sql <<-EOQ
        CREATE INDEX index_books_on_publisher_id
        ON books
        (publisher_id)
        WHERE published
    EOQ
  end

  should "create foreign keys on an empty database" do
    DBLeftovers::DatabaseInterface.class_eval do
      def lookup_all_indexes
        {}
      end
      def lookup_all_foreign_keys
        {}
      end
    end
    DBLeftovers::Definition.define do
      foreign_key :books, :shelf_id, :shelves
      foreign_key :books, :publisher_id, :publishers, :id, :set_null => true
      foreign_key :books, :author_id, :authors, :id, :cascade => true
    end
    assert_equal DBLeftovers::DatabaseInterface.sqls.size, 3
    assert DBLeftovers::DatabaseInterface.saw_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_shelf_id
        FOREIGN KEY (shelf_id)
        REFERENCES shelves (id)
    EOQ
    assert DBLeftovers::DatabaseInterface.saw_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_publisher_id
        FOREIGN KEY (publisher_id)
        REFERENCES publishers (id)
        ON DELETE SET NULL
    EOQ
    assert DBLeftovers::DatabaseInterface.saw_sql <<-EOQ
        ALTER TABLE books
        ADD CONSTRAINT fk_books_author_id
        FOREIGN KEY (author_id)
        REFERENCES authors (id)
        ON DELETE CASCADE
    EOQ
  end

  should "not create indexes when they already exist" do
    flunk "TODO"
  end

  should "not create foreign keys when they already exist" do
    flunk "TODO"
  end

  should "drop indexes when they are removed from the definition" do
    flunk "TODO"
  end

  should "drop foreign keys when they are removed from the definition" do
    flunk "TODO"
  end

end
