module DBLeftovers

  class DSL
    def initialize
      @db = DatabaseInterface.new
      @indexes_by_table = {}      # Set from the DSL
      @old_indexes = @db.lookup_all_indexes
      @new_indexes = {}
      
      @foreign_keys_by_table = {}   # Set from the DSL
      @old_foreign_keys = @db.lookup_all_foreign_keys
      @new_foreign_keys = {}
    end

    def define(&block)
      instance_eval(&block)
    end

    def table(table_name, &block)
      table_dsl = TableDSL.new(self, table_name)
      table_dsl.define(&block)
    end

    def index(table_name, column_names, opts={})
      column_names = [column_names].flatten
      # puts "#{table_name}.[#{column_names.join(',')}]"
      add_index(Index.new(table_name, column_names, opts))
    end

    def foreign_key(from_table, from_column, to_table, to_column='id', opts={})
      add_foreign_key(ForeignKey.new(name_constraint(from_table, from_column), from_table, from_column, to_table, to_column, opts))
    end

    def record_indexes
      # First create any new indexes:
      @indexes_by_table.each do |table_name, indexes|
        indexes.each do |idx|
          # puts "#{idx.table_name}.[#{idx.column_names.join(',')}]"
          if index_exists?(idx)
            puts "Index already exists: #{idx.index_name} on #{idx.table_name}"
          else
            @db.execute_add_index(idx)
            puts "Created index: #{idx.index_name} on #{idx.table_name}"
          end
          @new_indexes[truncate_index_name(idx.index_name)] = table_name
        end
      end

      # Now drop any old indexes that are no longer in the definition file:
      @old_indexes.each do |index_name, table_name|
        if not @new_indexes[index_name]
          # puts "#{index_name} #{table_name}"
          @db.execute_drop_index(table_name, index_name)
          puts "Dropped index: #{index_name} on #{table_name}"
        end
      end
    end

    def record_foreign_keys
      # First create any new foreign keys:
      @foreign_keys_by_table.each do |table_name, fks|
        fks.each do |fk|
          if foreign_key_exists?(fk)
            puts "Foreign Key already exists: #{fk.constraint_name} on #{fk.from_table}"
          else
            @db.execute_add_foreign_key(fk)
            puts "Created foreign key: #{fk.constraint_name} on #{fk.from_table}"
          end
          @new_foreign_keys[fk.constraint_name] = fk
        end
      end

      # Now drop any old foreign keys that are no longer in the definition file:
      @old_foreign_keys.each do |constraint_name, fk|
        if not @new_foreign_keys[constraint_name]
          @db.execute_drop_foreign_key(constraint_name, fk.from_table, fk.from_column)
          puts "Dropped foreign key: #{constraint_name} on #{fk.from_table}"
        end
      end
    end

    private

    def add_index(idx)
      t = (@indexes_by_table[idx.table_name] ||= [])
      t << idx
    end

    def add_foreign_key(fk)
      t = (@foreign_keys_by_table[fk.from_table] ||= [])
      t << fk
    end

    def truncate_index_name(index_name)
      index_name[0,63]
    end

    def index_exists?(idx)
      @old_indexes[truncate_index_name(idx.index_name)]
    end

    def foreign_key_exists?(fk)
      @old_foreign_keys[fk.constraint_name]
    end

    def name_constraint(from_table, from_column)
      "fk_#{from_table}_#{from_column}"
    end

  end

end
