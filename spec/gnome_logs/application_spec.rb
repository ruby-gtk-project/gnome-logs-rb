# frozen_string_literal: true

# Ported from the --version slice of src/gl-application.c's
# gl_application_handle_local_options.

require 'gnome_logs/translation'
require 'gnome_logs/application'

RSpec.describe GnomeLogs::Application do
  subject(:application) { described_class.new }

  describe '#on_handle_local_options' do
    FakeOptions = Struct.new(:present) do
      def contains?(key) = key == present
    end

    it 'prints the application name and version, then reports handled (0), when --version is given' do
      expect { expect(application.on_handle_local_options(FakeOptions.new('version'))).to eq(0) }
        .to output("Logs - Version #{GnomeLogs::Application::VERSION}\n").to_stdout
    end

    it 'reports unhandled (-1) for any other invocation, so normal startup proceeds' do
      expect(application.on_handle_local_options(FakeOptions.new(nil))).to eq(-1)
    end
  end
end
