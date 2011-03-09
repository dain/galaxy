require 'fileutils'
require 'open-uri'

module Galaxy
  class ConfigInstaller

    def initialize repository_base,  config_version
      @base_url = repository_base + '/' + config_version.repository_path + '/'
    end

    def install(base_path)
      download(base_path, "config.properties", true)
      download(base_path, "jvm.config")
      download(base_path, "log.config")
    end

private

    def download(base_path, file_name, required = false)
      dest_dir = File.join(base_path, "etc")
      dest_path = File.join(base_path, "etc", file_name)

      url = @base_url + file_name

      puts "#{url} => #{dest_path}"

      FileUtils.mkdir_p(dest_dir)
      begin
        open(url) do |io|
          File.open(dest_path, "w") do |dest|
            dest.write(io.read)
          end
        end
      rescue => e
        raise "Unable to copy #{url} to #{dest_path}" if required
      end
    end

  end
end