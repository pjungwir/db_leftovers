module DBLeftovers

  class DatabaseInterface

    def lookup_all_indexes
      ret = {}
      sql = <<-EOQ
          SELECT  ix.indexrelid,
                  ix.indrelid,
                  t.relname AS table_name,
                  i.relname AS index_name,
                  ix.indisunique AS is_unique,
                  array_to_string(ix.indkey, ',') AS column_numbers,
                  pg_get_expr(ix.indpred, ix.indrelid) AS where_clause
          FROM    pg_class t,
                  pg_class i,
                  pg_index ix,
                  pg_namespace n
          WHERE   t.oid = ix.indrelid
          AND     n.oid = t.relnamespace
          AND     i.oid = ix.indexrelid
          AND     t.relkind = 'r'
          AND     n.nspname NOT IN ('pg_catalog', 'pg_toast')
          AND     pg_catalog.pg_table_is_visible(t.oid)
          AND     t.relname NOT IN ('delayed_jobs', 'schema_migrations')
          AND     NOT ix.indisprimary
          GROUP BY  t.relname,
                    i.relname,
                    ix.indisunique,
                    ix.indexrelid,
                    ix.indrelid,
                    ix.indkey,
                    ix.indpred,
          ORDER BY t.relname, i.relname
      EOQ
      ActiveRecord::Base.connection.select_rows(sql).each do |indexrelid, indrelid, table_name, index_name, is_unique, column_numbers, where_clause|
        ret[index_name] = Index.new(
          table_name,
          column_names_for_index(indrelid, column_numbers.split(",")),
          unique: is_unique,
          where: where_clause,
          name: index_name
        )
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

    private

    def column_names_for_index(table_id, column_numbers)
      column_numbers.map do |c|
        sql = <<-EOQ
            SELECT  attname
            FROM    pg_attribute
            WHERE   attrelid = #{table_id}
            AND     attnum = #{c}
        EOQ
        ActiveRecord::Base.connection.select_value(sql)
      end
    end



  end
end
