module DBLeftovers

  class Constraint
    attr_accessor :constraint_name, :on_table, :check

    def initialize(constraint_name, on_table, check)
      @constraint_name = constraint_name.to_s
      @on_table = on_table.to_s
      @check = check
    end

    def equals(other)
      other.constraint_name == constraint_name and
      other.on_table == on_table and
      other.check == check
    end

    def to_s
      "<#{@constraint_name}: #{@on_table} CHECK (#{@check})>"
    end

  end
end
