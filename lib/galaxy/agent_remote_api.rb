require 'galaxy/config_installer'
require 'galaxy/config_version'
require 'galaxy/binary_version'

module Galaxy
    module AgentRemoteApi
        # Command to become a specific core
        def become!(binary_version, config_version, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy) # TODO - make this configurable w/ default
            raise "binary_version is nil" unless binary_version
            raise "config_version is nil" unless config_version

            lock

            begin
                # check if versioning policy allows this assignment
                unless config.config_version.nil? or config.config_version.empty?
                    current_config_version = Galaxy::ConfigVersion.new_from_config_spec(config.config_version)
                    current_binary_version = Galaxy::BinaryVersion.new_from_gav(config.binary_version)
                    unless versioning_policy.assignment_allowed?(current_binary_version, binary_version, current_config_version, config_version)
                        error_reason = "Versioning policy does not allow this version assignment"
                        @event_dispatcher.dispatch_become_error_event error_reason
                        raise error_reason
                    end
                end

                @logger.info "Becoming #{binary_version} with #{config_version}"

                # todo stop! should only happen after a a successful install
                stop!

                # fetch the archive
                archive_path = @fetcher.fetch binary_version

                # create config installer
                config_installer = Galaxy::ConfigInstaller.new(@repository_base, config_version)

                # install software
                new_deployment = current_deployment_number + 1
                core_base = @deployer.deploy(new_deployment, archive_path, config_installer)
                @deployer.activate(new_deployment)
                FileUtils.rm(archive_path) if archive_path && File.exists?(archive_path)

                # update store to new installation
                new_deployment_config = OpenStruct.new(
                    :binary_version => binary_version.gav,
                    :config_version => config_version.config_spec,
                    :core_base => core_base,
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
                error_reason = "Unable to become #{binary_version} with #{config_version}: #{e}"
                @logger.error error_reason
                @event_dispatcher.dispatch_become_error_event error_reason
                raise error_reason
            ensure
                unlock
            end
        end

        # Invoked by 'galaxy update-config <version>'
        def update_config! requested_version, versioning_policy = Galaxy::Versioning::StrictVersioningPolicy # TODO - make this configurable w/ default
            raise "requested_version is nil" unless requested_version

            lock

            begin
                @logger.info "Updating configuration to version #{requested_version}"

                if config.config_version.nil? or config.config_version.empty?
                    error_reason = "Cannot update configuration of unassigned host"
                    @event_dispatcher.dispatch_update_config_error_event error_reason
                    raise error_reason
                end

                binary_version = Galaxy::BinaryVersion.new_from_gav(config.binary_version)
                current_config_version = Galaxy::ConfigVersion.new_from_config_spec(config.config_version) # TODO - this should already be tracked
                requested_config_version = Galaxy::ConfigVersion.new(current_config_version.environment, current_config_version.component, requested_version, current_config_version.pool)

#                unless versioning_policy.assignment_allowed?(current_config, requested_config)
#                    error_reason = "Versioning policy does not allow this version assignment"
#                    @event_dispatcher.dispatch_update_config_error_event error_reason
#                    raise error_reason
#                end

                @logger.info "Updating configuration to #{requested_config_version}"

                config_installer = Galaxy::ConfigInstaller.new(@repository_base, requested_config_version)
                config_installer.install(config.core_base)

                @config = OpenStruct.new(
                    :binary_version => binary_version,
                    :config_version => requested_config_version.config_spec,
                    :core_base => config.core_base)
                write_config(current_deployment_number, @config)

                @event_dispatcher.dispatch_update_config_success_event status
                announce
                return status
            rescue => e
                error_reason = "Unable to update configuration to version #{requested_config_version}: #{e}"
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
                config_version = Galaxy::ConfigVersion.new_from_config_spec(config.config_version)
                controller = Galaxy::Controller.new config.core_base, config_version.repository_path, @repository_base, @binaries_base, @logger
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
