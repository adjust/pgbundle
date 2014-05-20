require 'pg'
require 'pry'
module PgBundle
  # The Database class defines on which database the extensions should be installed
  # Note to install an extension the code must be compiled on the database server
  # on a typical environment ssh access is needed if the database host differs from
  # the Pgfile host
  class Database
    attr_accessor :name, :user, :host
    def initialize(name, opts = {})
      @name     = name
      @user     = opts[:user]     || 'postgres'
      @host     = opts[:host]     || 'localhost'
      @make_cmd = opts[:make_cmd] || 'make'
      @use_sudo = opts[:use_sudo] || 'false'
    end

    def connection
      @connection ||= begin
        PG.connect(dbname: name, user: user, host: host)
      end
    end

    # executes the given sql on the database connections
    # redirects all noise to /dev/null
    def execute(sql)
      silence do
        connection.exec sql
      end
    end

    def transaction(&block)
      silence do
        connection.transaction(&block)
      end
    end

    def transaction_rollback(&block)
      silence do
        connection.transaction do |con|
          yield con
          fail TransactionRollback
        end
      end

      rescue TransactionRollback
    end

    private

    def silence
      begin
        orig_stderr = $stderr.clone
        orig_stdout = $stdout.clone
        $stderr.reopen File.new('/dev/null', 'w')
        $stdout.reopen File.new('/dev/null', 'w')
        retval = yield
      rescue Exception => e
        $stdout.reopen orig_stdout
        $stderr.reopen orig_stderr
        raise e
      ensure
        $stdout.reopen orig_stdout
        $stderr.reopen orig_stderr
      end
      retval
    end
  end
end
