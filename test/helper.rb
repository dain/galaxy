require 'tempfile'
require 'fileutils'

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
  attr_reader :host, :config_path, :stopped, :started, :restarted
  attr_reader :gonsole_url, :env, :type, :version, :url, :agent_status, :proxy, :group_id, :artifact_id, :binary_version, :machine, :ip

  def initialize host, env = nil, type = nil, version = nil, gonsole_url=nil
    @host = host
    @env = env
    @type = type
    @version = version
    @gonsole_url = gonsole_url
    @stopped = @started = @restarted = false

    @url = "local://#{host}"
    Galaxy::Transport.publish @url, self

    @config_path = nil
    @config_path = "/#{env}/#{type}/#{version}" unless env.nil? || type.nil? || version.nil?
    @agent_status = 'online'
    @status = 'online'
    @proxy = Galaxy::Transport.locate(@url)
    @group_id = 'my.group'
    @artifact_id = 'test'
    @binary_version = "1.2.3"

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
          :group_id => @group_id,
          :artifact_id => @artifact_id,
          :version => @binary_version,
          :config_path => @config_path,
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

  def become! path, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy
    md = %r!^/([^/]+)/(.*)/([^/]+)$!.match path
    new_env, new_type, new_version = md[1], md[2], md[3]
    # XXX We don't test the versioning code - but it should go away soon
    #raise if @version == new_version
    @env = new_env
    @type = new_type
    @version = new_version
    @config_path = "/#{@env}/#{@type}/#{@version}"
    status
  end

  def update_config! new_version, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy
    # XXX We don't test the versioning code - but it should go away soon
    #raise if @version == new_version
    @version = new_version
    @config_path = "/#{@env}/#{@type}/#{@version}"
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
