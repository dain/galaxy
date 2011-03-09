require 'galaxy/binary_version'
require 'galaxy/config_version'
require 'galaxy/command'
require 'galaxy/client'
require 'galaxy/report'

module Galaxy
    module Commands
        class AssignCommand < Command
            register_command "assign"
            changes_agent_state

            def initialize args, options
                super

                raise CommandLineError.new("<config_version> or <binary_version> are missing") unless args.length == 2
                if args[0].start_with?'@' 
                elsif args[1].start_with?'@'
                else
                  raise CommandLineError.new("<config_version> is missing")                  
                end
                first, second = * args
                
                raise CommandLineError.new("<config_version> is missing") unless first
                raise CommandLineError.new("<binary_version> is missing") unless second
                
                if first.start_with?('@')
                  config_version = first
                  binary_version = second
                else
                  binary_version = first
                  config_version = second
                end

                begin
                  @config_version = Galaxy::ConfigVersion.new_from_config_spec(config_version)
                rescue  
                  raise CommandLineError.new("<config_version> is invalid: #{config_version}")                  
                end

                begin
                  @binary_version = Galaxy::BinaryVersion.new_from_gav(binary_version)
                rescue  
                  raise CommandLineError.new("<binary_version> is invalid: #{binary_version}")                  
                end

                @versioning_policy = options[:versioning_policy]
            end

            def default_filter
                {:set => :empty}
            end

            def execute_for_agent agent
                agent.proxy.become!(@binary_version, @config_version, @versioning_policy)
            end

            def self.help
                return <<-HELP
#{name}  <binary_version> <config_version>
        
        Deploy software to the selected hosts
        
        Parameters:
          binary_version  The binary software version
          config_version  The configuration version

        These three parameters together define the configuration path (relative to the repository base):
        
            <repository base>/<env>/<type>/<version>
                HELP
            end
        end
    end
end
