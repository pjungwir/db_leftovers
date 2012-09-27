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
      @unique = !!opts[:unique]
      @index_name = (opts[:name] || choose_name(@table_name, @column_names)).to_s
    end

    def unique?
      !!@unique
    end

    def equals(other)
      other.table_name == table_name and
      other.column_names == column_names and
      other.index_name == index_name and
      other.where_clause == where_clause and
      other.unique == unique
    end

    def to_s
      "<#{@index_name}: #{@table_name}.[#{column_names.join(",")}] unique=#{@unique}, where=#{@where_clause}>"
    end

    private 

    def choose_name(table_name, column_names)
      "index_#{table_name}_on_#{column_names.join('_and_')}"
    end

  end

end
