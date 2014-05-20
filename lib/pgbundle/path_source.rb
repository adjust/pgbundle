require 'tmpdir'
require 'net/scp'
module PgBundle
  # The PathSource class defines a local Path Source
  # eg. PathSource.new('/my/local/path')
  class PathSource < BaseSource
    def load(host, dest)
      if host == 'localhost'
        copy_local(path, dest)
      else
        copy_to_remote(host, path, dest)
      end
    end
  end
end
