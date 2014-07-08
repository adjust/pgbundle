require 'pg'
module PgBundle
  # The Definition class collects all objects defined in a PgFile
  class Definition
    attr_accessor :database, :extensions, :errors
    def initialize
      @extensions = {}
      @errors = []
    end

    # returns an Array of missing Extensions
    def missing_extensions
      link_dependencies
      extensions.select { |_, dep| !dep.available?(database) }.values
    end

    # returns an Array of already available Extensions
    def available_extensions
      link_dependencies
      extensions.select { |_, dep| dep.available?(database) }.values
    end

    # installs missing extensions returns all successfully installed Extensions
    def install
      installed = missing_extensions.map do |dep|
        dep.install(database)
        dep
      end

      installed.select { |dep| dep.available?(database) }
    end

    # installs all required extensions
    def install!
      installed = extensions.map do |_, dep|
        dep.install(database, true)
        dep
      end

      installed.select { |dep| dep.available?(database) }
    end

    # create all required extensions
    def create
      extensions.map do |_, dep|
        dep.create_with_dependencies(database)
        dep
      end
    end

    def init
      ["database '#{database.name}', host: '#{database.host}', user: #{database.user}, system_user: #{database.system_user}, use_sudo: #{database.use_sudo}"] +
      database.current_definition.map do |r|
        name, version = r['name'], r['version']
        requires = r['requires'] ? ", requires: " + r['requires'].gsub(/[{},]/,{'{' => '%w(', '}' =>')', ','=> ' '}) : ''
        "pgx '#{name}', '#{version}'#{requires}"
      end
    end

    # returns an array hashes with dependency information
    # [{name: 'foo', installed: true, created: false }]
    def check
      link_dependencies
      extensions.map do |_,ext|
        {
          name: ext.name,
          installed: ext.installed?(database),
          created: ext.created?(database)
        }
      end
    end

    # links extension dependencies to each other
    def link_dependencies
      extensions.each do |_, ex|
        undefined_dependencies = ex.dependencies.select { |k, v| v.source.nil? }.keys
        undefined_dependencies.each do |name|
          if extensions[name]
            ex.dependencies[name] = extensions[name]
          else
            ex.dependencies[name] = PgBundle::Extension.new(name)
          end
        end
      end
      self
    end
  end
end
