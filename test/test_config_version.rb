$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "fileutils"
require "test/unit"
require "galaxy/config_version"

class TestConfigVersion < Test::Unit::TestCase
  def test_simple_config_version
    cv = Galaxy::ConfigVersion.new_from_config_spec('@environment:component:version')
    assert_equal '@environment:component:version', cv.config_spec
    assert_equal 'environment', cv.environment
    assert_equal 'component', cv.component
    assert_nil cv.pool
    assert_equal 'version', cv.version
    assert_equal 'environment/component/version', cv.repository_path
    assert_equal cv, cv
    assert_equal Galaxy::ConfigVersion.new_from_config_spec('@environment:component:version'), cv
    assert_equal Galaxy::ConfigVersion.new('environment', 'component', 'version'), cv
  end

  def test_pool_config_version
    cv = Galaxy::ConfigVersion.new_from_config_spec('@environment:component:pool:version')
    assert_equal '@environment:component:pool:version', cv.config_spec
    assert_equal 'environment', cv.environment
    assert_equal 'component', cv.component
    assert_equal 'pool', cv.pool
    assert_equal 'version', cv.version
    assert_equal 'environment/component/pool/version', cv.repository_path
    assert_equal cv, cv
    assert_equal Galaxy::ConfigVersion.new_from_config_spec('@environment:component:pool:version'), cv
    assert_equal Galaxy::ConfigVersion.new('environment', 'component', 'version', 'pool'), cv
  end
end