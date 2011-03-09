require 'galaxy/binary_version'
require 'galaxy/config_version'
require 'galaxy/command'
require 'galaxy/client'

module Galaxy
    module Commands
        class UpdateCommand < Command
            register_command "update"
            changes_agent_state

            def initialize args, options
                super
                @requested_version = args.first
                raise CommandLineError.new("Must specify version") unless @requested_version
                @versioning_policy = options[:versioning_policy]
            end

            def normalize_filter filter
                filter = super
                filter[:set] = :taken if filter[:set] == :all
                filter
            end

            def execute_for_agent agent
                if agent.config_version.nil?
                    raise "Cannot update unassigned agent"
                end

                binary_version = Galaxy::BinaryVersion.new_from_gav(agent.binary_version)
                requested_binary_config = Galaxy::BinaryVersion.new(binary_version.group_id, binary_version.artifact_id, @requested_version, binary_version.packaging, binary_version.classifier)

                config_version = Galaxy::ConfigVersion.new_from_config_spec(agent.config_version) # TODO - this should already be tracked
                agent.proxy.become!(requested_binary_config, config_version, @versioning_policy)
            end

            def self.help
                return <<-HELP
#{name}  <version>
      
        Stop and update the binary software on the selected hosts to the specified version
                HELP
            end
        end
    end
end
