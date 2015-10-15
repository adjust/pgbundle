[![Build Status](https://travis-ci.org/adjust/pgbundle.svg?branch=master)](https://travis-ci.org/adjust/pgbundle)

# pgbundle

bundling postgres extension

## install

  gem install pgbundle

## usage

define your dependent postgres extensions in a Pgfile like this:

```
# Pgfile

database 'my_database', host: 'my.db.server', use_sudo: true, system_user: 'postgres'

pgx 'hstore'
pgx 'my_extension', '1.0.2', github: me/my_extension
pgx 'my_other_extionsion', :git => 'https://github.com/me/my_other_extionsion.git'
pgx 'my_ltree_dependend_extension', github: me/my_ltree_dependend_extension, requires: 'ltree'
```

**database**

`database` defines on which database(s) the extensions should be installed. The first
argument is the database name the additional options may specify your setup but
come with reasonable default values.

option        | default     | desciption
-------       | -------     | -----------
user          | 'postgres'  | the database user (needs privilege to `CREATE EXTENSION`)
host          | 'localhost' | the database host (needs to be accessible from where `pgbundle` runs)
use_sudo      | false       | if true use `sudo` to run `make install` if needed
system_user   | 'postgres'  | the (os) system user that is allowed to install an extension (through make)
port          | 5432        | the database port
force_ssh     | false       | run commands via ssh even if host is `localhost`
slave         | false       | defines if the database runs as a read-only slave thus skips any `CREATE` command

**pgx**

The `pgx` command defines you actual Extension. The first argument specifies the Extension name,
the second optional parameter defines the required Version. If the Extension is not yet
installed on the server you may wish to define how `pgbundle` can find it's source to build
and install it. And which Extensions may be required

option      | description
------      | -----------
git         | any git repository pgbundle can clone from
github      | any github repository in the form `user/repository`
branch      | an optional branch name for git or github sources defaults to `master`
requires    | an optional extension that the extension depends on
path        | any absolute or relative local path e.g. './foo/bar'
pgxn        | any repository available on http://pgxn.org/
flags       | optional string used for make results in "make flags && make flags install"


Some Extensions may require other Extensions to allow `pgbundle` to resolve dependencies
and install it in the right order you can define them with `requires`.
If the required Extension is not yet available on the target server or the Extension
requires a specific Version you should define it as well.
E.g.

```
# Pgfile

database ...

pgx 'foo', '0.1.2', github: me/foo

# set foo as dependency for bar
pgx 'bar', '1.2.3', github: me/bar, requires: 'foo'

# set bar and boo as dependency for baz
# will automatically set foo as dependency as well
pgx 'baz', '0.2.3', github: me/baz, requires: ['bar', 'boo']
```

## pgbundle commands

`pgbundle` comes with four commands. If the optional `pgfile` is not given it assumes
to find a file named `Pgfile` in the current directory.

**check**

checks availability of required extensions.

```
pgbundle check [pgfile]
```

`check` does not change anything on your system, it only checks which
of your specified extensions are available and which are missing.
It returns with exitcode `1` if any Extension is missing and `0` otherwise.


**install**

installs extensions

```
pgbundle install [pgfile] [-f]
```

`install` tries to install missing Extensions. If `--force` is given it installs
all Extension even if they are already installed.

**create**

create the extension at the desired version

```
pgbundle create [pgfile]
```

`create` runs the `CREATE EXTENSION` command on the specified databases. If a version
is specified in the `Pgfile` it tries to install with `CREATE EXTENSION VERSION version`.
If the Extension is already created but with a wrong version, it will run
`ALTER EXTENSION extension_name UPDATE TO new_version`.

**init**

write an initial pgfile to stdout

```
pgbundle init db_name -u user -h host -p port
```

`init` is there to help you get started. If you have already a database with installed
Extensions you get the content for an initial `Pgfile`. Pgbundle will figure out
which Extension at which Version are already in use and print a reasonable starting
point for you Pgfile.
However this is only to help you get started you may wish to specify sources and
dependencies correctly.

### How it works

You may already have noticed that using Extensions on postgres requires two different
steps. Building the extension on the database cluster with `make install`
and creating the extension into the database with `CREATE/ALTER EXTENSION`.
Pgbundle reflects that with the two different commands `install` and `create`.

Usually `pgbundle` runs along with your application on your application server
which often is different from your database machine. Thus the `install` step
will (if necessary) try to download the source code of the extension into a
temporary folder and then copy it to your database servers into `/tmp/pgbundle`.
From there it will run `make clean && make && make install` for each database.
You may specify as which user you want these commands to run with the `system_user`
option. Although for security reasons not recommended you can specify to run the
install step with sudo `use_sudo: true`, but we suggest to give write permission
for the postgres system user to the install targets. If you are not sure which these
are run

```
pg_config
```

and find the `LIBDIR`, `SHAREDIR` and `DOCDIR`

#### master - slave

Every serious production database cluster usually has a slave often ran as Hot Standby.
You should make sure that all your Extension are also installed on all slaves.
Because database slaves run as read-only servers any attempt to `CREATE` or `ALTER`
Extension will fail, these commands should only run on the master server and will
be replicated to the slave from there. You can tell `pgbundle` that it should skip
these steps with `slave: true`.


