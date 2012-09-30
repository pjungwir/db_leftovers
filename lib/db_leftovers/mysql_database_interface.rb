module DBLeftovers

  class MysqlDatabaseInterface < GenericDatabaseInterface

    def lookup_all_indexes
      raise "stub"
    end

    def lookup_all_foreign_keys
      raise "stub"
    end

    def lookup_all_constraints
      raise "stub"
    end

  end
end
