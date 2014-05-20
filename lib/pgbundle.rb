require 'pgbundle/version'

module PgBundle
  autoload :Dsl, 'pgbundle/dsl'
  autoload :Definition, 'pgbundle/definition'
  autoload :Database, 'pgbundle/database'
  autoload :Extension, 'pgbundle/extension'
  autoload :BaseSource, 'pgbundle/base_source'
  autoload :PathSource, 'pgbundle/path_source'
  autoload :GithubSource, 'pgbundle/github_source'

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
    def initialize(name, version, msg)
      # could not stat file "/../postgresql92/extension/foo--0.0.3.sql": No such file or directory\n
      # could not stat file "/../postgresql92/extension/foo.control": No such file or directory\n
      if msg =~ /\.control":/
        super "Extension #{name} not available"
      elsif msg =~ /\.sql":/
        super "specified Version #{version} for Extension #{name} not available"
      else
        super msg
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

  class MissingDependency < ExtensionCreateError
    def initialize(base_name, dependen_msg)
      required = dependen_msg[/required extension \"(.*?)\" is not installed/, 1]
      super "Dependency #{required} for Extension #{base_name} is not defined"
    end
  end

  class GitCommandError < InstallError
    def initialize
      super 'Failed to load git repository'
    end
  end
end
