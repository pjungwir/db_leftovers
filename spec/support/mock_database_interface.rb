class DBLeftovers::MockDatabaseInterface < DBLeftovers::GenericDatabaseInterface

  def initialize
    @sqls = []
  end

  def sqls
    @sqls
  end

  def execute_sql(sql)
    @sqls << normal_whitespace(sql)
  end

  alias :old_execute_add_index :execute_add_index
  def execute_add_index(idx)
    old_execute_add_index(idx)
    @indexes[idx.index_name] = idx
  end

  alias :old_execute_add_constraint :execute_add_constraint
  def execute_add_constraint(chk)
    old_execute_add_constraint(chk)
    @constraints[chk.constraint_name] = chk
  end

  def saw_sql(sql)
    # puts sqls.join("\n\n\n")
    # Don't fail if only the whitespace is different:
    sqls.include?(normal_whitespace(sql))
  end

  def starts_with(indexes=[], foreign_keys=[], constraints=[])
    # Convert symbols to strings:
    @indexes = Hash[indexes.map{|idx| [idx.index_name, idx]}]
    @foreign_keys = Hash[foreign_keys.map{|fk| [fk.constraint_name, fk]}]
    @constraints = Hash[constraints.map{|chk| [chk.constraint_name, chk]}]
  end

  def lookup_all_indexes
    @indexes
  end

  def lookup_all_foreign_keys
    @foreign_keys
  end

  def lookup_all_constraints
    @constraints
  end

  private

  def normal_whitespace(sql)
    sql.gsub(/\s/m, ' ').gsub(/  +/, ' ').strip
  end

end

