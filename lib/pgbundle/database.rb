require 'pg'
require 'net/ssh'

module PgBundle
  # The Database class defines on which database the extensions should be installed
  # Note to install an extension the code must be compiled on the database server
  # on a typical environment ssh access is needed if the database host differs from
  # the Pgfile host
  class Database
    attr_accessor :name, :user, :password, :host, :system_user, :use_sudo, :port, :force_ssh

    def initialize(name, opts = {})
      @name        = name
      @user        = opts[:user]        || 'postgres'
      @password    = opts[:password]
      @host        = opts[:host]        || 'localhost'
      @use_sudo    = opts[:use_sudo]    || false
      @system_user = opts[:system_user] || 'postgres'
      @port        = opts[:port]        || 5432
      @force_ssh   = opts[:force_ssh]   || false
      @slave       = opts[:slave]       || false
    end

    def connection
      @connection ||= begin
        PG.connect(connection_opts)
      end
    end

    def connection_opts
      {
        dbname: name,
        user: user,
        password: password,
        host: host,
        port: port
      }.compact
    end

    def to_s
      "host: #{@host}:#{port} db: #{@name}"
    end

    def slave?
      @slave
    end
    # executes the given sql on the database connections
    # redirects all noise to /dev/null
    def execute(sql)
      silence do
        connection.exec sql
      end
    end

    alias_method :exec, :execute

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

    # loads the source, runs make install and removes the source afterwards
    def make_install(source, ext_name, flags)
      run("mkdir -p -m 0777 /tmp/pgbundle/")
      remove_source(ext_name)
      source.load(host, system_user, load_destination(ext_name))
      run(make_install_cmd(ext_name, flags))
      remove_source(ext_name)
      source.clean
    end

    # loads the source and runs make uninstall
    def make_uninstall(source, ext_name, flags)
      remove_source(ext_name)
      source.load(host, system_user, load_destination(ext_name))
      run(make_uninstall_cmd(ext_name, flags))
      remove_source(ext_name)
      source.clean
    end

    def drop_extension(name)
      execute "DROP EXTENSION IF EXISTS #{name}"
    end

    def load_destination(ext_name)
      "/tmp/pgbundle/#{ext_name}"
    end

    # returns currently installed extensions
    def current_definition
      result = execute('SELECT name, version, requires FROM pg_available_extension_versions WHERE installed').to_a
    end

    private

    def sudo
      use_sudo ? 'sudo' : ''
    end

    def remove_source(name)
      run("rm -rf #{load_destination(name)}")
    end

    def make_install_cmd(name, flags)
      <<-CMD.gsub(/\s+/, ' ').strip
        cd #{load_destination(name)} &&
        #{sudo} make #{flags} clean &&
        #{sudo} make #{flags} &&
        #{sudo} make #{flags} install
      CMD
    end

    def make_uninstall_cmd(name, flags)
      "cd #{load_destination(name)} && #{sudo} make #{flags} uninstall"
    end

    def run(cmd)
      if host == 'localhost' && !force_ssh
        local cmd
      else
        remote cmd
      end
    end

    def local(cmd)
      res = %x((#{cmd}) 2>&1 )
      raise res unless $?.success?
    end

    def remote(cmd)
      Net::SSH.start(host, system_user) do |ssh|
        ssh.exec cmd
      end
    end


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
