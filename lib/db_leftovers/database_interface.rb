module DBLeftovers

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

    def lookup_all_constraints
      ret = {}
      sql = <<-EOQ
          SELECT  t.constraint_name, t.table_name
          FROM    information_schema.table_constraints t
          WHERE   t.constraint_type = 'CHECK'
          AND     EXISTS (SELECT  1
                          FROM    information_schema.constraint_column_usage c
                          WHERE   t.constraint_name = c.constraint_name)
      EOQ
      ActiveRecord::Base.connection.select_rows(sql).each do |constr_name, on_table|
        ret[constr_name] = Constraint.new(constr_name, on_table, nil)
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
      ActiveRecord::Base.connection.execute(sql)
    end

  end

end
