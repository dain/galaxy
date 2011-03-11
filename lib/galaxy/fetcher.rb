require 'galaxy/temp'
require 'galaxy/host'
require 'galaxy/binary_version'
require 'rexml/document'

module Galaxy
    class Fetcher
        def initialize base_url, log
            @base, @log = base_url, log
        end

        def fetch binary_version
            if binary_version.version =~ /SNAPSHOT/
              require 'open-uri'
              core_url =  "#{@base}/#{binary_version.group_id.gsub('.', '/')}/#{binary_version.artifact_id}/#{binary_version.version}/maven-metadata.xml"
              contents = ""
              open(core_url) do |io|
                contents = io.read
              end

              maven_metadata = REXML::Document.new(contents)
              snapshot_timestamp = REXML::XPath.first(maven_metadata, '/metadata/versioning/snapshot/timestamp').text
              build_number = REXML::XPath.first(maven_metadata, '/metadata/versioning/snapshot/buildNumber').text
              artifact_version = "#{binary_version.version.gsub('-SNAPSHOT', '')}-#{snapshot_timestamp}-#{build_number}"

            else
              artifact_version = binary_version.version
            end

            core_url = "#{@base}/#{binary_version.group_id.gsub('.', '/')}/#{binary_version.artifact_id}/#{binary_version.version}/#{binary_version.artifact_id}-#{artifact_version}"
            core_url += "-#{binary_version.classifier}" unless binary_version.classifier.nil?
            core_url += ".#{binary_version.packaging}"

            tmp_file = Galaxy::Temp.mk_auto_file "galaxy-download"
            @log.info "Fetching #{core_url} into #{tmp_file}"
            if @base =~ /^http:/
                begin
                    output = Galaxy::HostUtils.system("curl -D - #{core_url} -o #{tmp_file} -s")
                rescue Galaxy::HostUtils::CommandFailedError => e
                    raise "Failed to download archive #{core_url}: #{e.message}"
                end
                status = output.first
                (protocol, response_code, response_message) = status.split
                unless response_code == '200'
                    raise "Failed to download archive #{core_url}: #{status}"
                end
            else
                open(core_url) do |io|
                    File.open(tmp_file, "w") { |f| f.write(io.read) }
                end
            end
            tmp_file
        end
    end
end
