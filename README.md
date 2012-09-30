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

### foreign\_key(from\_table, [from\_column], to\_table, [to\_column], [opts])

This ensures that you have a foreign key relating the given tables and columns.
All parameters are strings/symbols except `opts`, which is a hash.
If you omit the column names, db\_leftovers will infer them based on Rails conventions. (See examples below.)
The only option that is supported is `:on_delete`, which may have any of these values:

* `nil` Indicates that attempting to delete the referenced row should fail (the default).
* `:set_null` Indicates that the foreign key should be set to null if the referenced row is deleted.
* `:cascade` Indicates that the referencing row should be deleted if the referenced row is deleted.

#### Examples

    foreign_key :books, :author_id, :authors, :id
    foreign_key :pages, :book_id, :books, :id, :on_delete => :cascade

With implicit column names:

    foreign_key :books, :authors
    foreign_key :books, :authors, :on_delete => :cascade
    foreign_key :books, :co_author_id, :authors
    foreign_key :books, :co_author_id, :authors, :on_delete => :cascade

### check(constraint\_name, on\_table, expression)

This ensures that you have a CHECK constraint on the given table with the given name and expression.
All parameters are strings or symbols.

#### Examples

    check :books, :books_have_positive_pages, 'page_count > 0'

### table(table\_name, &block)

The `table` call is just a convenience so you can group all a table's indexes etcetera together and not keep repeating the table name. You use it like this:

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

db\_leftovers will notice whenever an index, foreign key, or CHECK constraint needs to be added, dropped, or changed.
It will even catch cases where the name of the managed object is the same, but its attributes have changed.
For instance, if you previously required books to have at least 1 page, but now you are introducing a "pamphlet"
and want books to have at least 100 pages, you can change your config file to say:

    check :books, :books_have_positive_pages, 'page_count >= 100'

and db\_leftovers will notice the changed expression. It will drop and re-add the constraint.

One caveat, however: we pull the current expression from the database, and sometimes Postgres does things like
add type conversions. If instance, suppose you said `check :users, :email_length, 'LENGTH(email) > 2'`.
The second time you run db\_leftovers, it will read the expression from Postgres and get `LENGTH((email)::text) > 2`,
and so it will drop and re-create the constraint.
It will drop and re-create it every time you run the rake task.
To get around this, make sure your config file uses the same expression as printed by db\_leftovers in the rake output.
This can also happen for index WHERE clauses, fixable by a similar workaround.

To print messages even about indexes/foreign keys/constraints that haven't changed, you can say:

    rake db:leftovers VERBOSE=true

or

    rake db:leftovers DB_LEFTOVERS_VERBOSE=true




Known Issues
------------

* db\_leftovers only supports PostgreSQL databases.
  If you want to add support for something else, just send me a pull request!

  


Contributing to db\_leftovers
-----------------------------
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone hasn't already requested and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make be sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, that is fine, but please isolate that change to its own commit so I can cherry-pick around it.

Copyright
---------

Copyright (c) 2012 Paul A. Jungwirth.
See LICENSE.txt for further details.

