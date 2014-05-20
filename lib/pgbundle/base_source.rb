module PgBundle
  # The BaseSource class defines an Extension source like PathSource or GithubSource
  # it defines how to get the code and run make install on a given host (e.g. database server)
  class BaseSource
    attr_accessor :path
    def initialize(path)
      @path = path
    end

    def load(host, dest)
      fail NotImplementedError
    end

    private

    def copy_local(source, dest)
      FileUtils.cp_r source, dest
    end

    def copy_to_remote(host, source, dest)
      Net::SCP.start(host, nil) do |scp|
        scp.upload(source, dest, recursive: true)
      end
    end
  end
end
