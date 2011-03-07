require 'galaxy/report'

module Galaxy
    module Commands
        class AssignCommand < Command
            register_command "assign"
            changes_agent_state

            def initialize args, options
                super

                env, type, version = * args

                raise CommandLineError.new("<env> is missing") unless env
                raise CommandLineError.new("<type> is missing") unless type
                raise CommandLineError.new("<version> is missing") unless version

                @config_path = "/#{env}/#{type}/#{version}"
                @versioning_policy = options[:versioning_policy]
            end

            def default_filter
                {:set => :empty}
            end

            def execute_for_agent agent
                agent.proxy.become!(@config_path, @versioning_policy)
            end

            def self.help
                return <<-HELP
#{name}  <env> <type> <version>
        
        Deploy software to the selected hosts
        
        Parameters:
          env      The environment
          type     The software type
          version  The software version

        These three parameters together define the configuration path (relative to the repository base):
        
            <repository base>/<env>/<type>/<version>
                HELP
            end
        end
    end
end
