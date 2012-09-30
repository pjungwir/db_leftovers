module DBLeftovers

  class MysqlDatabaseInterface < GenericDatabaseInterface

    def lookup_all_indexes
      ret = {}
      ActiveRecord::Base.connection.select_values("SHOW TABLES").each do |table_name|
        indexes = {}
        ActiveRecord::Base.connection.select_rows("SHOW INDEXES FROM #{table_name}").each do |_, non_unique, key_name, seq_in_index, column_name, collation, cardinality, sub_part, packed, has_nulls, index_type, comment|
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
      raise "stub"
    end

    def lookup_all_constraints
      raise "stub"
    end

  end
end
