module DBLeftovers

  # Just a struct to hold all the info for one index:
  class Index
    attr_accessor :table_name, :column_names, :index_name,
      :where_clause, :unique

    def initialize(table_name, column_names, opts={})
      opts = {
        :where => nil,
        :unique => false,
      }.merge(opts)
      opts.keys.each do |k|
        raise "Unknown option: #{k}" unless [:where, :unique, :name].include?(k)
      end
      @table_name = table_name.to_s
      @column_names = [column_names].flatten.map{|x| x.to_s}
      @where_clause = opts[:where]
      @unique = opts[:unique]
      @index_name = opts[:name] || choose_name(@table_name, @column_names)
    end

    def unique?
      @unique
    end

    private 

    def choose_name(table_name, column_names)
      "index_#{table_name}_on_#{column_names.join('_and_')}"
    end

  end

end
