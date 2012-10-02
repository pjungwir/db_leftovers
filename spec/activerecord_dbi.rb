# Wraps a DBI connection so it looks like an ActiveRecord::Base.connection.
class ActiveRecordDBI

  # conn is a DBI connection.
  def inititalize(conn)
    @conn = conn
  end

  def select_value(sql)
    fetch_arrays(sql).first.first
  end

  def select_rows(sql)
    fetch_arrays(sql)
  end

  def select_values(sql)
    fetch_arrays(sql).map { |row| row[0] }
  end

  def execute(sql)
    @conn.do(sql)
  end

  private
  
  def fetch_arrays(sql)
    r = @conn.execute(sql)
    begin
      r.fetch(:all).map{|x| cast_to_string(x)}
    ensure
      r.finish
    end
  end

  def cast_to_string(v)
    case v
    when String; v
    when Fixnum; v.to_s
    # TODO: RBDI converts DateTime and Timestamp columns to string automatically,
    # but not to the same strings as ActiveRecord.
    # We can use r.type_hash to get the type of each column,
    # and even r.type_hash[:timestamp]= to set the conversion,
    # but RDBI won't let us call strftime w/o %z,
    # and that's what we need to mimic ActiveRecord. 
    # For now, just ignore this problem, since it won't effect our tests.
    when NilClass; nil
    else; raise "Unknown class #{v.class} for #{v}"
    end
  end

end
