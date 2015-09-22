require 'pgbundle/version'

module PgBundle
  autoload :Dsl, 'pgbundle/dsl'
  autoload :Definition, 'pgbundle/definition'
  autoload :Database, 'pgbundle/database'
  autoload :Extension, 'pgbundle/extension'
  autoload :BaseSource, 'pgbundle/base_source'
  autoload :PathSource, 'pgbundle/path_source'
  autoload :GitSource, 'pgbundle/git_source'
  autoload :GithubSource, 'pgbundle/github_source'
  autoload :PgxnSource, 'pgbundle/pgxn_source'

  class PgfileError < StandardError
  end

  class InstallError < StandardError; end
  class ExtensionCreateError < StandardError; end
  class CircularDependencyError < StandardError
    def initialize(base, dep)
      super "Circular Dependency between #{base} and #{dep} detected"
    end
  end

  class TransactionRollback < StandardError; end

  class ExtensionNotFound < ExtensionCreateError
    def initialize(name, version = nil)
      if version
        super "specified Version #{version} for Extension #{name} not available"
      else
        super "Extension #{name} not available"
      end
    end
  end

  class SourceNotFound < InstallError
    def initialize(name)
      super "Source for Extension #{name} not found"
    end
  end

  class DependencyNotFound < ExtensionCreateError
    def initialize(base_name, dependen_msg)
      super "Can't install Dependency for Extension #{base_name}: #{dependen_msg}"
    end
  end

  class ReadOnlyDb < ExtensionCreateError
    def initialize(db, base_name)
      super "Can't install Extension #{base_name}, Database #{db} is read only"
    end
  end

  class MissingDependency < ExtensionCreateError
    def initialize(base_name, dependen_msg)
      required = dependen_msg[/required extension \"(.*?)\" is not installed/, 1]
      super "Dependency #{required} for Extension #{base_name} is not defined"
    end
  end

  class GitCommandError < InstallError
    def initialize(dest, details = nil)
      super "Failed to load git repository cmd: '#{dest}'\n failed: #{details}"
    end
  end

  class PgxnError < InstallError
    def initialize(dest, message = nil)
      super "Failed to load from pgxn: '#{dest}'\n failed: #{message}"
    end
  end
end
