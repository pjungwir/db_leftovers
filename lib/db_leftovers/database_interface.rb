module DBLeftovers

  class DatabaseInterface

    def lookup_all_indexes
      # TODO: Constraint it to the database for the current Rails project:
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
                    ix.indpred
          ORDER BY t.relname, i.relname
      EOQ
      ActiveRecord::Base.connection.select_rows(sql).each do |indexrelid, indrelid, table_name, index_name, is_unique, column_numbers, where_clause|
        where_clause = remove_outer_parens(where_clause) if where_clause
        ret[index_name] = Index.new(
          table_name,
          column_names_for_index(indrelid, column_numbers.split(",")),
          unique: is_unique == 't',
          where: where_clause,
          name: index_name
        )
      end
      return ret
    end



    def lookup_all_foreign_keys
      # confdeltype: a=nil, c=cascade, n=null
      ret = {}
      # TODO: Support multi-column foreign keys:
      # TODO: Constraint it to the database for the current Rails project:
      sql = <<-EOQ
          SELECT  c.conname,
                  t1.relname,
                  a1.attname,
                  t2.relname,
                  a2.attname,
                  c.confdeltype
          FROM    pg_catalog.pg_constraint c,
                  pg_catalog.pg_class t1,
                  pg_catalog.pg_class t2,
                  pg_catalog.pg_attribute a1,
                  pg_catalog.pg_attribute a2,
                  pg_catalog.pg_namespace n1,
                  pg_catalog.pg_namespace n2
          WHERE   c.conrelid = t1.oid
          AND     c.confrelid = t2.oid
          AND     c.contype = 'f'
          AND     a1.attrelid = t1.oid
          AND     a1.attnum = ANY(c.conkey)
          AND     a2.attrelid = t2.oid
          AND     a2.attnum = ANY(c.confkey)
          AND     t1.relkind = 'r'
          AND     t2.relkind = 'r'
          AND     n1.oid = t1.relnamespace
          AND     n2.oid = t2.relnamespace
          AND     n1.nspname NOT IN ('pg_catalog', 'pg_toast')
          AND     n2.nspname NOT IN ('pg_catalog', 'pg_toast')
          AND     pg_catalog.pg_table_is_visible(t1.oid)
          AND     pg_catalog.pg_table_is_visible(t2.oid)
      EOQ
      ActiveRecord::Base.connection.select_rows(sql).each do |constr_name, from_table, from_column, to_table, to_column, del_type|
        del_type = case del_type
                   when 'a'; nil
                   when 'c'; :cascade
                   when 'n'; :set_null
                   else; raise "Unknown del type: #{del_type}"
                   end
        ret[constr_name] = ForeignKey.new(constr_name, from_table, from_column, to_table, to_column, :on_delete => del_type)
      end
      return ret
    end

    def lookup_all_constraints
      # TODO: Constraint it to the database for the current Rails project:
      ret = {}
      sql = <<-EOQ
          SELECT  c.conname,
                  t.relname,
                  pg_get_expr(c.conbin, c.conrelid)
          FROM    pg_catalog.pg_constraint c,
                  pg_catalog.pg_class t,
                  pg_catalog.pg_namespace n
          WHERE   c.contype = 'c'
          AND     c.conrelid = t.oid
          AND     t.relkind = 'r'
          AND     n.oid = t.relnamespace
          AND     n.nspname NOT IN ('pg_catalog', 'pg_toast')
          AND     pg_catalog.pg_table_is_visible(t.oid)
      EOQ
      ActiveRecord::Base.connection.select_rows(sql).each do |constr_name, on_table, check_expr|
        ret[constr_name] = Constraint.new(constr_name, on_table, remove_outer_parens(check_expr))
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

    def remove_outer_parens(str)
      str ? str.gsub(/^\((.*)\)$/, '\1') : nil
    end


  end
end
