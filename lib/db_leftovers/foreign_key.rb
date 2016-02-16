module DBLeftovers

  class ForeignKey
    attr_accessor :constraint_name, :from_table, :from_column, :to_table, :to_column, :set_null, :cascade, :deferrable_initially_immediate, :deferrable_initially_deferred

    def initialize(from_table, from_column, to_table, to_column, opts={})
      opts = {
        :deferrable => nil,
        :on_delete => nil,
        :name => name_constraint(from_table, from_column)
      }.merge(opts)
      opts.keys.each do |k|
        raise "`:set_null => true` should now be `:on_delete => :set_null`" if k.to_s == 'set_null'
        raise "`:cascade => true` should now be `:on_delete => :cascade`"   if k.to_s == 'cascade'
        raise "Unknown option: #{k}" unless [:on_delete, :name, :deferrable].include?(k)
      end
      raise "Unknown on_delete option: #{opts[:on_delete]}" unless [nil, :set_null, :cascade].include?(opts[:on_delete])
      raise "Unknown deferrable option: #{opts[:deferrable]}" unless [nil, :immediate, :deferred].include?(opts[:deferrable])
      @constraint_name = opts[:name].to_s
      @from_table = from_table.to_s
      @from_column = from_column.to_s
      @to_table = to_table.to_s
      @to_column = to_column.to_s

      @set_null = opts[:on_delete] == :set_null
      @cascade  = opts[:on_delete] == :cascade
      @deferrable_initially_immediate = opts[:deferrable] == :immediate
      @deferrable_initially_deferred  = opts[:deferrable] == :deferred

      raise "ON DELETE can't be both set_null and cascade" if @set_null and @cascade
      raise "DEFERRABLE can't be both immediate and deferred" if @deferrable_initially_immediate and @deferrable_initially_deferred
    end

    def equals(other)
      other.constraint_name == constraint_name and
      other.from_table == from_table and
      other.from_column == from_column and
      other.to_table == to_table and
      other.to_column == to_column and
      other.set_null == set_null and
      other.cascade == cascade and
      other.deferrable_initially_immediate == deferrable_initially_immediate and
      other.deferrable_initially_deferred == deferrable_initially_deferred
    end

    def to_s
      [
        "<#{@constraint_name}: from #{@from_table}.#{@from_column} to #{@to_table}.#{@to_column}",
        if @set_null; "ON DELETE SET NULL"
        elsif @cascade; "ON DELETE CASCADE"
        else; nil
        end,
        if @deferrable_initially_immediate; "DEFERRABLE INITIALLY IMMEDIATE"
        elsif @deferrable_initially_deferred; "DEFERRABLE INITIALLY DEFERRED"
        else; nil
        end,
        ">"
      ].compact.join(" ")
    end

    def name_constraint(from_table, from_column)
      "fk_#{from_table}_#{from_column}"
    end

  end

end
