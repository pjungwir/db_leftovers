module DBLeftovers

  class ForeignKey
    attr_accessor :constraint_name, :from_table, :from_column, :to_table, :to_column, :set_null, :cascade

    def initialize(constraint_name, from_table, from_column, to_table, to_column, opts={})
      opts = {
        :set_null => false,
        :cascade => false
      }.merge(opts)
      opts.keys.each do |k|
        raise "Unknown option: #{k}" unless [:set_null, :cascade].include?(k)
      end
      @constraint_name = constraint_name.to_s
      @from_table = from_table.to_s
      @from_column = from_column.to_s
      @to_table = to_table.to_s
      @to_column = to_column.to_s

      @set_null = opts[:set_null]
      @cascade = opts[:cascade]

      raise "ON DELETE can't be both set_null and cascade" if @set_null and @cascade
    end
  end

end
