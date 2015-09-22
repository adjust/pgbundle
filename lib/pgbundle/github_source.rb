require 'tmpdir'
module PgBundle
  # The GithubSource class defines a Github Source
  class GithubSource < GitSource
    attr_reader :branch

    def initialize(path, branch = 'master')
      branch = branch || 'master'
      path = "git@github.com:#{path}.git"
      super(path, branch)
    end
  end
end
