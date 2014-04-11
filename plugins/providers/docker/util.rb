module VagrantPlugins
  module DockerProvider
    module Util
      def self.needs_host_machine?
        # TODO: It'd be nice to also check if Docker supports the version
        # of Linux that Vagrant is running on so that we can spin up a VM
        # on old versions of Linux as well.
        !Vagrant::Util::Platform.linux?
      end
    end
  end
end
