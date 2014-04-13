require "log4r"

require "vagrant/util/platform"
require "vagrant/util/silence_warnings"

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

          return @app.call(env)
          env[:machine].ui.output(I18n.t(
            "docker_provider.host_machine_needed"))

          # TODO(mitchellh): process-level lock so that we don't
          # step on parallel Vagrant's toes.

          # TODO(mitchellh): copy the default Vagrantfile to the env
          # data dir so that we aren't writing into Vagrant's install
          # directory, which we can't do.

          # Get the path to the Vagrantfile that we're going to use
          vf_path = env[:machine].provider_config.vagrant_vagrantfile
          vf_path ||= File.expand_path("../../hostmachine/Vagrantfile", __FILE__)
          vf_file = File.basename(vf_path)
          vf_path = File.dirname(vf_path)

          # The name of the machine we want
          host_machine_name = env[:machine].provider_config.vagrant_machine
          host_machine_name ||= :default

          # Create the env to manage this machine
          host_machine = Vagrant::Util::SilenceWarnings.silence! do
            host_env = Vagrant::Environment.new(
              cwd: vf_path,
              home_path: env[:machine].env.home_path,
              ui_class: env[:machine].env.ui_class,
              vagrantfile_name: vf_file,
            )

            # TODO(mitchellh): configure the provider of this machine somehow
            host_env.machine(host_machine_name, :virtualbox)
          end

          # See if the machine is ready already.
          if host_machine.communicate.ready?
            env[:machine].ui.detail(I18n.t("docker_provider.host_machine_ready"))
            return @app.call(env)
          end

          # Create a UI for this machine that stays at the detail level
          proxy_ui = host_machine.ui.dup
          proxy_ui.opts[:bold] = false
          proxy_ui.opts[:prefix_spaces] = true
          proxy_ui.opts[:target] = env[:machine].name.to_s

          env[:machine].ui.detail(
            I18n.t("docker_provider.host_machine_starting"))
          env[:machine].ui.detail(" ")

          host_machine.with_ui(proxy_ui) do
            host_machine.action(:up)
          end

          @app.call(env)
        end
      end
    end
  end
end
