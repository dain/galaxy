require 'galaxy/config_installer'

module Galaxy
    module AgentRemoteApi
        # Command to become a specific core
        def become! requested_config_path, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy # TODO - make this configurable w/ default
            lock

            begin
                requested_config = Galaxy::SoftwareConfiguration.new_from_config_path(requested_config_path)

                # check if versioning policy allows this assignment
                unless config.config_path.nil? or config.config_path.empty?
                    current_config = Galaxy::SoftwareConfiguration.new_from_config_path(config.config_path) # TODO - this should already be tracked
                    unless versioning_policy.assignment_allowed?(current_config, requested_config)
                        error_reason = "Versioning policy does not allow this version assignment"
                        @event_dispatcher.dispatch_become_error_event error_reason
                        raise error_reason
                    end
                end

                # fetch build.properties from config store
                build_properties = @prop_builder.build(requested_config.config_path, "build.properties")
                group_id = build_properties['groupId']
                artifact_id = build_properties['artifactId']
                version = build_properties['version']
                os = build_properties['os']

                # verify build.properties
                if group_id.nil?
                    error_reason = "No groupId for #{requested_config.config_path}"
                    @event_dispatcher.dispatch_become_error_event error_reason
                    raise error_reason
                end
                if artifact_id.nil?
                    error_reason = "No groupId for #{requested_config.config_path}"
                    @event_dispatcher.dispatch_become_error_event error_reason
                    raise error_reason
                end
                if version.nil?
                    error_reason = "No version for #{requested_config.config_path}"
                    @event_dispatcher.dispatch_become_error_event error_reason
                    raise error_reason
                end
                if os and os != @os
                    error_reason = "Cannot assign #{requested_config.config_path} to #{@os} host (requires #{os})"
                    @event_dispatcher.dispatch_become_error_event error_reason
                    raise error_reason
                end


                @logger.info "Becoming #{group_id}:#{artifact_id}:#{version} with #{requested_config.config_path}"

                # todo stop! should only happen after a a successful install
                stop!

                # fetch the archive
                archive_path = @fetcher.fetch group_id, artifact_id, version

                # create config installer
                config_installer = Galaxy::ConfigInstaller.new(@repository_base, requested_config.config_path)

                # install software
                new_deployment = current_deployment_number + 1
                core_base = @deployer.deploy(new_deployment, archive_path, config_installer)
                @deployer.activate(new_deployment)
                FileUtils.rm(archive_path) if archive_path && File.exists?(archive_path)

                # update store to new installation
                new_deployment_config = OpenStruct.new(:core_type => "#{group_id}:#{artifact_id}",
                                                       :build => version,
                                                       :core_base => core_base,
                                                       :config_path => requested_config.config_path,
                                                       :auto_start => true)
                write_config new_deployment, new_deployment_config
                self.current_deployment_number = new_deployment

                # inform everyone else of the change
                # todo should this be done after the lock is released
                @event_dispatcher.dispatch_become_success_event status
                announce
                return status
            rescue Exception => e
                # todo remove archive and install directory
                error_reason = "Unable to become #{requested_config_path}: #{e}"
                @logger.error error_reason
                @event_dispatcher.dispatch_become_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Invoked by 'galaxy update-config <version>'
        def update_config! requested_version, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy # TODO - make this configurable w/ default
            lock

            begin
                @logger.info "Updating configuration to version #{requested_version}"

                if config.config_path.nil? or config.config_path.empty?
                    error_reason = "Cannot update configuration of unassigned host"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end

                current_config = Galaxy::SoftwareConfiguration.new_from_config_path(config.config_path) # TODO - this should already be tracked
                requested_config = current_config.dup
                requested_config.version = requested_version

                unless versioning_policy.assignment_allowed?(current_config, requested_config)
                    error_reason = "Versioning policy does not allow this version assignment"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end

                build_properties = @prop_builder.build(requested_config.config_path, "build.properties")
                group_id = build_properties['groupId']
                artifact_id = build_properties['artifactId']
                version = build_properties['version']

                if group_id.nil?
                    error_reason = "No groupId for #{requested_config.config_path}"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end
                if artifact_id.nil?
                    error_reason = "No groupId for #{requested_config.config_path}"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end
                if version.nil?
                    error_reason = "No version for #{requested_config.config_path}"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end

                if config.core_type != "#{group_id}:#{artifact_id}"
                    error_reason = "Binary type differs (#{config.core_type} != #{type})"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end

                if config.build != version
                    error_reason = "Binary build number differs (#{config.build} != #{version})"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end

                @logger.info "Updating configuration to #{requested_config.config_path}"

                controller = Galaxy::Controller.new config.core_base, config.config_path, @repository_base, @binaries_base, @logger
                begin
                    controller.perform! 'update-config', requested_config.config_path
                rescue Exception => e
                    error_reason = "Failed to update configuration for #{requested_config.config_path}: #{e}"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end

                @config = OpenStruct.new(:core_type => "#{group_id}:#{artifact_id}",
                                         :build => build,
                                         :core_base => config.core_base,
                                         :config_path => requested_config.config_path)

                write_config(current_deployment_number, @config)

                @event_dispatcher.dispatch_update_config_success_event status
                announce
                return status
            rescue => e
                error_reason = "Unable to update configuration to version #{requested_version}: #{e}"
                @logger.error error_reason
                @event_dispatcher.dispatch_update_config_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Rollback to the previous deployment
        def rollback!
            lock

            begin
                stop!

                if current_deployment_number > 0
                    write_config current_deployment_number, OpenStruct.new()
                    @core_base = @deployer.rollback current_deployment_number
                    self.current_deployment_number = current_deployment_number - 1
                end

                @event_dispatcher.dispatch_rollback_success_event status
                announce
                return status
            rescue => e
                error_reason = "Unable to rollback: #{e}"
                @logger.error error_reason
                @event_dispatcher.dispatch_rollback_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Cleanup up to the previous deployment
        def cleanup!
            lock

            begin
                @deployer.cleanup_up_to_previous current_deployment_number, @db
                @event_dispatcher.dispatch_cleanup_success_event status
                announce
                return status
            rescue Exception => e
                error_reason = "Unable to cleanup: #{e}"
                @logger.error error_reason
                @event_dispatcher.dispatch_cleanup_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Stop the current core
        def stop!
            lock

            begin
                if config.core_base
                    @config.state = "stopped"
                    write_config current_deployment_number, @config
                    @logger.debug "Stopping core"
                    @starter.stop! config.core_base
                end

                @event_dispatcher.dispatch_stop_success_event status
                announce
                return status
            rescue Exception => e
                error_reason = "Unable to stop: #{e}"
                error_reason += "\n#{e.message}" if e.class == Galaxy::HostUtils::CommandFailedError
                @logger.error error_reason
                @event_dispatcher.dispatch_stop_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Start the currently deployed core
        def start!
            lock

            begin
                if config.core_base
                    @config.state = "started"
                    write_config current_deployment_number, @config
                    @logger.debug "Starting core"
                    @starter.start! config.core_base
                    @config.last_start_time = time
                end

                @event_dispatcher.dispatch_start_success_event status
                announce
                return status
            rescue Exception => e
                error_reason = "Unable to start: #{e}"
                error_reason += "\n#{e.message}" if e.class == Galaxy::HostUtils::CommandFailedError
                @logger.error error_reason
                @event_dispatcher.dispatch_start_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Retart the currently deployed core
        def restart!
            lock

            begin
                if config.core_base
                    @config.state = "started"
                    write_config current_deployment_number, @config
                    @logger.debug "Restarting core"
                    @starter.restart! config.core_base
                    @config.last_start_time = time
                end

                @event_dispatcher.dispatch_restart_success_event status
                announce
                return status
            rescue Exception => e
                error_reason = "Unable to restart: #{e}"
                error_reason += "\n#{e.message}" if e.class == Galaxy::HostUtils::CommandFailedError
                @logger.error error_reason
                @event_dispatcher.dispatch_restart_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Called by the galaxy 'clear' command
        def clear!
            lock

            begin
                stop!

                @logger.debug "Clearing core"
                @deployer.deactivate current_deployment_number
                self.current_deployment_number = current_deployment_number + 1

                @event_dispatcher.dispatch_clear_success_event status
                announce
                return status
            ensure
                unlock
            end
        end

        # Invoked by 'galaxy perform <command> [arguments]'
        def perform! command, args = ''
            lock

            begin
                @logger.info "Performing command #{command} with arguments #{args}"
                controller = Galaxy::Controller.new config.core_base, config.config_path, @repository_base, @binaries_base, @logger
                output = controller.perform! command, args

                @event_dispatcher.dispatch_perform_success_event status.marshal_dump.merge!({:perform_command => command, :perform_args => args})
                announce
                return status, output
            rescue Exception => e
                error_reason = "Unable to perform command #{command}: #{e}"
                @logger.error error_reason
                @event_dispatcher.dispatch_perform_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Return a nice formatted version of Time.now
        def time
            Time.now.strftime("%m/%d/%Y %H:%M:%S")
        end
    end
end
