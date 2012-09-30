module DBLeftovers

  class TableDSL
    def initialize(dsl, table_name)
      @dsl = dsl
      @table_name = table_name
    end

    def define(&block)
      instance_eval(&block)
    end

    def index(column_names, opts={})
      @dsl.index(@table_name, column_names, opts)
    end

    def foreign_key(from_column=nil, to_table=nil, to_column=nil, opts={})
      @dsl.foreign_key(@table_name, from_column, to_table, to_column, opts)
    end

    def check(constraint_name, check_expression)
      @dsl.check(@table_name, constraint_name, check_expression)
    end
  end

end
