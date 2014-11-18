require 'rubygems'
require 'pgbundle'
require 'pg'

Dir.glob('spec/support/**/*.rb').each { |f| require f }

RSpec.configure do |config|
  config.fail_fast                                        = false
  config.order                                            = 'random'
  config.treat_symbols_as_metadata_keys_with_true_values  = true
  config.filter_run focus: true
  config.run_all_when_everything_filtered                 = true
  config.before(:suite) do
    conn = PG.connect(dbname: 'postgres', user: 'postgres')
    conn.exec('CREATE DATABASE pgbundle_test')
    conn.close
  end

  config.after(:suite) do
    conn = PG.connect(dbname: 'postgres', user: 'postgres')
    conn.exec("SELECT pg_terminate_backend(pid) from pg_stat_activity WHERE datname ='pgbundle_test'")
    conn.exec('DROP DATABASE IF EXISTS pgbundle_test')
    conn.close
  end

  config.before(:each) do
    [
      PgBundle::Extension.new('foo', '0.0.2', path: './spec/sample_extensions/foo'),
      PgBundle::Extension.new('bar', path: './spec/sample_extensions/bar'),
      PgBundle::Extension.new('baz', path: './spec/sample_extensions/baz')
    ].each { |d| d.uninstall!(database) }
  end

  config.after(:each) do
    [
      PgBundle::Extension.new('foo', '0.0.2', path: './spec/sample_extensions/foo'),
      PgBundle::Extension.new('bar', path: './spec/sample_extensions/bar'),
      PgBundle::Extension.new('baz', path: './spec/sample_extensions/baz')
    ].each { |d| d.uninstall!(database) }
    database.connection.close
  end

  def database
    @db ||= PgBundle::Database.new('pgbundle_test')
  end
end
