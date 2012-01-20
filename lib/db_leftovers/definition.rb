module DBLeftovers

  class Definition
    def self.define(opts={}, &block)
      opts = {
        :do_indexes => true,
        :do_foreign_keys => true
      }.merge(opts)
      dsl = DSL.new
      dsl.define(&block)
      dsl.record_indexes        if opts[:do_indexes]
      dsl.record_foreign_keys   if opts[:do_foreign_keys]
    end
  end

end
