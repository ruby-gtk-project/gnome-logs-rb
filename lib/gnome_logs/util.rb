# frozen_string_literal: true

require 'gio2'
require_relative 'translation'

module GnomeLogs
  # Ported from src/gl-util.c.
  #
  # The timestamp formatting helpers, the journal storage probes and the uid
  # lookup. Everything is a module method, because the C functions are free
  # functions with no state of their own, and the one preference they consult
  # — the desktop clock format — is read fresh each time, as the C version
  # does.
  #
  # Three deliberate differences from the C version:
  #
  # * sd_id128_get_machine needs libsystemd, which Ruby cannot link against
  #   here, so the machine id is read from /etc/machine-id (and the older dbus
  #   location). It is the same 32 hex digits in the same format.
  # * Ruby's Time#strftime is not locale aware, so %b and %p render in English
  #   whatever the locale is. The format strings themselves are still
  #   translated, so the order of the fields follows the locale.
  # * pango_font_description_to_css has no counterpart: the C version used it
  #   to turn the desktop monospace font into a CSS fragment at run time, and
  #   data/style.css declares `font-family: monospace` instead.
  module Util
    extend Translation

    # GLib has padded %e and %l with U+2007 FIGURE SPACE since 2.73.1, where
    # Ruby's strftime pads with an ASCII space, so the padding is substituted
    # into the pattern before strftime sees it.
    FIGURE_SPACE = "\u2007"

    DESKTOP_SCHEMA = 'org.gnome.desktop.interface'
    CLOCK_FORMAT_KEY = 'clock-format'

    # GlUtilClockFormat, keyed by the nicknames of the clock-format enum in
    # the org.gnome.desktop.interface schema.
    CLOCK_FORMATS = { '24h' => :twenty_four_hour, '12h' => :twelve_hour }.freeze

    # GL_UTIL_CLOCK_FORMAT_24HR is the first member of the C enum, so it is
    # what g_settings_get_enum falls back to when the schema is missing.
    DEFAULT_CLOCK_FORMAT = :twenty_four_hour

    USEC_PER_SECOND = 1_000_000

    MACHINE_ID_PATHS = ['/etc/machine-id', '/var/lib/dbus/machine-id'].freeze

    # GlJournalStorage, and the directory whose existence identifies each
    # storage type. Volatile is checked first, as gl_util_journal_storage_type
    # does.
    STORAGE_DIRS = { volatile: '/run/log/journal', persistent: '/var/log/journal' }.freeze

    # The patterns are the C version's msgids, so the po/ catalogues carried
    # over from the C version keep translating them.
    FORMATS = {
      twelve_hour: {
        same_day: { seconds: '%l:%M:%S %p', no_seconds: '%l:%M %p' },
        same_year: { seconds: '%b %e %l:%M:%S %p', no_seconds: '%b %e %l:%M %p' },
        different_year: { seconds: '%b %e %Y %l:%M:%S %p', no_seconds: '%b %e %Y %l:%M %p' }
      },
      twenty_four_hour: {
        same_day: { seconds: '%H:%M:%S', no_seconds: '%H:%M' },
        same_year: { seconds: '%b %e %H:%M:%S', no_seconds: '%b %e %H:%M' },
        different_year: { seconds: '%b %e %Y %H:%M:%S', no_seconds: '%b %e %Y %H:%M' }
      }
    }.freeze

    # Ports gl_util_timestamp_to_display: a human readable time for
    # +microsecs+, with the elements that +now+ makes redundant left out.
    #
    # Callers that format a whole list of timestamps read #clock_format once
    # and pass it in, which is what the C version's cached priv->clock_format
    # amounts to.
    def self.timestamp_to_display(microsecs, now = Time.now, format = clock_format, show_second: false)
      Time.at(microsecs.to_i / USEC_PER_SECOND).then do |local|
        pattern = t(pattern_for(compare_timestamps(local, now), format, show_second))

        local.strftime(expand_padding(local, pattern))
      end
    end

    # Ports gl_util_boot_time_to_display: the span a boot covers.
    def self.boot_time_to_display(realtime_first, realtime_last)
      Time.now.then do |now|
        # Translators: the first string is the earliest timestamp of the boot,
        # and the second string is the newest timestamp. An example string
        # might be '08:10 - 08:30'
        format(
          t('%s – %s'),
          timestamp_to_display(realtime_first, now),
          timestamp_to_display(realtime_last, now)
        )
      end
    end

    # Ports gl_util_get_uid.
    def self.uid = Process.uid

    # Ports gl_util_journal_storage_type: where the journal keeps its files,
    # which decides which warning the window shows.
    def self.journal_storage_type
      if machine_id.empty?
        :none
      else
        STORAGE_DIRS.find { |_type, dir| File.exist?(File.join(dir, machine_id)) }.then do |found|
          found ? found.first : :none
        end
      end
    end

    # Ports gl_util_can_read_system_journal.
    def self.can_read_system_journal?(storage_type = journal_storage_type)
      File.readable?(system_journal_path(storage_type))
    end

    # Ports gl_util_can_read_user_journal. Only the persistent location is
    # looked at, as in the C version: a volatile journal has no per-user file.
    def self.can_read_user_journal?
      File.readable?(File.join(STORAGE_DIRS.fetch(:persistent), machine_id, "user-#{uid}.journal"))
    end

    # The C version probes /dev/null when there is no journal at all, and
    # /dev/null is readable, so GL_JOURNAL_STORAGE_NONE reports that the
    # system journal can be read. The window never asks in that case: it
    # reports "No logs available" instead.
    def self.system_journal_path(storage_type)
      if STORAGE_DIRS.key?(storage_type)
        File.join(STORAGE_DIRS.fetch(storage_type), machine_id, 'system.journal')
      else
        File::NULL
      end
    end

    # The machine id systemd generates, which names the per-machine journal
    # directory. An empty string means no id could be read, and then there is
    # no journal directory to find either.
    def self.machine_id
      MACHINE_ID_PATHS.filter_map { |path| read_machine_id(path) }.first.to_s
    end

    def self.read_machine_id(path)
      File.read(path).strip.then { |id| id.match?(/\A[0-9a-f]{32}\z/) ? id : nil }
    rescue SystemCallError
      nil
    end

    def self.clock_format
      CLOCK_FORMATS.fetch(desktop_setting(CLOCK_FORMAT_KEY), DEFAULT_CLOCK_FORMAT)
    end

    # Gio::Settings aborts the process when its schema is not installed rather
    # than raising, so the schema source is consulted first, exactly as
    # GnomeLogs::Settings does.
    def self.desktop_setting(key)
      desktop_schema_installed? ? Gio::Settings.new(DESKTOP_SCHEMA)[key] : nil
    end

    def self.desktop_schema_installed?
      Gio::SettingsSchemaSource.default&.lookup(DESKTOP_SCHEMA, true) ? true : false
    rescue StandardError
      false
    end

    # Ports compare_timestamps: how much of the date still needs showing once
    # the parts both timestamps share are dropped.
    def self.compare_timestamps(a, b)
      if a.year != b.year
        :different_year
      elsif a.month == b.month && a.day == b.day
        :same_day
      else
        :same_year
      end
    end

    def self.pattern_for(similarity, format, show_second)
      FORMATS.fetch(format).fetch(similarity).fetch(show_second ? :seconds : :no_seconds)
    end

    def self.expand_padding(time, pattern)
      pattern.gsub('%e', pad(time.day)).gsub('%l', pad(hour_of_twelve(time)))
    end

    def self.pad(number) = number < 10 ? "#{FIGURE_SPACE}#{number}" : number.to_s

    def self.hour_of_twelve(time) = (time.hour % 12).zero? ? 12 : time.hour % 12
  end
end
