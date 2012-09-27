module DBLeftovers

  class Constraint
    attr_accessor :constraint_name, :on_table, :check

    def initialize(constraint_name, on_table, check)
      @constraint_name = constraint_name
      @on_table = on_table
      @check = check
    end
  end

end
