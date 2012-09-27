db\_leftovers
=============

db\_leftovers lets you define indexes, foreign keys, and CHECK constraints for your Rails app
in one place using an easy-to-read DSL,
then run a rake task to bring your database up-to-date.
I wrote this because I didn't want indexes and constraints scattered throughout my migrations or buried in my `schema.rb`, and I wanted a command I could run to ensure that they matched across my development, test, staging, and production databases.
This was particularly a problem for Heroku projects, because `db:push` and `db:pull` do not transfer your foreign keys or other constraints.
But now that it's written, I'm finding it useful on non-Heroku projects as well.

At present db\_leftovers works only on PostgreSQL databases,
but it could easily be extended to cover other RDBMSes.

Configuration File
------------------

db\_leftovers reads a file named `config/db_leftovers.rb` to find out which indexes and constraints you want in your database. This file is a DSL implemented in Ruby, sort of like `config/routes.rb`. There are only a few methods:

### index(table\_name, columns, [opts])

This ensures that you have an index on the given table and column(s). The `columns` parameter can be either a string or a list of strings. Opts is a hash with the following possible keys:

* `:name` The name of the index. Defaults to `index_`*table\_name*`_on_`*column\_names*, like the `add_index` method from Rails migrations.

* `:unique` Set this to `true` if you'd like a unique index.

* `:where` Accepts SQL to include in the `WHERE` part of the `CREATE INDEX` command, in case you want to limit the index to a subset of the table's rows.

#### Examples

    index :books, :author_id
    index :books, [:publisher_id, :published_at]
    index :books, :isbn, :unique => true

### foreign\_key(from\_table, from\_column, to\_table, [to\_column, [opts]])

This ensures that you have a foreign key relating the given tables and columns.
All parameters are strings/symbols except `opts`, which is a hash.
If you don't pass anything for `opts`, you can leave off the `to_column` parameter, and it will default to `:id`.
These options are supported:

* `:set_null` Indicates that the foreign key should be set to null if the referenced row is deleted.
* `:cascade` Indicates that the referencing row should be deleted if the referenced row is deleted.

These options are mutually exclusive. They should probably be consolidated into a single option like `:on_delete`.

#### Examples

    foreign_key :books, :author_id, :authors, :id
    foreign_key :books, :publisher_id, :publishers
    foreign_key :pages, :book_id, :books, :id, :cascade => true

### check(constraint\_name, on\_table, expression)

This ensures that you have a CHECK constraint on the given table with the given name and expression.
All parameters are strings or symbols.

#### Examples

    check :books, :books_have_positive_pages, 'page_count > 0'

### table(table\_name, &block)

The `table` call is just a convenience so you can group all a table's indexes and foreign keys together and not keep repeating the table name. You use it like this:

    table :books do
      index :author_id
      foreign_key :publisher_id, :publishers
      check :books_have_positive_pages, 'page_count > 0'
    end

You can repeat `table` calls for the same table several times if you like. This lets you put your indexes in one place and your foreign keys in another, for example.


Running db\_leftovers
---------------------

db\_leftovers comes with a Rake task named `db:leftovers`. So you can update your database to match your config file by saying this:

    rake db:leftovers


Known Issues
------------

* db\_leftovers only supports PostgreSQL databases.
  If you want to add support for something else, just send me a pull request!

* db\_leftovers will not notice if an foreign key/constraint definition changes.
  Right now it only checks for existence/non-existence.
  You can get around this by adding a version number to your constraint names,
  so if you want to force books to have at least 12 pages, you can say this:

  `check :books_have_positive_pages2, 'page_count >= 12'`

  Then the old constraint will be dropped and the new one will be added.

  However, db\_leftovers *does* check for index definitions, so if you
  make an existing index unique, add a column, remove a WHERE clause, or
  anything else, it will notice and drop and re-create the index.
  I'm working on doing the same thing for foreign keys/constraints,
  but it's not done just yet.
  
* If your database is mostly up-to-date, then running the Rake task will spam
  you with messages about how this index and that foreign key already exist.
  These should be hidden by default and shown only if you request a higher
  verbosity.
 

Contributing to db\_leftovers
-----------------------------
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

Copyright
---------

Copyright (c) 2012 Paul A. Jungwirth.
See LICENSE.txt for further details.

