module DBLeftovers

  class DSL

    STATUS_EXISTS  = 'exists'
    STATUS_CHANGED = 'changed'
    STATUS_NEW     = 'new'

    def initialize(opts={})
      @verbose = !!opts[:verbose]
      @db = DatabaseInterface.new

      @indexes_by_table = {}      # Set from the DSL
      @old_indexes = @db.lookup_all_indexes
      @new_indexes = {}
      
      @foreign_keys_by_table = {}   # Set from the DSL
      @old_foreign_keys = @db.lookup_all_foreign_keys
      @new_foreign_keys = {}

      @constraints_by_table = {}    # Set from the DSL
      @old_constraints = @db.lookup_all_constraints
      @new_constraints = {}
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

    # foreign_key(from_table, [from_column], to_table, [to_column], [opts]):
    #   foreign_key(:books, :publishers)                   -> foreign_key(:books, nil, :publishers, nil)
    #   foreign_key(:books, :co_author_id, :authors)       -> foreign_key(:books, :co_author_id, :authors, nil)
    #   foreign_key(:books, :publishers, opts)             -> foreign_key(:books, nil, :publishers, nil, opts)
    #   foreign_key(:books, :co_author_id, :authors, opts) -> foreign_key(:books, :co_author_id, :authors, nil, opts)
    def foreign_key(from_table, from_column=nil, to_table=nil, to_column=nil, opts={})
      # First get the options hash into the right place:
      if to_column.class == Hash
        opts = to_column
        to_column = nil
      elsif to_table.class == Hash
        opts = to_table
        to_table = to_column = nil
      end

      # Sort out implicit arguments:
      if from_column and not to_table and not to_column
        to_table = from_column
        from_column = "#{to_table.to_s.singularize}_id"
        to_column = :id
      elsif from_column and to_table and not to_column
        to_column = :id
      end

      add_foreign_key(ForeignKey.new(name_constraint(from_table, from_column), from_table, from_column, to_table, to_column, opts))
    end

    def check(table_name, constraint_name, check_expression)
      add_constraint(Constraint.new(constraint_name, table_name, check_expression))
    end

    def record_indexes
      # First create any new indexes:
      @indexes_by_table.each do |table_name, indexes|
        indexes.each do |idx|
          # puts "#{idx.table_name}.[#{idx.column_names.join(',')}]"
          case index_status(idx)
          when STATUS_EXISTS
            puts "Index already exists: #{idx.index_name} on #{idx.table_name}" if @verbose
          when STATUS_CHANGED
            @db.execute_drop_index(idx.table_name, idx.index_name)
            @db.execute_add_index(idx)
            log_new_index(idx, true)
          when STATUS_NEW
            @db.execute_add_index(idx)
            log_new_index(idx, false)
          end
          @new_indexes[truncate_index_name(idx.index_name)] = table_name
        end
      end

      # Now drop any old indexes that are no longer in the definition file:
      @old_indexes.each do |index_name, idx|
        if not @new_indexes[index_name]
          # puts "#{index_name} #{table_name}"
          @db.execute_drop_index(idx.table_name, index_name)
          puts "Dropped index: #{index_name} on #{idx.table_name}"
        end
      end
    end

    def record_foreign_keys
      # First create any new foreign keys:
      @foreign_keys_by_table.each do |table_name, fks|
        fks.each do |fk|
          case foreign_key_status(fk)
          when STATUS_EXISTS
            puts "Foreign Key already exists: #{fk.constraint_name} on #{fk.from_table}" if @verbose
          when STATUS_CHANGED
            @db.execute_drop_foreign_key(fk.constraint_name, fk.from_table, fk.from_column)
            @db.execute_add_foreign_key(fk)
            puts "Dropped & re-created foreign key: #{fk.constraint_name} on #{fk.from_table}"
          when STATUS_NEW
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

    def record_constraints
      # First create any new constraints:
      @constraints_by_table.each do |table_name, chks|
        chks.each do |chk|
          case constraint_status(chk)
          when STATUS_EXISTS
            puts "Constraint already exists: #{chk.constraint_name} on #{chk.on_table}" if @verbose
          when STATUS_CHANGED
            @db.execute_drop_constraint(chk.constraint_name, chk.on_table)
            @db.execute_add_constraint(chk)
            log_new_constraint(chk, true)
          when STATUS_NEW
            @db.execute_add_constraint(chk)
            log_new_constraint(chk, false)
          end
          @new_constraints[chk.constraint_name] = chk
        end
      end

      # Now drop any old constraints that are no longer in the definition file:
      @old_constraints.each do |constraint_name, chk|
        if not @new_constraints[constraint_name]
          @db.execute_drop_constraint(constraint_name, chk.on_table)
          puts "Dropped CHECK constraint: #{constraint_name} on #{chk.on_table}"
        end
      end
    end

    private

    def log_new_index(idx, altered=false)
      did_what = altered ? "Dropped & re-created" : "Created"
      if idx.where_clause
        # NB: This is O(n*m) where n is your indexes and m is your indexes with WHERE clauses.
        #     But it's hard to believe it matters:
        new_idx = @db.lookup_all_indexes[truncate_index_name(idx.index_name)]
        puts "#{did_what} index: #{idx.index_name} on #{idx.table_name} WHERE #{new_idx.where_clause}"
      else
        puts "#{did_what} index: #{idx.index_name} on #{idx.table_name}"
      end
    end

    def log_new_constraint(chk, altered=false)
      # NB: This is O(n^2) where n is your check constraints.
      #     But it's hard to believe it matters:
      new_chk = @db.lookup_all_constraints[chk.constraint_name]
      puts "#{altered ? "Dropped & re-created" : "Created"} CHECK constraint: #{chk.constraint_name} on #{chk.on_table} as #{new_chk.check}"
    end

    def add_index(idx)
      t = (@indexes_by_table[idx.table_name] ||= [])
      t << idx
    end

    def add_foreign_key(fk)
      t = (@foreign_keys_by_table[fk.from_table] ||= [])
      t << fk
    end

    def add_constraint(chk)
      t = (@constraints_by_table[chk.on_table] ||= [])
      t << chk
    end

    def truncate_index_name(index_name)
      index_name[0,63]
    end

    def index_status(idx)
      old = @old_indexes[truncate_index_name(idx.index_name)]
      if old
        return old.equals(idx) ? STATUS_EXISTS : STATUS_CHANGED
      else
        return STATUS_NEW
      end
    end

    def foreign_key_status(fk)
      old = @old_foreign_keys[fk.constraint_name]
      if old
        return old.equals(fk) ? STATUS_EXISTS : STATUS_CHANGED
      else
        return STATUS_NEW
      end
    end

    def constraint_status(chk)
      old = @old_constraints[chk.constraint_name]
      if old
        return old.equals(chk) ? STATUS_EXISTS : STATUS_CHANGED
      else
        return STATUS_NEW
      end
    end

    def name_constraint(from_table, from_column)
      "fk_#{from_table}_#{from_column}"
    end

  end

end
