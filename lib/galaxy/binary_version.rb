module Galaxy
  class BinaryVersion
    attr_reader :group_id, :artifact_id, :packaging, :classifier, :version

    def initialize(group_id, artifact_id, version, packaging='tar.gz', classifier=nil)
      if group_id.nil? then
        raise "group_id is nil"
      end
      if artifact_id.nil? then
        raise "artifact_id is nil"
      end
      if version.nil? then
        raise "version is nil"
      end
      if packaging.nil? then
        raise "packaging is nil"
      end

      @group_id = group_id
      @artifact_id = artifact_id
      @classifier = classifier
      @packaging = packaging
      @version = version
    end

    def self.new_from_gav(gav)
      unless components = /^([^:]+):([^:]+)(?::([^:]+))?(?::([^:]+))?:([^:]+)$/.match(gav)
        raise "Illegal binary version '#{gav}'"
      end
      group_id, artifact_id, packaging, classifier, version = components[1], components[2], components[3], components[4], components[5]
      if packaging.nil?
        packaging = 'tar.gz'
      end
      new group_id, artifact_id, version, packaging, classifier
    end

    def gav
      gav = "#{group_id}:#{artifact_id}"
      gav += ':' + packaging unless packaging == 'tar.gz'
      gav += ':' + classifier unless classifier.nil?
      gav += ':' + version
      gav
    end

    def repository_path
      path = "#{group_id.gsub('.', '/')}/#{artifact_id}/#{version}/#{artifact_id}-#{version}"
      path += "-#{classifier}" unless classifier.nil?
      path += ".#{packaging}"
      path
    end

    def == other
      !other.nil? &&
          group_id == other.group_id &&
          artifact_id == other.artifact_id &&
          packaging == other.packaging &&
          classifier == other.classifier &&
          version == other.version
    end

    def to_s()
      gav
    end
  end
end