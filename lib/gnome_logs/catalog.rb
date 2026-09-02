# frozen_string_literal: true

module GnomeLogs
  # The systemd message catalog, keyed by MESSAGE_ID. The C version pulls each
  # entry through sd_journal_get_catalog and picks it apart with strtok; here
  # the whole catalog is dumped once and split into headers plus body, which
  # gives the same four fields the detail view shows.
  class Catalog
    HEADERS = { 'Subject' => :subject, 'Defined-By' => :defined_by,
                'Support' => :support, 'Documentation' => :documentation }.freeze

    Entry = Struct.new(:subject, :defined_by, :support, :documentation, :body, keyword_init: true)

    EMPTY = Entry.new(subject: '', defined_by: '', support: '', documentation: '', body: '')

    def entry_for(message_id) = entries.fetch(message_id.to_s.downcase, EMPTY)

    def entries
      @entries ||= dump.split(/^-- /).drop(1).to_h do |block|
        block.split("\n", 2).then { |id, text| [id.strip.downcase, parse(text.to_s)] }
      end
    end

    def parse(text)
      text.split("\n\n", 2).then do |headers, body|
        Entry.new(body: body.to_s.strip, **collect(headers)).tap do |entry|
          HEADERS.each_value { |name| entry[name] = entry[name].to_s }
        end
      end
    end

    def collect(headers)
      headers.to_s.lines.filter_map do |line|
        line.split(': ', 2).then do |name, value|
          [HEADERS[name.strip], value.to_s.strip] if HEADERS.key?(name.to_s.strip)
        end
      end.to_h
    end

    def dump = @dump ||= `journalctl --dump-catalog 2>/dev/null`
  end
end
