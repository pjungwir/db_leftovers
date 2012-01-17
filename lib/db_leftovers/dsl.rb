module DBLeftovers

  class Definition
    def self.define(opts={}, &block)
      opts = {
        :do_indexes => true,
        :do_foreign_keys => true
      }.merge(opts)
      dsl = DSL.new
      dsl.define(&block)
      dsl.record_indexes        if opts[:do_indexes]
      dsl.record_foreign_keys   if opts[:do_foreign_keys]
    end
  end


  private

  # Just a struct to hold all the info for one index:
  class Index
    attr_accessor :table_name, :column_names, :index_name,
      :where_clause, :unique

    def initialize(table_name, column_names, opts={})
      opts = {
        :where => nil,
        :unique => false,
      }.merge(opts)
      opts.keys.each do |k|
        raise "Unknown option: #{k}" unless [:where, :unique, :name].include?(k)
      end
      @table_name = table_name.to_s
      @column_names = [column_names].flatten.map{|x| x.to_s}
      @where_clause = opts[:where]
      @unique = opts[:unique]
      @index_name = opts[:name] || choose_name(@table_name, @column_names)
    end

    def unique?
      @unique
    end

    private 

    def choose_name(table_name, column_names)
      "index_#{table_name}_on_#{column_names.join('_and_')}"
    end

  end


  class ForeignKey
    attr_accessor :constraint_name, :from_table, :from_column, :to_table, :to_column, :set_null, :cascade

    def initialize(constraint_name, from_table, from_column, to_table, to_column, opts={})
      opts = {
        :set_null => false,
        :cascade => false
      }.merge(opts)
      opts.keys.each do |k|
        raise "Unknown option: #{k}" unless [:set_null, :cascade].include?(k)
      end
      @constraint_name = constraint_name
      @from_table = from_table
      @from_column = from_column
      @to_table = to_table
      @to_column = to_column

      @set_null = opts[:set_null]
      @cascade = opts[:cascade]

      raise "ON DELETE can't be both set_null and cascade" if @set_null and @cascade
    end
  end

  class TableDSL
    def initialize(dsl, table_name)
      @dsl = dsl
      @table_name = table_name
    end

    def define(&block)
      instance_eval(&block)
    end

    def index(column_names, opts={})
      @dsl.index(@table_name, column_names, opts)
    end

    def foreign_key(from_column, to_table, to_column='id', opts={})
      @dsl.foreign_key(@table_name, from_column, to_table, to_column, opts)
    end
  end

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

  class DatabaseInterface

    def lookup_all_indexes
      ret = {}
      sql = <<-EOQ
          SELECT  n.nspname as "Schema", c.relname as "Name",
                  CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'i' THEN 'index' WHEN 'S' THEN 'sequence' WHEN 's' THEN 'special' END as "Type",
                  u.usename as "Owner",
                  c2.relname as "Table"
          FROM    pg_catalog.pg_class c
                  JOIN pg_catalog.pg_index i ON i.indexrelid = c.oid
                  JOIN pg_catalog.pg_class c2 ON i.indrelid = c2.oid
                  LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
                  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE   c.relkind IN ('i','')
          AND     n.nspname NOT IN ('pg_catalog', 'pg_toast')
          AND     pg_catalog.pg_table_is_visible(c.oid)
          AND     c.relname NOT LIKE '%_pkey'
          AND     c2.relname NOT IN ('delayed_jobs', 'schema_migrations')
          ORDER BY 1,2;
      EOQ
      ActiveRecord::Base.connection.select_rows(sql).each do |schema, index_name, object_type, owner, table_name|
        ret[index_name] = table_name
      end
      return ret
    end

    def lookup_all_foreign_keys
      ret = {}
      sql = <<-EOQ
          SELECT  t.constraint_name, t.table_name, k.column_name, t.constraint_type, c.table_name, c.column_name
          FROM    information_schema.table_constraints t,
                  information_schema.constraint_column_usage c,
                  information_schema.key_column_usage k
          WHERE   t.constraint_name = c.constraint_name
          AND     k.constraint_name = c.constraint_name
          AND     t.constraint_type = 'FOREIGN KEY'
      EOQ
      ActiveRecord::Base.connection.select_rows(sql).each do |constr_name, from_table, from_column, constr_type, to_table, to_column|
        ret[constr_name] = ForeignKey.new(constr_name, from_table, from_column, to_table, to_column)
      end
      return ret
    end

    def execute_add_index(idx)
      unique = idx.unique? ? 'UNIQUE' : ''
      where = idx.where_clause.present? ? "WHERE #{idx.where_clause}" : ''

      sql = <<-EOQ
        CREATE #{unique} INDEX #{idx.index_name}
        ON #{idx.table_name}
        (#{idx.column_names.join(', ')})
        #{where}
      EOQ
      execute_sql(sql)
    end

    def execute_drop_index(table_name, index_name)
      sql = <<-EOQ
          DROP INDEX #{index_name}
      EOQ
      execute_sql(sql)
    end

    def execute_add_foreign_key(fk)
      on_delete = "ON DELETE CASCADE" if fk.cascade
      on_delete = "ON DELETE SET NULL" if fk.set_null
      execute_sql %{ALTER TABLE #{fk.from_table}
                ADD CONSTRAINT #{fk.constraint_name}
                FOREIGN KEY (#{fk.from_column})
                REFERENCES #{fk.to_table} (#{fk.to_column})
                #{on_delete}}
    end

    def execute_drop_foreign_key(constraint_name, from_table, from_column)
      execute_sql %{ALTER TABLE #{from_table}
                DROP CONSTRAINT #{constraint_name}}
    end

    def execute_sql(sql)
      ActiveRecord::Base.connection.execute(sql)
    end

  end

end
