require "vagrant/util/shell_quote"

module VagrantPlugins
  module DockerProvider
    module Executor
      # The Vagrant executor runs Docker over SSH against the given
      # Vagrant-managed machine.
      class Vagrant
        def initialize(host_machine)
          @host_machine = host_machine
        end

        def execute(*cmd, &block)
          quote = '"'
          cmd   = cmd.map do |a|
            "#{quote}#{::Vagrant::Util::ShellQuote.escape(a, quote)}#{quote}"
          end.join(" ")

          stderr = ""
          stdout = ""
          comm   = @host_machine.communicate
          code   = comm.execute(cmd, error_check: false) do |type, data|
            next if ![:stdout, :stderr].include?(type)
            block.call(type, data) if block
            stderr << data if type == :stderr
            stdout << data if type == :stdout
          end

          if code != 0
            raise Errors::ExecuteError,
              command: cmd,
              stderr: stderr,
              stdout: stdout
          end

          stdout
        end
      end
    end
  end
end
