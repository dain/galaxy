module Galaxy
  module Versioning
    class StrictVersioningPolicy
      def self.assignment_allowed? current_binary_version, requested_binary_version, current_config_version, requested_config_version
        # can not upgrade to the exact same version and config
        if current_binary_version.group_id == requested_binary_version.group_id and
            current_binary_version.artifact_id == requested_binary_version.artifact_id and
            current_binary_version.packaging == requested_binary_version.packaging and
            current_binary_version.classifier == requested_binary_version.classifier and
            current_config_version.component == requested_config_version.component and
            current_config_version.pool == requested_config_version.pool

          return current_config_version.version != requested_config_version.version || current_binary_version.version != requested_binary_version.version
        end
        true
      end
    end

    class RelaxedVersioningPolicy
      def self.assignment_allowed? current_binary_version, requested_binary_version, current_config_version, requested_config_version
        true
      end
    end
  end
end
