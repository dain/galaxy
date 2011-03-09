$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'test/unit'
require 'galaxy/binary_version'
require 'galaxy/config_version'
require 'galaxy/command'
require 'galaxy/transport'
require 'helper'

class TestCommands < Test::Unit::TestCase
  def setup
    @agents = [
      MockAgent.new("agent1", Galaxy::BinaryVersion.new_from_gav("my.group:sysc:4.0"), Galaxy::ConfigVersion.new_from_config_spec("@alpha:sysc:1.0")),
      MockAgent.new("agent2", Galaxy::BinaryVersion.new_from_gav("my.group:idtc:5.0"), Galaxy::ConfigVersion.new_from_config_spec("@alpha:idtc:1.0")),
      MockAgent.new("agent3", Galaxy::BinaryVersion.new_from_gav("my.group:appc:6.0"), Galaxy::ConfigVersion.new_from_config_spec("@alpha:appc/aclu0:1.0")),
      MockAgent.new("agent4"),
      MockAgent.new("agent5", Galaxy::BinaryVersion.new_from_gav("my.group:sysc:7.0"), Galaxy::ConfigVersion.new_from_config_spec("@alpha:sysc:2.0")),
      MockAgent.new("agent6", Galaxy::BinaryVersion.new_from_gav("my.group:sysc:8.0"), Galaxy::ConfigVersion.new_from_config_spec("@beta:sysc:1.0")),
      MockAgent.new("agent7")
    ]

    @console = MockConsole.new(@agents)
  end

  def teardown
    @agents.each { |a| a.shutdown }
    @console.shutdown
  end

  def test_all_registered
    assert Galaxy::Commands["assign"]
    assert Galaxy::Commands["clear"]
    assert Galaxy::Commands["reap"]
    assert Galaxy::Commands["restart"]
    assert Galaxy::Commands["rollback"]
    assert Galaxy::Commands["show"]
    assert Galaxy::Commands["ssh"]
    assert Galaxy::Commands["start"]
    assert Galaxy::Commands["stop"]
    assert Galaxy::Commands["update"]
    assert Galaxy::Commands["update-config"]
  end

  def internal_test_all_for cmd
    command = Galaxy::Commands[cmd].new [], {:console => @console}
    agents = command.select_agents(:set => :all)
    command.execute agents

    @agents.select { |a| a.config_version }.each { |a| assert_equal true, yield(a) }
    @agents.select { |a| a.config_version.nil? }.each { |a| assert_equal false, yield(a) }
  end

  def internal_test_by_host cmd
    command = Galaxy::Commands[cmd].new [], {:console => @console}
    agents = command.select_agents(:host => "agent1")
    command.execute agents

    @agents.select {|a| a.host == "agent1" }.each { |a| assert_equal true, yield(a) }
    @agents.select {|a| a.host != "agent1" }.each { |a| assert_equal false, yield(a) }
  end

  def internal_test_by_component cmd
    command = Galaxy::Commands[cmd].new [], {:console => @console}
    agents = command.select_agents(:component => "sysc")
    command.execute agents

    @agents.select {|a| a.config_version && a.config_version.component == "sysc" }.each { |a| assert_equal true, yield(a) }
    @agents.select {|a| a.config_version && a.config_version.component != "sysc" }.each { |a| assert_equal false, yield(a) }
  end

  def test_stop_all
    internal_test_all_for("stop") { |a| a.stopped }
  end

  def test_start_all
    internal_test_all_for("start") { |a| a.started }
  end

  def test_restart_all
    internal_test_all_for("restart") { |a| a.restarted }
  end

  def test_stop_by_host
    internal_test_by_host("stop") { |a| a.stopped }
  end

  def test_start_by_host
    internal_test_by_host("start") { |a| a.started }
  end

  def test_restart_by_host
    internal_test_by_host("restart") { |a| a.restarted }
  end

  def test_stop_by_component
    internal_test_by_component("stop") { |a| a.stopped }
  end

  def test_start_by_component
    internal_test_by_component("start") { |a| a.started }
  end

  def test_restart_by_component
    internal_test_by_component("restart") { |a| a.restarted }
  end

  def test_show_all
    command = Galaxy::Commands["show"].new [], {:console => @console}
    agents = command.select_agents(:set => :all)
    results = command.execute agents

    assert_equal format_agents, results
  end

  def test_show_by_env
    command = Galaxy::Commands["show"].new [], {:console => @console}
    agents = command.select_agents(:environment => "alpha")
    results = command.execute agents

    assert_equal format_agents(@agents.select {|a| a.config_version && a.config_version.environment == "alpha"}), results
  end

  def test_show_by_version
    command = Galaxy::Commands["show"].new [], {:console => @console, :version => "1.0"}
    agents = command.select_agents(:version => "1.0")
    results = command.execute agents

    assert_equal format_agents(@agents.select {|a| a.config_version && a.config_version.version == "1.0"}), results
  end

  def test_show_by_component
    command = Galaxy::Commands["show"].new [], {:console => @console}
    agents = command.select_agents(:component => :sysc)
    results = command.execute agents

    assert_equal format_agents(@agents.select {|a| a.config_version && a.config_version.component == "sysc"}), results
  end

  def test_show_by_component2
    command = Galaxy::Commands["show"].new [], {:console => @console}
    agents = command.select_agents(:component => "appc/aclu0")
    results = command.execute agents

    assert_equal format_agents(@agents.select {|a| a.config_version && a.config_version.component == "appc/aclu0"}), results
  end

  def test_show_by_env_version_component
    command = Galaxy::Commands["show"].new [], {:console => @console}
    agents = command.select_agents({:component => "sysc", :environment => "alpha", :version => "1.0"})
    results = command.execute agents

    assert_equal format_agents(@agents.select {|a| a.config_version && a.config_version.environment == "alpha" && a.config_version.component == "sysc" && a.config_version.version == "1.0"}), results
  end

  def test_assign_empty
    command = Galaxy::Commands["assign"].new ["my.group:test:1.0-12345", "@beta:rslv:3.0"], {:console => @console, :set => :empty}
    agents = command.select_agents(:set => :all)
    agent = @agents.select { |a| a.config_version.nil? }.first
    command.execute agents

    assert_equal Galaxy::BinaryVersion.new_from_gav("my.group:test:1.0-12345"), agent.binary_version
    assert_equal Galaxy::ConfigVersion.new_from_config_spec("@beta:rslv:3.0"), agent.config_version
  end

  def test_assign_by_host
    agent = @agents.select { |a| a.host == "agent7" }.first

    command = Galaxy::Commands["assign"].new ["my.group:test:1.0-12345", "@beta:rslv:3.0"], { :console => @console }
    agents = command.select_agents(:host => agent.host)
    command.execute agents

    assert_equal Galaxy::BinaryVersion.new_from_gav("my.group:test:1.0-12345"), agent.binary_version
    assert_equal Galaxy::ConfigVersion.new_from_config_spec("@beta:rslv:3.0"), agent.config_version
  end

  def test_assign_by_host_reverse_args
    agent = @agents.select { |a| a.host == "agent7" }.first

    command = Galaxy::Commands["assign"].new ["@beta:rslv:3.0", "my.group:test:1.0-12345", ], { :console => @console }
    agents = command.select_agents(:host => agent.host)
    command.execute agents

    assert_equal Galaxy::BinaryVersion.new_from_gav("my.group:test:1.0-12345"), agent.binary_version
    assert_equal Galaxy::ConfigVersion.new_from_config_spec("@beta:rslv:3.0"), agent.config_version
  end

  def test_clear
    # TODO
  end

  def test_clear_by_host
    # TODO
  end

  def test_update_by_host
    agent = @agents.select { |a| !a.config_version.nil? }.first
    binary_version = agent.binary_version
    config_version = agent.config_version

    command = Galaxy::Commands["update"].new ["4.0"], { :console => @console }
    agents = command.select_agents(:host => agent.host)
    command.execute agents

    assert_not_nil agent.binary_version
    assert_equal binary_version.version, '4.0'
    assert_equal binary_version.group_id, agent.binary_version.group_id
    assert_equal binary_version.artifact_id, agent.binary_version.artifact_id
    assert_equal binary_version.packaging, agent.binary_version.packaging
    assert_equal binary_version.classifier, agent.binary_version.classifier

    assert_not_nil agent.config_version
    assert_equal config_version, agent.config_version
  end

  def test_update_config_by_host
    agent = @agents.select { |a| !a.config_version.nil? }.first
    env = agent.config_version.environment
    component = agent.config_version.component

    command = Galaxy::Commands["update-config"].new ["4.0"], { :console => @console }
    agents = command.select_agents(:version => "1.0")
    results = command.execute agents

    assert_not_nil agent.config_version
    assert_equal env, agent.config_version.environment
    assert_equal component, agent.config_version.component
    assert_equal "4.0", agent.config_version.version
  end

  private

  def format_agents(agents=@agents)
    res = agents.inject("") do |memo, a|
        memo.empty? ? a.inspect : memo.to_s + a.inspect
    end
    res
  end
end
