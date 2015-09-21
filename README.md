[![Build Status](https://travis-ci.org/adjust/pgbundle.svg?branch=master)](https://travis-ci.org/adjust/pgbundle)

# pgbundle

bundling postgres extension

## install

  gem install pgbundle

## usage

define your dependent postgres extensions in a Pgfile like this:

```
#Pgfile

database 'my_database', host: 'my.db.server', use_sudo: true, system_user: 'postgres'

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

## getting started

if your already have some database on your current project you can get a starting point with

  pgbundle init

lets say your database named 'my_project' runs on localhost with user postges

  pgbundle init my_project -u postgres -h localhost

