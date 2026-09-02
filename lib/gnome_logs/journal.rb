# frozen_string_literal: true

require 'json'
require 'open3'

module GnomeLogs
  # Reads the systemd journal. The C version links against libsystemd and walks
  # the journal cursor by cursor; Ruby has no such binding, so this shells out
  # to journalctl's JSON output, which exposes the same fields and the same
  # match semantics.
  class Journal
    FORMAT = '%Y-%m-%d %H:%M'

    Boot = Struct.new(:index, :boot_id, :first_time, :last_time) do
      def display_name
        format('%<from>s - %<to>s', from: first_time.strftime(FORMAT), to: last_time.strftime(FORMAT))
      end
    end

    def entries(query)
      read(query.journalctl_args).lazy.map { |json| JournalEntry.from_json(json) }
    end

    def boots
      read(['--list-boots', '--output=json']).map do |json|
        Boot.new(json['index'], json['boot_id'],
                 Time.at(json['first_entry'].to_i / 1_000_000.0),
                 Time.at(json['last_entry'].to_i / 1_000_000.0))
      end
    end

    # journalctl exits non-zero when the range selects nothing (for instance
    # --boot=-1 on a machine with a single boot), which is not an error here.
    def read(args)
      Open3.capture3('journalctl', *args).then do |stdout, stderr, status|
        @last_error = status.success? ? nil : stderr.strip
        # Entry output is one JSON object per line; --list-boots emits a
        # single JSON array instead, so both shapes flatten to a list.
        stdout.each_line.filter_map { |line| parse(line) }.flatten
      end
    end

    def parse(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    def available? = system('journalctl', '--version', out: File::NULL, err: File::NULL)

    attr_reader :last_error
  end
end
