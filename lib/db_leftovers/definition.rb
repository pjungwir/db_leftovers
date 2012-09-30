module DBLeftovers

  class Definition
    def self.define(opts={}, &block)
      opts = {
        :do_indexes => true,
        :do_foreign_keys => true,
        :do_constraints => true,
        :db_interface => nil
      }.merge(opts)
      dsl = DSL.new(
        :verbose => ENV['DB_LEFTOVERS_VERBOSE'] || false,
        :db_interface => opts[:db_interface])
      dsl.define(&block)
      dsl.record_indexes        if opts[:do_indexes]
      dsl.record_foreign_keys   if opts[:do_foreign_keys]
      dsl.record_constraints    if opts[:do_constraints]
    end
  end

end
