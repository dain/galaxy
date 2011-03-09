module Galaxy
  class ConfigVersion
    attr_reader :environment, :component, :pool, :version

    def initialize(environment, component, version, pool=nil)
      if environment.nil? then
        raise "environment is nil"
      end
      if component.nil? then
        raise "component is nil"
      end
      if version.nil? then
        raise "version is nil"
      end

      @environment = environment
      @component = component
      @pool = pool
      @version = version
    end

    def self.new_from_config_spec(config_spec)
      unless parts = /^^@([^:]+):([^:]+)(?::([^:]+))?:([^:]+)$$/.match(config_spec)
        raise "Illegal config spec '#{config_spec}'"
      end
      environment, component, pool, version = parts[1], parts[2], parts[3], parts[4]
      new environment, component, version, pool
    end

    def config_spec
      config_spec = "@#{environment}:#{component}"
      config_spec += ':' + pool unless pool.nil?
      config_spec += ':' + version
      config_spec
    end

    def repository_path
      path = "#{environment}/#{component}"
      path += "/#{pool}" unless pool.nil?
      path += "/#{version}"
      path
    end

    def == other
      !other.nil? &&
          environment == other.environment &&
          component == other.component &&
          pool == other.pool &&
          version == other.version
    end

    def to_s()
      config_spec
    end
  end
end