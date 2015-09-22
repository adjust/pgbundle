require 'tmpdir'
module PgBundle
  # The GithubSource class defines a Github Source
  class GitSource < BaseSource
    attr_reader :branch

    def initialize(path, branch = 'master')
      @branch = branch || 'master'
      super(path)
    end

    def load(host, user, dest)
      clone
      if host == 'localhost'
        copy_local("#{clone_dir}/", dest)
      else
        copy_to_remote(host, user, "#{clone_dir}/", dest)
      end
    end

    def clean
      FileUtils.remove_dir(clone_dir, true)
    end

    private

    def clone
      res = %x((rm -rf #{clone_dir} && #{git_command} && rm -rf #{clone_dir}/.git}) 2>&1)
      unless $?.success?
        fail GitCommandError, git_command, res
      end
    end

    # git clone user@git-server:project_name.git -b branch_name /some/folder
    def git_command
      "git clone #{path} -b #{branch} --quiet --depth=1 #{clone_dir}"
    end

    def clone_dir
      @clone_dir ||= Dir.mktmpdir
    end
  end
end
