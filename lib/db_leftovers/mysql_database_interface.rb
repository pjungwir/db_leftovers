module DBLeftovers

  class MysqlDatabaseInterface < GenericDatabaseInterface

    def initialize(conn=nil)
      @conn = conn || ActiveRecord::Base.connection
    end

    def lookup_all_indexes
      # TODO: Constrain it to the database for the current Rails project:
      ret = {}
      @conn.select_values("SHOW TABLES").each do |table_name|
        indexes = {}
        @conn.select_rows("SHOW INDEXES FROM #{table_name}").each do |_, non_unique, key_name, seq_in_index, column_name, collation, cardinality, sub_part, packed, has_nulls, index_type, comment|
          unless key_name == 'PRIMARY'
            # Combine rows for multi-column indexes
            h = (indexes[key_name] ||= { unique: !non_unique, name: key_name, columns: {} })
            h[:columns][seq_in_index.to_i] = column_name
          end
        end

        indexes.each do |index_name, h|
          ret[index_name] = Index.new(
            table_name,
            h[:columns].sort.map{|k, v| v},
            unique: h[:unique],
            name: h[:name]
          )
        end
      end

      return ret
    end

    def lookup_all_foreign_keys
      # TODO: Support multi-column foreign keys:
      # TODO: Constrain it to the database for the current Rails project:
      ret = {}
      sql = <<-EOQ
          SELECT  c.constraint_name,
                  c.table_name,
                  k.column_name,
                  c.referenced_table_name,
                  k.referenced_column_name,
                  c.delete_rule
          FROM    information_schema.referential_constraints c,
                  information_schema.key_column_usage k
          WHERE   c.constraint_schema = k.constraint_schema
          AND     c.constraint_name = k.constraint_name
      EOQ
      @conn.select_rows(sql).each do |constr_name, from_table, from_column, to_table, to_column, del_type|
        del_type = case del_type
                   when 'RESTRICT'; nil
                   when 'CASCADE'; :cascade
                   when 'SET NULL'; :set_null
                   else; raise "Unknown del type: #{del_type}"
                   end
        ret[constr_name] = ForeignKey.new(constr_name, from_table, from_column, to_table, to_column, :on_delete => del_type)
      end
      return ret
    end

    def lookup_all_constraints
      # TODO: Constrain it to the database for the current Rails project:
      # MySQL doesn't support CHECK constraints:
      return []
    end

    def execute_drop_foreign_key(constraint_name, from_table, from_column)
      execute_sql %{ALTER TABLE #{from_table} DROP FOREIGN KEY #{constraint_name}}
    end

  end
end
