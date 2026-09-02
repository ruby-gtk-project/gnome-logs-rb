# frozen_string_literal: true

module GnomeLogs
  # org.gnome.Logs preferences. Ports the two GSettings keys the C version
  # reads: whether the journal-access warning has been dismissed for good, and
  # which way round to sort the list.
  #
  # Gio::Settings aborts the process when its schema is not installed, which is
  # exactly the situation when running from a source checkout, so every access
  # falls back to the schema's own defaults if the lookup fails.
  class Settings
    ID = 'org.gnome.Logs'
    DEFAULTS = { 'ignore-warning' => false, 'sort-order' => 'descending-time' }.freeze

    def ignore_warning? = read('ignore-warning')
    def ignore_warning! = write('ignore-warning', true)

    def sort_order = read('sort-order').to_sym

    def descending? = sort_order == :'descending-time'

    def read(key) = settings ? settings[key] : DEFAULTS.fetch(key)

    def write(key, value)
      settings&.[]=(key, value)
    end

    # Gio::SettingsSchemaSource is consulted first because instantiating
    # Gio::Settings for an unknown schema is fatal rather than an exception.
    def settings
      return @settings if defined?(@settings)

      @settings = installed? ? Gio::Settings.new(ID) : nil
    end

    def installed?
      Gio::SettingsSchemaSource.default&.lookup(ID, true) ? true : false
    rescue StandardError
      false
    end
  end
end
