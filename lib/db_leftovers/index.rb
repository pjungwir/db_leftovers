module DBLeftovers

  # Just a struct to hold all the info for one index:
  class Index
    attr_accessor :table_name, :column_names, :index_name,
      :where_clause, :using_clause, :unique, :index_function

    def initialize(table_name, column_names, opts={})
      opts = {
        :where => nil,
        :function => nil,
        :unique => false,
        :using => nil
      }.merge(opts)
      opts.keys.each do |k|
        raise "Unknown option: #{k}" unless [:where, :function, :unique, :using, :name].include?(k)
      end
      if column_names.is_a?(Array) and column_names[0].is_a?(String) and opts[:function].nil?
        opts[:function] = column_names[0]
        column_names = []
      end
      @table_name = table_name.to_s
      @column_names = [column_names].flatten.map{|x| x.to_s}
      @where_clause = opts[:where]
      @index_function = opts[:function]
      @using_clause = opts[:using]
      @unique = !!opts[:unique]
      @index_name = (opts[:name] || choose_name(@table_name, @column_names, @index_function)).to_s

      raise "Indexes need a table!" unless @table_name
      raise "Indexes need at least column or an expression!" unless (@column_names.any? or @index_function)
      raise "Can't have both columns and an expression!" if (@column_names.size > 0 and @index_function)
    end

    def unique?
      !!@unique
    end

    def equals(other)
      other.table_name == table_name and
      other.column_names == column_names and
      other.index_name == index_name and
      other.where_clause == where_clause and
      other.index_function == index_function and
      other.using_clause == using_clause and
      other.unique == unique
    end

    def to_s
      "<#{@index_name}: #{@table_name}.[#{column_names.join(",")}] unique=#{@unique}, where=#{@where_clause}, function=#{@index_function}, using=#{@using_clause}>"
    end

    private 

    def choose_name(table_name, column_names, index_function)
      topic = if column_names.any?
                column_names.join("_and_")
              else
                index_function
              end
      ret = "index_#{table_name}_on_#{topic}"
      ret = ret.gsub(/[^a-zA-Z0-9]/, '_').
                gsub(/__+/, '_').
                gsub(/^_/, '').
                gsub(/_$/, '')
      # Max length in Postgres is 63; in MySQL 64:
      ret[0,63]
    end

  end

end
