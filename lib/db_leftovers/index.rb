module DBLeftovers

  # Just a struct to hold all the info for one index:
  class Index
    attr_accessor :table_name, :column_names, :index_name,
      :where_clause, :using_clause, :unique

    def initialize(table_name, column_names, opts={})
      opts = {
        :where => nil,
        :unique => false,
        :using => nil
      }.merge(opts)
      opts.keys.each do |k|
        raise "Unknown option: #{k}" unless [:where, :unique, :using, :name].include?(k)
      end
      @table_name = table_name.to_s
      @column_names = [column_names].flatten.map{|x| x.to_s}
      @where_clause = opts[:where]
      @using_clause = opts[:using]
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
      other.using_clause == using_clause and
      other.unique == unique
    end

    def to_s
      "<#{@index_name}: #{@table_name}.[#{column_names.join(",")}] unique=#{@unique}, where=#{@where_clause}, using=#{@using_clause}>"
    end

    private 

    def choose_name(table_name, column_names)
      # Max length in Postgres is 63; in MySQL 64:
      "index_#{table_name}_on_#{column_names.join('_and_')}"[0,63]
    end

  end

end
