module DBLeftovers

  class Definition
    def self.define(opts={}, &block)
      opts = {
        :do_indexes => true,
        :do_foreign_keys => true,
        :do_constraints => true
      }.merge(opts)
      dsl = DSL.new
      dsl.define(&block)
      dsl.record_indexes        if opts[:do_indexes]
      dsl.record_foreign_keys   if opts[:do_foreign_keys]
      dsl.record_constraints    if opts[:do_constraints]
    end
  end

end
