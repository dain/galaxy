require 'galaxy/binary_version'
require 'galaxy/report'

module Galaxy
    module Commands
        class AssignCommand < Command
            register_command "assign"
            changes_agent_state

            def initialize args, options
                super

                env, type, version, binary_version = * args

                raise CommandLineError.new("<env> is missing") unless env
                raise CommandLineError.new("<type> is missing") unless type
                raise CommandLineError.new("<version> is missing") unless version
                raise CommandLineError.new("<binary_version> is missing") unless binary_version

                @config_path = "/#{env}/#{type}/#{version}"
                @binary_version = Galaxy::BinaryVersion.new_from_gav(binary_version)
                @versioning_policy = options[:versioning_policy]
            end

            def default_filter
                {:set => :empty}
            end

            def execute_for_agent agent
                agent.proxy.become!(@config_path, @binary_version, @versioning_policy)
            end

            def self.help
                return <<-HELP
#{name}  <env> <type> <version> <binary_version>
        
        Deploy software to the selected hosts
        
        Parameters:
          env             The environment
          type            The configuration type
          version         The configuration version
          binary_version  The binary software version

        These three parameters together define the configuration path (relative to the repository base):
        
            <repository base>/<env>/<type>/<version>
                HELP
            end
        end
    end
end
