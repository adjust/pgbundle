# pgbundle

bundling postgres extension

## install

  gem install pgbundle

## usage

define your dependent postgres extensions in a Pgfile like this:

```
#Pgfile

database 'my_database', host: 'my.db.server' , use_sudo: true, make_cmd: 'make'

pgx 'hstore'
pgx 'my_extension', '1.0.2', github: me/my_extension
pgx 'my_other_extionsion', :git => 'https://github.com/me/my_other_extionsion.git'
pgx 'my_ltree_dependend_extension', github: me/my_ltree_dependend_extension, require: 'ltree'
```

### install your extension

  pgbundle install

installs the extensions and dependencies on your database server

### check your dependencies

  pgbundle check

checks whether all dependencies are available for creation on the database server

### create extensions

  pgbundle create

runs the `CREATE EXTENSION` command on the database to create all extension at the
defined version

