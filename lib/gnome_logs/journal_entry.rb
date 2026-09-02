# frozen_string_literal: true

module GnomeLogs
  # A single journal entry. Mirrors GlJournalEntry from the C implementation,
  # but every field is a plain string and the class is a plain Ruby object:
  # the list is a Gtk::ListBox rather than a Gio::ListStore, so there is
  # nothing to gain from making it a GObject. Timestamps are microseconds
  # since the epoch, exactly as journalctl reports __REALTIME_TIMESTAMP.
  class JournalEntry
    FIELDS = {
      cursor: '__CURSOR',
      timestamp: '__REALTIME_TIMESTAMP',
      message: 'MESSAGE',
      priority: 'PRIORITY',
      comm: '_COMM',
      kernel_device: '_KERNEL_DEVICE',
      audit_session: '_AUDIT_SESSION',
      transport: '_TRANSPORT',
      catalog: 'MESSAGE_ID',
      uid: '_UID',
      pid: '_PID',
      gid: '_GID',
      systemd_unit: '_SYSTEMD_UNIT',
      executable_path: '_EXE',
      command_line: '_CMDLINE',
      boot_id: '_BOOT_ID'
    }.freeze

    # U+2424 SYMBOL FOR NEWLINE, as gl_event_view_row_replace_newline uses.
    NEWLINE_SYMBOL = "\u2424"

    PRIORITIES = {
      '0' => 'Emergency',
      '1' => 'Alert',
      '2' => 'Critical',
      '3' => 'Error',
      '4' => 'Warning',
      '5' => 'Notice',
      '6' => 'Info',
      '7' => 'Debug'
    }.freeze

    attr_accessor(*FIELDS.keys)
    attr_accessor :display_time_label

    def self.from_json(hash)
      new(**FIELDS.transform_values { |field| stringify(hash[field]) })
    end

    # journalctl emits a field as an array when the entry carries it more than
    # once, and as an array of byte values when it is not valid UTF-8.
    def self.stringify(value)
      case value
      when nil then ''
      when String then value
      when Array
        value.all?(Integer) ? value.pack('C*').force_encoding('UTF-8').scrub : value.join(' ')
      else value.to_s
      end
    end

    def initialize(**attrs)
      FIELDS.each_key { |name| instance_variable_set("@#{name}", attrs[name].to_s) }
      @display_time_label = true
    end

    def timestamp_usec = timestamp.to_i

    def time = Time.at(timestamp_usec / 1_000_000.0)

    def priority_name = PRIORITIES.fetch(priority, priority)

    def sender = comm.empty? ? executable_path : comm

    # Newlines are replaced with U+2424 so a multi-line message still renders
    # as a single row, matching gl_event_view_row_replace_newline.
    def single_line_message = message.tr("\n", NEWLINE_SYMBOL)

    def to_export_line
      format('%<time>s %<sender>s: %<message>s', time: time.strftime('%b %d %H:%M:%S'),
                                                 sender: sender, message: message)
    end
  end
end
