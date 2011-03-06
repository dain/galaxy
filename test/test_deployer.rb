$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
$:.unshift File.join(File.dirname(__FILE__))

require 'test/unit'
require 'galaxy/deployer'
require 'galaxy/host'
require 'helper'
require 'fileutils'
require 'logger'

class TestDeployer < Test::Unit::TestCase
  
  def setup
    @core_package = Tempfile.new("package.tgz").path
    @bad_core_package = Tempfile.new("bad-package.tgz").path
    system "#{Galaxy::HostUtils.tar} -C #{File.dirname(__FILE__)} -czf #{@core_package} core_package"
    system "#{Galaxy::HostUtils.tar} -C #{File.dirname(__FILE__)} -czf #{@bad_core_package} bad_core_package"
    @path = Helper.mk_tmpdir
    @deployer = Galaxy::Deployer.new @path, Logger.new("/dev/null")
    @config_installer = MockConfigInstaller.new
  end
  
  def test_core_base_is_right    
    core_base = @deployer.deploy "2", @core_package, @config_installer
    assert_equal File.join(@path, "2"), core_base
  end
  
  def test_deployment_dir_is_made
    core_base = @deployer.deploy "2", @core_package, @config_installer
    assert FileTest.directory?(core_base)
  end
  
  def test_config_installer_invoked_on_deploy
    @deployer.deploy "2", @core_package, @config_installer
    assert @config_installer.base_path
  end
  
  def test_current_symlink_created
    core_base = @deployer.deploy "2", @core_package, @config_installer
    link = File.join(@path, "current")
    assert_equal false, FileTest.symlink?(link)
    @deployer.activate "2"
    assert FileTest.symlink?(link)
    assert_equal File.join(@path, "2"), File.readlink(link)
  end
  
  def test_upgrade
    first = @deployer.deploy "1", @core_package, @config_installer
    @deployer.activate "1"
    assert_equal File.join(@path, "1"), File.readlink(File.join(@path, "current"))
    
    first = @deployer.deploy "2", @core_package, @config_installer
    @deployer.activate "2"
    assert_equal File.join(@path, "2"), File.readlink(File.join(@path, "current"))
  end  
  
  def test_bad_archive
    assert_raise RuntimeError do
      @deployer.deploy "bad", "/etc/hosts", @config_installer
    end
  end
end
