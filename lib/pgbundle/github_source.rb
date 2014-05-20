require 'tmpdir'
module PgBundle
  # The GithubSource class defines a Github Source
  class GithubSource < BaseSource
    def load(host, user, dest)
      clone(dest)
      if host == 'localhost'
        copy_local(clone_dir, dest)
      else
        copy_to_remote(host, user, clone_dir, dest)
      end
    end

    def branch_name
      @branch || 'master'
    end

    private

    def clone(dest)
      # git clone user@git-server:project_name.git -b branch_name /some/folder
      %x((git clone git@github.com:#{path}.git -b #{branch_name} --quiet --depth=1 #{clone_dir} && rm -rf #{clone_dir}/.git}) 2>&1)
      unless $?.success?
        fail GitCommandError
      end
    end

    def clone_dir
      @clone_dir ||= Dir.mktmpdir
    end
  end
end
