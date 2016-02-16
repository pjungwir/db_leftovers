db\_leftovers
=============

Db\_leftovers lets you define indexes, foreign keys, and CHECK constraints for your Rails app
in one place using an easy-to-read DSL,
then run a rake task to bring your database up-to-date.
Whenever you edit the DSL, you can re-run the rake task and db\_leftovers will alter your database accordingly.
This is useful because of the following limitations in vanilla Rails (note that very recently Rails has started to add some of these, e.g. `add_foreign_key`):

  * There are no built-in migration methods to create foreign keys or CHECK constraints.
  * Even if created, foreign keys and CHECK constraints won't appear in your schema.rb.
  * The built-in `add_index` method doesn't support WHERE clauses on your indexes.
  * If you're using Heroku, `db:push` and `db:pull` won't transfer your foreign keys and CHECK constraints.
  * Creating indexes in your migrations makes it hard to manage them.
  
That last point deserves some elaboration. First, using `add_index` in your migrations is bug-prone because without rare developer discipline, you wind up missing indexes in some environments. (My rule is "never change a migration after a `git push`," but I haven't seen this followed elsewhere, and there is nothing that automatically enforces it.) Also, since missing indexes don't cause errors, it's easy to be missing one and not notice until users start complaining about performance.

Second, scattering `add_index` methods throughout migrations doesn't match the workflow of optimizing database queries. Hopefully you create appropriate indexes when you set up your tables originally, but in practice you often need to go back later and add/remove indexes according to your database usage patterns. Or you just forget the indexes, because you're thinking about modeling the data, not optimizing the queries.
It's easier to vet and analyze database indexes if you can see them all in one place,
and db\_leftovers lets you do that easily.
And since you can rest assured that each environment conforms to the same definition, you don't need to second-guess yourself about indexes that are present in development but missing in production.
Db\_leftovers gives you confidence that your database matches a definition that is easy to read and checked into version control.

At present db\_leftovers supports PostgreSQL and MySQL, although since MySQL doesn't support index WHERE clauses or CHECK constraints, using that functionality will raise errors. (If you need to share the same definitions across Postgres and MySQL, you can run arbitrary Ruby code inside the DSL to avoid defining unsupported objects when run against MySQL.)

Configuration File
------------------

db\_leftovers reads a file named `config/db_leftovers.rb` to find out which indexes and constraints you want in your database. This file is a DSL implemented in Ruby, sort of like `config/routes.rb`. It should look something like this:

    DBLeftovers::Definition.define do

      table :users do
        index :email, :unique => true
        check :registered_at_unless_guest, "role_name = 'guest' OR registered_at IS NOT NULL"
      end

      foreign_key :orders, :users

      # . . 
    end

Within the DSL file, the following methods are supported:

### index(table\_name, columns, [opts])

This ensures that you have an index on the given table and column(s). The `columns` parameter can be either a symbol or a list of strings/symbols. (If you pass a single string for the `columns` parameter, it will be treated as the expression for a functional index rather than a column name.) Opts is a hash with the following possible keys:

* `:name` The name of the index. Defaults to `index_`*table\_name*`_on_`*column\_names*, like the `add_index` method from Rails migrations.

* `:unique` Set this to `true` if you'd like a unique index.

* `:where` Accepts SQL to include in the `WHERE` part of the `CREATE INDEX` command, in case you want to limit the index to a subset of the table's rows.

* `:using` Lets you specify what kind of index to create. Default is `btree`, but if you're on Postgres you might also want `gist`, `gin`, or `hash`.

* `:function` Lets you specify an expression rather than a list of columns. If you give this option, you should pass an empty list of column names. Alternately, you can pass a string as the column name (rather than a symbol), and db\_leftovers will interpret it as a function.

#### Examples

    index :books, :author_id
    index :books, [:publisher_id, :published_at]
    index :books, :isbn, :unique => true
    index :authors, [], function: 'lower(name)'
    index :authors, 'lower(name)'

### foreign\_key(from\_table, [from\_column], to\_table, [to\_column], [opts])

This ensures that you have a foreign key relating the given tables and columns.
All parameters are strings/symbols except `opts`, which is a hash.
If you omit the column names, db\_leftovers will infer them based on Rails conventions. (See examples below.)
Opts is a hash with the following possible keys:

* `:name` The name of the foreign key. Defaults to `fk_`*from\_table*`_`*from\_column*`.

* `:on_delete` Sets the behavior when a row is deleted and other rows reference it. It may have any of these values:

  * `nil` Indicates that attempting to delete the referenced row should fail (the default).
  * `:set_null` Indicates that the foreign key should be set to null if the referenced row is deleted.
  * `:cascade` Indicates that the referencing row should be deleted if the referenced row is deleted.

* `:deferrable` Marks the constraint as deferrable. Accepts these values:

  * `nil` Indicates the constraint is not deferrable (the default).
  * `:immediate` Indicates the constraint is usually enforced immediately but can be deferred.
  * `:deferred` Indicates the constraint is always enforced deferred.

#### Examples

    foreign_key :books, :author_id, :authors, :id
    foreign_key :pages, :book_id, :books, :id, :on_delete => :cascade

With implicit column names:

    foreign_key :books, :authors
    foreign_key :books, :authors, :on_delete => :cascade
    foreign_key :books, :co_author_id, :authors
    foreign_key :books, :co_author_id, :authors, :on_delete => :cascade, :deferred => :immediate

### check(on\_table, constraint\_name, expression)

This ensures that you have a CHECK constraint on the given table with the given name and expression.
All parameters are strings or symbols.

#### Examples

    check :books, :books_have_positive_pages, 'page_count > 0'

### table(table\_name, &block)

The `table` call is just a convenience so you can group all a table's indexes et cetera together and not keep repeating the table name. You use it like this:

    table :books do
      index :author_id
      foreign_key :publisher_id, :publishers
      check :books_have_positive_pages, 'page_count > 0'
    end

You can repeat `table` calls for the same table several times if you like. This lets you put your indexes in one place and your foreign keys in another, for example.

### ignore(table\_name, [table\_name, ...])

Lets you specify one or more tables you'd like db\_leftovers to ignore completely. No objects will be added/removed to these tables. This is useful if you have tables that shouldn't be managed under db\_leftovers.

If you don't call `ignore`, the list of ignored tables defaults to `schema_migrations` and `delayed_jobs`. If you do call `ignore`, you should probably include those in your list also. If you want db\_leftovers to manage those tables after all, just say `ignore []`.



Running db\_leftovers
---------------------

db\_leftovers comes with a Rake task named `db:leftovers`. So you can update your database to match your config file by saying this:

    rake db:leftovers

db\_leftovers will notice whenever an index, foreign key, or CHECK constraint needs to be added, dropped, or changed.
It will even catch cases where the name of the managed object is the same, but its attributes have changed.
For instance, if you previously required books to have at least 1 page, but now you are introducing a "pamphlet"
and want books to have at least 100 pages, you can change your config file to say:

    check :books, :books_have_positive_pages, 'page_count >= 100'

and db\_leftovers will notice the changed expression. It will drop and re-add the constraint.

One caveat, however: we pull the current expression from the database, and sometimes Postgres does things like
add type conversions and extra parentheses. For instance, suppose you said `check :users, :email_length, 'LENGTH(email) > 2'`.
The second time you run db\_leftovers, it will read the expression from Postgres and get `length((email)::text) > 2`,
and so it will drop and re-create the constraint.
It will drop and re-create it every time you run the rake task.
To get around this, make sure your config file uses the same expression as printed by db\_leftovers in the rake output.
This can also happen for index WHERE clauses and functional indexes, fixable by a similar workaround.
MySQL doesn't have this problem because it doesn't support CHECK constraints or index WHERE clauses.

To print messages even about indexes/foreign keys/constraints that haven't changed, you can say:

    rake db:leftovers VERBOSE=true

or

    rake db:leftovers DB_LEFTOVERS_VERBOSE=true




Capistrano Integration
----------------------

I recommend running `rake db:migrate` any time you deploy, and then running `rake db:leftovers` after that. Here is what you need in your `config/deploy.rb` to make that happen:

    set :rails_env, "production"

    namespace :db do
      desc "Set up constraints and indexes"
      task :leftovers do
        run("cd #{deploy_to}/current && bundle exec rake db:leftovers RAILS_ENV=#{rails_env}")  
      end
    end

    after :deploy, 'deploy:migrate'
    after 'deploy:migrate', 'db:leftovers'

You could also change this code to *not* run migrations after each deploy, if you like. But in that case I'd recommend not running db:leftovers until after the latest migrations (if any), since new entries in the DSL are likely to reference newly-created tables/columns.



Known Issues
------------

* Multi-column foreign keys are not supported. This shouldn't be a problem for a Rails project, unless you are using a legacy database. If you need this functionality, let me know and I'll look into adding it.

* It'd be nice to have another Rake task that will read your database and generate a new `db_leftovers.rb` file, to help people migrating existing projects that already have lots of tables.



Tests
-----

Db\_leftovers has three kinds of RSpec tests: tests that run against a mock database, a Postgres database, and a MySQL database. The tests look at `spec/config/database.yml` to see if you've created a test database for Postgres and/or MySQL, and only run those tests if an entry is found there. You can look at `spec/config/database.yml.sample` to get a sense of what is expected and for instructions on setting up your own test databases. If you're contributing a patch, please make sure you've run these tests!



Contributing to db\_leftovers
-----------------------------
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone hasn't already requested and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make be sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, that is fine, but please isolate that change to its own commit so I can cherry-pick around it.

Commands for building/releasing/installing:

* `rake build`
* `rake install`
* `rake release`

Copyright
---------

Copyright (c) 2012 Paul A. Jungwirth.
See LICENSE.txt for further details.

