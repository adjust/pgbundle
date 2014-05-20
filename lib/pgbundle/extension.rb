require 'net/ssh'
module PgBundle
  # The Extension class provides the api for defining an Extension
  # it installation source, and dependencies
  # example:
  #   define an extension named 'foo' at version '0.1.1', with source on github depending on hstore
  #   Extension.new('foo', '0.1.1', github: 'me/foo', requires: 'hstore')
  #   you can then check if the Extension is available on a given database
  #   extension.available?(database)
  #   or install it along with it's dependencies
  #   extension.install(database)
  class Extension
    attr_accessor :name, :version, :source, :resolving_dependencies
    def initialize(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      @name, @version = args
      self.dependencies = opts[:requires]
      set_source(opts)
    end

    def dependencies
      @dependencies
    end

    # set dependency hash with different options
    # dependencies= {foo: Extension.new('foo'), bar: Extension.new('bar')}
    # => {'foo' => Extension.new('foo'), 'bar' Extension.new('bar')}
    # dependencies= 'foo'
    # => {foo: Extension.new('foo')}
    # dependencies= Extension.new('foo')
    # => {foo: Extension.new('foo')}
    # dependencies= ['foo', 'bar']
    # => {'foo' => Extension.new('foo'), 'bar' Extension.new('bar')}
    def dependencies=(obj = nil)
      @dependencies = case obj
      when nil
        {}
      when Hash
        Hash[obj.map { |k, v| [k.to_s, v] }]
      when String, Symbol
        { obj.to_s => Extension.new(obj.to_s) }
      when Extension
        { obj.name => obj }
      when Array
        hashable = obj.map do |o|
          case o
          when String, Symbol
            [o.to_s, Extension.new(obj.to_s)]
          when Extension
            [o.name, o]
          end
        end
        Hash[hashable]
      end
    end

    # returns true if extension is available for installation on a given database
    def available?(database)
      @available ||= available!(database)
    end

    def available!(database)
      result = database.execute("SELECT * FROM pg_available_extensions WHERE name ='#{name}'").to_a
      if result.empty?
        return false
      end

      if result.first['installed_version'] == version || version.nil?
        return true
      end

      already_installed?(database) ? updatable?(database) : creatable?(database)
      rescue ExtensionCreateError
        false
    end

    # checks if Extension is already installed at any version thus need ALTER EXTENSION to install
    def already_installed?(database)
      result = database.execute("SELECT * FROM pg_available_extensions WHERE name ='#{name}' AND installed_version IS NOT NULL ").to_a
      !result.empty?
    end

    # installs extension and all dependencies using make install
    # returns true if Extension can successfully be created using CREATE EXTENSION
    def install(database)
      unless dependencies.empty?
        install_dependencies(database)
      end

      make_install(database)

      creatable?(database)
    end

    # completely removes extension be running make uninstall and DROP EXTENSION
    def uninstall!(database)
      drop_extension(database)
      make_uninstall(database)
    end

    # create extension on a given database connection
    def create!(con)
      con.exec create_stmt
    end

    # create the dependency graph on the given connection
    def create_dependencies(con)
      @resolving_dependencies = true
      dependencies.each do |_, d|
        fail CircularDependencyError.new(name, d.name) if d.resolving_dependencies
        d.create_dependencies(con)
        d.create!(con)
      end
      @resolving_dependencies = false
    end

    private

    # loads the source and runs make uninstall
    # returns: self
    def make_uninstall(database)
      source.load(database.host, load_destination)
      run(database.host, make_uninstall_cmd)
      run(database.host, "rm -rf #{load_destination}")
      self
    end

    def drop_extension(database)
      database.execute "DROP EXTENSION IF EXISTS #{name}"
    end

    # loads the source and runs make install
    # returns: self
    def make_install(database)
      return self if available?(database)

      fail SourceNotFound, name if source.nil?

      source.load(database.host, load_destination)
      run(database.host, make_install_cmd)
      run(database.host, "rm -rf #{load_destination}")
      self
    end

    def create_stmt
      stmt = "CREATE EXTENSION #{name}"
      stmt += " VERSION '#{version}'" unless version.nil? || version.empty?

      stmt
    end

    def install_dependencies(database)
      begin
        dependencies.each do |_, d|
          d.install(database)
        end
      rescue InstallError, ExtensionCreateError => e
        raise DependencyNotFound.new(name, e.message)
      end

      true
    end

    def creatable?(database)
      @creatable ||= creatable!(database)
    end

    def creatable!(database)
      database.transaction_rollback do |con|
        begin
          create_dependencies(con)
          create!(con)
        rescue PG::UndefinedFile => err
          raise ExtensionNotFound.new(name, version, err.message)
        rescue PG::UndefinedObject => err
          raise MissingDependency.new(name, err.message)
        end
      end

      true
    end

    def updatable?(database)
      result = true
      database.execute 'BEGIN'
      begin
        database.execute "ALTER EXTENSION #{name} UPDATE TO '#{version}'"
      rescue PG::UndefinedFile, PG::UndefinedObject => err
        @error = err.message
        result = false
      end
      database.execute 'ROLLBACK'

      result
    end

    def run(host, cmd)
      if host == 'localhost'
        local cmd
      else
        remote host, cmd
      end
    end

    def local(cmd)
      %x(#{cmd})
    end

    def remote(host, cmd)
      Net::SSH.start(host, nil) do |ssh|
        ssh.exec cmd
      end
    end

    def make_install_cmd
      "cd #{load_destination} && make clean && make install"
    end

    def make_uninstall_cmd
      "cd #{load_destination} && make uninstall"
    end

    def load_destination
      "/tmp/#{name}"
    end

    def set_source(opts)
      if opts[:path]
        @source = PathSource.new(opts[:path])
      elsif opts[:github]
        @source = GithubSource.new(opts[:github])
      end
    end
  end
end
