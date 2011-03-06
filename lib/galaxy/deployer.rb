require 'fileutils'
require 'tempfile'
require 'logger'
require 'galaxy/host'

module Galaxy
    class Deployer
        attr_reader :log

        def initialize deploy_dir, log
            @base, @log = deploy_dir, log
        end

        # number is the deployment number for this agent
        # archive is the path to the binary archive to deploy
        # props are the properties (configuration) for the core
        def deploy number, archive, config_installer
            # assure base dir exists
            FileUtils.mkdir_p @base

            # core_base it the ultimate target directory
            core_base = File.join(@base, number.to_s)

            # create a temp dir for unpacking work
            Dir.mktmpdir(['galaxy', "tmp"], @base) { |tmp|
                # Unpack the archive
                command = "#{Galaxy::HostUtils.tar} -C #{tmp} -zxf #{archive}"
                begin
                    Galaxy::HostUtils.system command
                rescue Galaxy::HostUtils::CommandFailedError => e
                    raise "Unable to extract archive: #{e.message}"
                end

                # find the directory unpacked from the tar.gz file
                files = Dir.glob(File.join(tmp, '*'))
                if files.length != 1 || !File::directory?(files[0])
                  raise "Invalid tar file: file does not have a root directory #{archive}"
                end
                dir = files[0]

                # copy config files from config repository
                config_installer.install(dir)

                # move the unpacked directory to core_base
                puts "FileUtils.mv(#{dir}, #{core_base})"
                FileUtils.mv(dir, core_base)
            }
            return core_base
        end

        def activate number
            core_base = File.join(@base, number.to_s);
            current = File.join(@base, "current")
            if File.exists? current
                File.unlink(current)
            end
            FileUtils.ln_sf core_base, current
            return core_base
        end

        def deactivate number
            current = File.join(@base, "current")
            if File.exists? current
                File.unlink(current)
            end
        end

        def rollback number
            current = File.join(@base, "current")

            if File.exists? current
                File.unlink(current)
            end

            FileUtils.rm_rf File.join(@base, number.to_s)

            core_base = File.join(@base, (number - 1).to_s)
            FileUtils.ln_sf core_base, current

            return core_base
        end

        def cleanup_up_to_previous current, db
            # Keep the current and last one (for rollback)
            (1..(current - 2)).each do |number|
                key = number.to_s

                # Remove deployed bits
                FileUtils.rm_rf File.join(@base, key)

                # Cleanup the database
                db.delete_at key
            end
        end
    end
end
