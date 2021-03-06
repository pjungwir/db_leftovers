module DBLeftovers

  class PostgresDatabaseInterface < GenericDatabaseInterface

    def initialize(conn=nil)
      @conn = conn || ActiveRecord::Base.connection
    end

    def lookup_all_indexes
      ret = {}
      sql = <<-EOQ
          SELECT  ix.indexrelid,
                  ix.indrelid,
                  t.relname AS table_name,
                  i.relname AS index_name,
                  ix.indisunique AS is_unique,
                  array_to_string(ix.indkey, ',') AS column_numbers,
                  am.amname AS index_type,
                  pg_get_expr(ix.indpred, ix.indrelid) AS where_clause,
                  pg_get_expr(ix.indexprs, ix.indrelid) AS index_function
          FROM    pg_class t,
                  pg_class i,
                  pg_index ix,
                  pg_namespace n,
                  pg_am am
          WHERE   t.oid = ix.indrelid
          AND     n.oid = t.relnamespace
          AND     i.oid = ix.indexrelid
          AND     t.relkind = 'r'
          AND     n.nspname NOT IN ('pg_catalog', 'pg_toast')
          AND     pg_catalog.pg_table_is_visible(t.oid)
          AND     NOT ix.indisprimary
          AND     i.relam = am.oid
          GROUP BY  t.relname,
                    i.relname,
                    ix.indisunique,
                    ix.indexrelid,
                    ix.indrelid,
                    ix.indkey,
                    am.amname,
                    ix.indpred,
                    ix.indexprs
          ORDER BY t.relname, i.relname
      EOQ
      @conn.select_rows(sql).each do |indexrelid, indrelid, table_name, index_name, is_unique, column_numbers, index_method, where_clause, index_function|
        where_clause = remove_outer_parens(where_clause) if where_clause
        index_method = nil if index_method == 'btree'
        ret[index_name] = Index.new(
          table_name,
          column_names_for_index(indrelid, column_numbers.split(",")),
          unique: is_unique == 't',
          where: where_clause,
          function: index_function,
          using: index_method,
          name: index_name
        )
      end
      return ret
    end



    def lookup_all_foreign_keys
      # confdeltype: a=nil, c=cascade, n=null
      ret = {}
      # TODO: Support multi-column foreign keys:
      sql = <<-EOQ
          SELECT  c.conname,
                  t1.relname AS from_table,
                  a1.attname AS from_column,
                  t2.relname AS to_table,
                  a2.attname AS to_column,
                  c.confdeltype,
                  c.condeferrable AS deferrable,
                  c.condeferred AS deferred
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
      @conn.select_rows(sql).each do |constr_name, from_table, from_column, to_table, to_column, del_type, deferrable, deferred|
        del_type = case del_type
                   when 'a'; nil
                   when 'c'; :cascade
                   when 'n'; :set_null
                   else; raise "Unknown del type: #{del_type}"
                   end
        deferrable = deferrable == 't'
        deferred   = deferred == 't'
        defer_type = if deferrable and deferred; :deferred
                     elsif deferrable; :immediate
                     else; nil
                     end
        ret[constr_name] = ForeignKey.new(from_table, from_column, to_table, to_column, :name => constr_name, :on_delete => del_type, :deferrable => defer_type)
      end
      return ret
    end

    def lookup_all_constraints
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
      @conn.select_rows(sql).each do |constr_name, on_table, check_expr|
        ret[constr_name] = Constraint.new(constr_name, on_table, remove_outer_parens(check_expr))
      end
      return ret
    end

    private

    def column_names_for_index(table_id, column_numbers)
      return [] if column_numbers == ['0']
      column_numbers.map do |c|
        sql = <<-EOQ
            SELECT  attname
            FROM    pg_attribute
            WHERE   attrelid = #{table_id}
            AND     attnum = #{c}
        EOQ
        @conn.select_value(sql)
      end
    end

    def remove_outer_parens(str)
      str ? str.gsub(/^\((.*)\)$/, '\1') : nil
    end

  end
end
