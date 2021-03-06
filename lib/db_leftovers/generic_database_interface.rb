module DBLeftovers

  class GenericDatabaseInterface

    def lookup_all_indexes
      raise "Should be overriden by a database-specific interface"
    end

    def lookup_all_foreign_keys
      raise "Should be overriden by a database-specific interface"
    end

    def lookup_all_constraints
      raise "Should be overriden by a database-specific interface"
    end

    def execute_add_index(idx)
      unique = idx.unique? ? 'UNIQUE' : ''
      where = idx.where_clause.present? ? "WHERE #{idx.where_clause}" : ''
      using = idx.using_clause.present? ? "USING #{idx.using_clause}" : ''

      sql = <<-EOQ
        CREATE #{unique} INDEX #{idx.index_name}
        ON #{idx.table_name}
        #{using}
        (#{idx.index_function || idx.column_names.join(', ')})
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
      on_delete = "ON DELETE CASCADE"  if fk.cascade
      on_delete = "ON DELETE SET NULL" if fk.set_null
      deferrable = "DEFERRABLE INITIALLY DEFERRED"  if fk.deferrable_initially_deferred
      deferrable = "DEFERRABLE INITIALLY IMMEDIATE" if fk.deferrable_initially_immediate
      execute_sql %{ALTER TABLE #{fk.from_table}
                ADD CONSTRAINT #{fk.constraint_name}
                FOREIGN KEY (#{fk.from_column})
                REFERENCES #{fk.to_table} (#{fk.to_column})
                #{on_delete}
                #{deferrable}}
    end

    def execute_drop_foreign_key(constraint_name, from_table, from_column)
      execute_sql %{ALTER TABLE #{from_table} DROP CONSTRAINT #{constraint_name}}
    end

    def execute_add_constraint(chk)
      sql = <<-EOQ
          ALTER TABLE #{chk.on_table} ADD CONSTRAINT #{chk.constraint_name} CHECK (#{chk.check})
      EOQ
      execute_sql sql
    end

    def execute_drop_constraint(constraint_name, on_table)
      execute_sql %{ALTER TABLE #{on_table} DROP CONSTRAINT #{constraint_name}}
    end

    def execute_sql(sql)
      @conn.execute(sql)
    end

  end
end
