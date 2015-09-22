require 'tmpdir'
require 'open-uri'
require 'zip'

module PgBundle
  # The GithubSource class defines a Github Source
  class PgxnSource < BaseSource

    def initialize(dist, version)
      @dist, @version = dist, version
      path = "http://master.pgxn.org/dist/%{dist}/%{version}/%{dist}-%{version}.zip" % {dist: dist, version: version}
      super(path)
    end

    def load(host, user, dest)
      download
      unzip
      if host == 'localhost'
        copy_local("#{download_dir}/#{@dist}-#{@version}", dest)
      else
        copy_to_remote(host, user, "#{download_dir}/#{@dist}-#{@version}", dest)
      end
    end

    def clean
      FileUtils.remove_dir(download_dir, true)
    end

    private

    def download
      begin
      File.open(zipfile, "wb") do |saved_file|
        open(@path, "rb") do |read_file|
          saved_file.write(read_file.read)
        end
      end
      rescue OpenURI::HTTPError => e
        raise PgxnError.new(path, e.message)
      end
    end

    def zipfile
      "#{download_dir}/#{@dist}.zip"
    end

    def unzip
      Zip::ZipFile.open(zipfile) do |zip_file|
        zip_file.each do |f|
            f_path=File.join(download_dir, f.name)
            FileUtils.mkdir_p(File.dirname(f_path))
            zip_file.extract(f, f_path) unless File.exist?(f_path)
        end
      end
    end

    def download_dir
      @clone_dir ||= Dir.mktmpdir
    end
  end
end
