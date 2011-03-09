module Galaxy
    module Filter
        def self.new args
            filters = []

            case args[:set]
                when :all, "all"
                    filters << lambda { true }
                when :empty, "empty"
                    filters << lambda { |a| a.config_version.nil? }
                when :taken, "taken"
                    filters << lambda { |a| a.config_version }
            end

            if args[:environment] || args[:component] || args[:version]
                environment = Regexp.new('^' + (args[:environment] || ".*").to_s() +'$')
                component = Regexp.new('^' + (args[:component] || ".*").to_s() +'$')
                version = Regexp.new('^' + (args[:version] || ".*").to_s() +'$')

                filters << lambda do |a|
                  !a.config_version.nil? &&
                      a.config_version.environment =~ environment &&
                      a.config_version.component =~ component &&
                      a.config_version.version =~ version
                end
            end

            if args[:host]
                filters << lambda { |a| a.host == args[:host] }
            end

            if args[:ip]
                filters << lambda { |a| a.ip == args[:ip] }
            end

            if args[:machine]
                filters << lambda { |a| a.machine == args[:machine] }
            end

            if args[:state]
                filters << lambda { |a| a.status == args[:state] }
            end

            if args[:agent_state]
                p args[:agent_state]
                filters << lambda { |a| p a.agent_status; a.agent_status == args[:agent_state] }
            end

            lambda do |a|
                filters.inject(false) { |result, filter| result || filter.call(a) }
            end
        end
    end
end
