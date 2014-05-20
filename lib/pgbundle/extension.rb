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
      return false unless installed?(database)
      return true if created?(database)

      created_any_version?(database) ? updatable?(database) : creatable?(database)
      rescue ExtensionCreateError
        false
    end

    # returns true if extension is already created with the correct version in the given database
    def created?(database)
      if version
        result = database.execute("SELECT * FROM pg_available_extension_versions WHERE name ='#{name}' AND version = '#{version}' AND installed").to_a
      else
        result = database.execute("SELECT * FROM pg_available_extension_versions WHERE name ='#{name}' AND installed").to_a
      end

      if result.empty?
        false
      else
        true
      end
    end

    # returns if the extension is already installed on the database system
    # if it is also already created it returns the installed version
    def installed?(database)
      if version
        result = database.execute("SELECT * FROM pg_available_extension_versions WHERE name ='#{name}' AND version = '#{version}'").to_a
      else
        result = database.execute("SELECT * FROM pg_available_extension_versions WHERE name ='#{name}'").to_a
      end

      if result.empty?
        false
      else
        true
      end
    end

    # checks that all dependencies are installed on a given database
    def dependencies_installed?(database)
      dependencies.all?{|_, d| d.installed?(database)}
    end

    # installs extension and all dependencies using make install
    # returns true if Extension can successfully be created using CREATE EXTENSION
    def install(database)
      unless dependencies.empty?
        install_dependencies(database)
      end

      make_install(database)
      raise ExtensionNotFound.new(name, version) unless installed?(database)

      add_missing_required_dependencies(database)

      creatable?(database)
    end

    # completely removes extension be running make uninstall and DROP EXTENSION
    def uninstall!(database)
      drop_extension(database)
      make_uninstall(database)
    end

    private

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

    # checks if Extension is already installed at any version thus need ALTER EXTENSION to install
    def created_any_version?(database)
      result = database.execute("SELECT * FROM pg_available_extension_versions WHERE name ='#{name}' AND installed").to_a
      if result.empty?
        false
      else
        true
      end
    end

    # adds dependencies that are required but not defined yet
    def add_missing_required_dependencies(database)
      requires = requires(database)
      requires.each do |name|
        unless dependencies[name]
          dependencies[name] = Extension.new(name)
        end
      end
    end

    # returns an array of required Extension specified in the extensions control file
    def requires(database)
      fail "Extension #{name} not (yet) installed" unless installed?(database)

      stmt = if version
        <<-SQL
          SELECT unnest(requires) as name FROM
          ( SELECT requires FROM  pg_available_extension_versions where name='#{name}' AND version ='#{version}') t
        SQL
      else
        <<-SQL
          SELECT unnest(requires) as name FROM
          (SELECT requires FROM
            pg_available_extensions a
            JOIN pg_available_extension_versions v ON v.name = a.name AND a.default_version = v.version
            WHERE v.name = '#{name}')t
        SQL
      end

      result = database.execute(stmt).to_a

      requires = result.map{|r| r['name']}
    end

    # loads the source and runs make uninstall
    # returns: self
    def make_uninstall(database)
      database.make_uninstall(source, name)
      self
    end

    def drop_extension(database)
      database.drop_extension(name)
    end

    # loads the source and runs make install
    # returns: self
    def make_install(database)
      return self if installed?(database)

      fail SourceNotFound, name if source.nil?

      database.make_install(source, name)
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
      dependencies_installed?(database) && installed?(database)
    end

    # hard checks that the dependency can be created running CREATE command in a transaction
    def creatable!(database)
      database.transaction_rollback do |con|
        begin
          create_dependencies(con)
          create!(con)
        rescue PG::UndefinedFile => err
          raise ExtensionNotFound.new(name, version)
        rescue PG::UndefinedObject => err
          raise MissingDependency.new(name, err.message)
        end
      end

      true
    end

    # checks that the extension can be updated running ALTER EXTENSION command in a transaction
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

    def set_source(opts)
      if opts[:path]
        @source = PathSource.new(opts[:path])
      elsif opts[:github]
        @source = GithubSource.new(opts[:github])
      end
    end
  end
end
