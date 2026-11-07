# frozen_string_literal: true

module GnomeLogs
  # Ports GlApplication: the app-level actions, their accelerators and the
  # about dialog.
  class Application
    include Translation

    ID = 'org.gnome.Logs'
    VERSION = '45.alpha'
    HELP_URI = 'help:gnome-logs'

    DESKTOP_SCHEMA = 'org.gnome.desktop.interface'
    MONOSPACE_FONT_NAME_KEY = 'monospace-font-name'
    DEFAULT_MONOSPACE_FONT = 'Monospace'

    ACCELS = {
      'win.close' => ['<Primary>w'],
      'win.search' => ['<Primary>f'],
      'win.export' => ['<Primary>e'],
      'app.help' => ['F1'],
      'app.new-window' => ['<Primary>n'],
      'win.show-help-overlay' => ['<Primary>question']
    }.freeze

    DEVELOPERS = ['David King <davidk@gnome.org>', 'Jonathan Kang <jonathan121537@gmail.com>'].freeze
    DESIGNERS = ['Jakub Steiner <jimmac@gmail.com>', 'Lapo Calamandrei <calamandrei@gmail.com>'].freeze
    COPYRIGHT = "Copyright © 2013–2015 Red Hat, Inc.\nCopyright © 2014-2015 Jonathan Kang"
    ISSUE_URL = 'https://gitlab.gnome.org/GNOME/gnome-logs/-/issues/'

    def build
      app.tap do |a|
        a.signal_connect('startup') do
          %w[new-window help about].each do |name|
            Gio::SimpleAction.new(name).tap do |action|
              action.signal_connect('activate') { public_send("on_#{name.tr('-', '_')}") }
              a.add_action(action)
            end
          end

          ACCELS.each { |action, accels| a.set_accels_for_action(action, accels) }

          load_style
          watch_monospace_font
        end

        a.signal_connect('activate') { on_new_window }
      end
    end

    def run = app.run([$PROGRAM_NAME, *ARGV])

    def on_new_window = Window.new(application: app).present

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
        about.developers = DEVELOPERS
        about.designers = DESIGNERS
        about.translator_credits = t('translator-credits')
        about.copyright = COPYRIGHT
        about.license_type = Gtk::License::GPL_3_0
        about.website = 'https://apps.gnome.org/Logs/'
        about.issue_url = ISSUE_URL
        about.comments = t('View and search logs')
        about.transient_for = app.active_window
        about.present
      end
    end

    # The C version ships style.css in a GResource; here it is read from the
    # data directory, which the installed wrapper points at and which
    # otherwise sits next to the library in a source checkout.
    #
    # GTK picks style-hc.css out of an application's resource base path by
    # itself, and nothing does that for a stylesheet on disk, so the
    # high-contrast sheet follows the style manager's setting instead.
    def load_style
      add_provider(style_provider)

      style_manager.tap do |manager|
        manager.signal_connect('notify::high-contrast') { apply_high_contrast }
      end

      apply_high_contrast
    end

    def apply_high_contrast
      if style_manager.high_contrast?
        add_provider(high_contrast_provider)
      else
        Gtk::StyleContext.remove_provider_for_display(Gdk::Display.default, high_contrast_provider)
      end
    end

    def add_provider(provider)
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default, provider, Gtk::StyleProvider::PRIORITY_APPLICATION
      )
    end

    def provider_for(path)
      Gtk::CssProvider.new.tap { |provider| provider.load(path: path) }
    end

    def style_provider = @style_provider ||= provider_for(style_path)
    def high_contrast_provider = @high_contrast_provider ||= provider_for(high_contrast_style_path)
    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    # Ports on_monospace_font_name_changed: watches
    # org.gnome.desktop.interface's monospace-font-name and keeps a
    # `.event-monospace` CSS provider matching it, so the event rows'
    # monospaced labels follow the desktop setting instead of a static rule.
    def watch_monospace_font
      add_provider(monospace_provider)

      desktop_settings&.signal_connect("changed::#{MONOSPACE_FONT_NAME_KEY}") { apply_monospace_font }

      apply_monospace_font
    end

    def apply_monospace_font = monospace_provider.load_from_data(monospace_css)

    def monospace_css = ".event-monospace { #{Util.font_description_to_css(monospace_font_description)} }"

    def monospace_font_description = Pango::FontDescription.from_string(monospace_font_name)

    def monospace_font_name
      desktop_settings ? desktop_settings[MONOSPACE_FONT_NAME_KEY] : DEFAULT_MONOSPACE_FONT
    end

    def desktop_settings
      return @desktop_settings if defined?(@desktop_settings)

      @desktop_settings = Util.desktop_schema_installed? ? Gio::Settings.new(DESKTOP_SCHEMA) : nil
    end

    def monospace_provider = @monospace_provider ||= Gtk::CssProvider.new

    def data_dir = ENV.fetch('GNOME_LOGS_DATA_DIR', File.expand_path('../../data', __dir__))
    def style_path = File.join(data_dir, 'style.css')
    def high_contrast_style_path = File.join(data_dir, 'style-hc.css')

    def app = @app ||= Gtk::Application.new(ID, :default_flags)
  end
end
