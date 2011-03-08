$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "fileutils"
require "test/unit"
require "galaxy/binary_version"

class TestBinaryVersion < Test::Unit::TestCase

  def test_simple_gav
    bv = Galaxy::BinaryVersion.new_from_gav('my.group_id:artifact_id:version')
    assert_equal 'my.group_id:artifact_id:version', bv.gav
    assert_equal 'my.group_id', bv.group_id
    assert_equal 'artifact_id', bv.artifact_id
    assert_equal 'tar.gz', bv.packaging
    assert_nil bv.classifier
    assert_equal 'version', bv.version
    assert_equal 'my/group_id/artifact_id/version/artifact_id-version.tar.gz', bv.repository_path
    assert_equal bv, bv
    assert_equal Galaxy::BinaryVersion.new_from_gav('my.group_id:artifact_id:version'), bv
    assert_equal Galaxy::BinaryVersion.new('my.group_id', 'artifact_id', 'version'), bv
  end

  def test_packaging_gav
    bv = Galaxy::BinaryVersion.new_from_gav('my.group_id:artifact_id:packaging:version')
    assert_equal 'my.group_id:artifact_id:packaging:version', bv.gav
    assert_equal 'my.group_id', bv.group_id
    assert_equal 'artifact_id', bv.artifact_id
    assert_equal 'packaging', bv.packaging
    assert_nil bv.classifier
    assert_equal 'version', bv.version
    assert_equal 'my/group_id/artifact_id/version/artifact_id-version.packaging', bv.repository_path
    assert_equal bv, bv
    assert_equal Galaxy::BinaryVersion.new_from_gav('my.group_id:artifact_id:packaging:version'), bv
    assert_equal Galaxy::BinaryVersion.new('my.group_id', 'artifact_id', 'version', 'packaging'), bv
  end

  def test_packaging_and_classifier_gav
    bv = Galaxy::BinaryVersion.new_from_gav('my.group_id:artifact_id:packaging:classifier:version')
    assert_equal 'my.group_id:artifact_id:packaging:classifier:version', bv.gav
    assert_equal 'my.group_id', bv.group_id
    assert_equal 'artifact_id', bv.artifact_id
    assert_equal 'packaging', bv.packaging
    assert_equal 'classifier', bv.classifier
    assert_equal 'version', bv.version
    assert_equal 'my/group_id/artifact_id/version/artifact_id-version-classifier.packaging', bv.repository_path
    assert_equal bv, bv
    assert_equal Galaxy::BinaryVersion.new_from_gav('my.group_id:artifact_id:packaging:classifier:version'), bv
    assert_equal Galaxy::BinaryVersion.new('my.group_id', 'artifact_id', 'version', 'packaging', 'classifier'), bv
  end
end