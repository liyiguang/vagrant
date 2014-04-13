require "log4r"

require "vagrant/util/silence_warnings"

module VagrantPlugins
  module DockerProvider
    class Provider < Vagrant.plugin("2", :provider)
      def initialize(machine)
        @logger  = Log4r::Logger.new("vagrant::provider::docker")
        @machine = machine
      end

      # @see Vagrant::Plugin::V2::Provider#action
      def action(name)
        action_method = "action_#{name}"
        return Action.send(action_method) if Action.respond_to?(action_method)
        nil
      end

      # Returns the driver instance for this provider.
      def driver
        return @driver if @driver
        @driver = Driver.new

        # If we are running on a host machine, then we set the executor
        # to execute remotely.
        if host_vm?
          @driver.executor = Executor::Vagrant.new(host_vm)
        end

        @driver
      end

      # This returns the {Vagrant::Machine} that is our host machine.
      # It does not perform any action on the machine or verify it is
      # running.
      #
      # @return [Vagrant::Machine]
      def host_vm
        return @host_vm if @host_vm

        vf_path = @machine.provider_config.vagrant_vagrantfile
        vf_path ||= File.expand_path("../hostmachine/Vagrantfile", __FILE__)
        vf_file = File.basename(vf_path)
        vf_path = File.dirname(vf_path)

        # The name of the machine we want
        host_machine_name = @machine.provider_config.vagrant_machine
        host_machine_name ||= :default

        # Create the env to manage this machine
        @host_vm = Vagrant::Util::SilenceWarnings.silence! do
          host_env = Vagrant::Environment.new(
            cwd: vf_path,
            home_path: @machine.env.home_path,
            ui_class: @machine.env.ui_class,
            vagrantfile_name: vf_file,
          )

          # TODO(mitchellh): configure the provider of this machine somehow
          host_env.machine(host_machine_name, :virtualbox)
        end

        @host_vm
      end

      # This says whether or not Docker will be running within a VM
      # rather than directly on our system. Docker needs to run in a VM
      # when we're not on Linux, or not on a Linux that supports Docker.
      def host_vm?
        # TODO: It'd be nice to also check if Docker supports the version
        # of Linux that Vagrant is running on so that we can spin up a VM
        # on old versions of Linux as well.
        !Vagrant::Util::Platform.linux?
      end

      # Returns the SSH info for accessing the Container.
      def ssh_info
        # If the Container is not created then we cannot possibly SSH into it, so
        # we return nil.
        return nil if state == :not_created

        network = driver.inspect_container(@machine.id)['NetworkSettings']
        ip      = network['IPAddress']

        # If we were not able to identify the container's IP, we return nil
        # here and we let Vagrant core deal with it ;)
        return nil unless ip

        {
          :host => ip,
          :port => @machine.config.ssh.guest_port
        }
      end

      def state
        state_id = nil
        state_id = :not_created if !@machine.id || !driver.created?(@machine.id)
        state_id = driver.state(@machine.id) if @machine.id && !state_id
        state_id = :unknown if !state_id

        short = state_id.to_s.gsub("_", " ")
        long  = I18n.t("vagrant.commands.status.#{state_id}")

        Vagrant::MachineState.new(state_id, short, long)
      end

      def to_s
        id = @machine.id ? @machine.id : "new container"
        "Docker (#{id})"
      end
    end
  end
end
