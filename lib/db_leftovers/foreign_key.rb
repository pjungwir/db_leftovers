module DBLeftovers

  class ForeignKey
    attr_accessor :constraint_name, :from_table, :from_column, :to_table, :to_column, :set_null, :cascade

    def initialize(constraint_name, from_table, from_column, to_table, to_column, opts={})
      opts = {
        :on_delete => nil
      }.merge(opts)
      opts.keys.each do |k|
        raise "`:set_null => true` should now be `:on_delete => :set_null`" if k.to_s == 'set_null'
        raise "`:cascade => true` should now be `:on_delete => :cascade`"   if k.to_s == 'cascade'
        raise "Unknown option: #{k}" unless [:on_delete].include?(k)
      end
      raise "Unknown on_delete option: #{opts[:on_delete]}" unless [nil, :set_null, :cascade].include?(opts[:on_delete])
      @constraint_name = constraint_name.to_s
      @from_table = from_table.to_s
      @from_column = from_column.to_s
      @to_table = to_table.to_s
      @to_column = to_column.to_s

      @set_null = opts[:on_delete] == :set_null
      @cascade = opts[:on_delete] == :cascade

      raise "ON DELETE can't be both set_null and cascade" if @set_null and @cascade
    end

    def equals(other)
      other.constraint_name == constraint_name and
      other.from_table == from_table and
      other.from_column == from_column and
      other.to_table == to_table and
      other.to_column == to_column and
      other.set_null == set_null and
      other.cascade == cascade
    end

    def to_s
      "<#{@constraint_name}: from #{@from_table}.#{@from_column} to #{@to_table}.#{@to_column} #{if @set_null; "ON DELETE SET NULL "; elsif @cascade; "ON DELETE CASCADE "; else ""; end}>"
    end

  end

end
