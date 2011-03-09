require 'tempfile'
require 'fileutils'

require 'galaxy/binary_version'
require 'galaxy/config_version'
require 'galaxy/filter'
require 'galaxy/temp'
require 'galaxy/transport'
require 'galaxy/version'
require 'galaxy/versioning'

module Helper

  def Helper.mk_tmpdir
    Galaxy::Temp.mk_auto_dir "testing"
  end

  class Mock

    def initialize listeners={}
      @listeners = listeners
    end

    def method_missing sym, *args
      f = @listeners[sym]
      if f
        f.call(*args)
      end
    end
  end

end

class MockConsole
  def initialize agents
    @agents = agents
  end

  def shutdown
  end

  def agents filters = { :set => :all }
    filter = Galaxy::Filter.new filters
    @agents.select(&filter)
  end
end

class MockAgent
  attr_reader :host, :stopped, :started, :restarted
  attr_reader :gonsole_url, :binary_version, :config_version, :url, :agent_status, :proxy, :machine, :ip

  def initialize host, binary_version = nil, config_version = nil, gonsole_url=nil
    @host = host
    @binary_version = binary_version
    @config_version = config_version
    @gonsole_url = gonsole_url
    @stopped = @started = @restarted = false

    @url = "local://#{host}"
    Galaxy::Transport.publish @url, self

    @agent_status = 'online'
    @status = 'online'
    @proxy = Galaxy::Transport.locate(@url)

    @ip = nil
    @drb_url = nil
    @os = nil
    @machine = nil
  end

  def shutdown
    Galaxy::Transport.unpublish @url
  end

  def status
    OpenStruct.new(
          :host => @host,
          :ip => @ip,
          :url => @drb_url,
          :os => @os,
          :machine => @machine,
          :binary_version => @binary_version ? @binary_version.gav : nil ,
          :config_version => @config_version ? @config_version.config_spec : nil,
          :status => @status,
          :agent_status => 'online',
          :galaxy_version => Galaxy::Version
    )
  end

  def stop!
    @stopped = true
    status
  end

  def start!
    @started = true
    status
  end

  def restart!
    @restarted = true
    status
  end

  def become! binary_version, config_version, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy
    @binary_version = binary_version
    @config_version = config_version
    status
  end

  def update_config! new_version, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy
    # XXX We don't test the versioning code - but it should go away soon
    @config_version = Galaxy::ConfigVersion.new(@config_version.environment, @config_version.component, new_version, @config_version.pool)
    status
  end

  def check_credentials!(command, credentials)
      true
  end

  def inspect
      Galaxy::Client::SoftwareDeploymentReport.new.record_result(self)
  end
end

class MockConfigInstaller
  attr_reader :base_path

  def install(base_path)
    @base_path = base_path
  end
end
