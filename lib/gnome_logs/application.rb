# frozen_string_literal: true

module GnomeLogs
  # Ports GlApplication: the app-level actions, their accelerators and the
  # about dialog.
  class Application
    include Translation

    ID = 'org.gnome.Logs'
    VERSION = '45.alpha'
    HELP_URI = 'help:gnome-logs'

    ACCELS = {
      'win.close' => ['<Primary>w'],
      'win.search' => ['<Primary>f'],
      'win.export' => ['<Primary>e'],
      'app.help' => ['F1'],
      'app.new-window' => ['<Primary>n'],
      'app.quit' => ['<Primary>q'],
      'win.show-help-overlay' => ['<Primary>question']
    }.freeze

    def build
      app.tap do |a|
        a.signal_connect('startup') do
          %w[new-window help about quit].each do |name|
            Gio::SimpleAction.new(name).tap do |action|
              action.signal_connect('activate') { public_send("on_#{name.tr('-', '_')}") }
              a.add_action(action)
            end
          end

          ACCELS.each { |action, accels| a.set_accels_for_action(action, accels) }

          load_style
        end

        a.signal_connect('activate') { on_new_window }
      end
    end

    def run = app.run([$PROGRAM_NAME, *ARGV])

    def on_new_window = Window.new(application: app).present
    def on_quit = app.quit

    def on_help
      Gtk::UriLauncher.new(HELP_URI).tap do |launcher|
        launcher.launch(app.active_window) do |_, result|
          report_launch_failure(launcher, result)
        end
      end
    end

    # Ports on_help's error path: the C version raises an alert dialog when the
    # help URI cannot be opened, so a silent failure is not an option.
    def report_launch_failure(launcher, result)
      launcher.launch_finish(result)
    rescue StandardError => e
      warn("Failed to open the given help URI: #{e.message}")
    end

    def on_about
      Adwaita::AboutWindow.new.tap do |about|
        about.application_name = t('Logs')
        about.application_icon = ID
        about.version = VERSION
        about.developer_name = t('The GNOME Project')
        about.license_type = Gtk::License::GPL_3_0
        about.website = 'https://apps.gnome.org/Logs/'
        about.comments = t('View and search logs')
        about.transient_for = app.active_window
        about.present
      end
    end

    # The C version ships style.css in a GResource; here it is read from the
    # data directory, which the installed wrapper points at and which
    # otherwise sits next to the library in a source checkout.
    def load_style
      Gtk::CssProvider.new.tap do |provider|
        provider.load(path: style_path)
        Gtk::StyleContext.add_provider_for_display(
          Gdk::Display.default, provider, Gtk::StyleProvider::PRIORITY_APPLICATION
        )
      end
    end

    def data_dir = ENV.fetch('GNOME_LOGS_DATA_DIR', File.expand_path('../../data', __dir__))
    def style_path = File.join(data_dir, 'style.css')

    def app = @app ||= Gtk::Application.new(ID, :default_flags)
  end
end
