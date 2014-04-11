require "log4r"

require "vagrant/util/platform"

module VagrantPlugins
  module DockerProvider
    module Action
      # This action is responsible for creating the host machine if
      # we need to. The host machine is where Docker containers will
      # live.
      class HostMachine
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant::docker::hostmachine")
        end

        def call(env)
          if !Util.needs_host_machine?
            @logger.info("No host machine needed.")
            return @app.call(env)
          end

          @app.call(env)
        end
      end
    end
  end
end
