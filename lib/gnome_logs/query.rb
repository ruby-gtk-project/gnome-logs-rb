# frozen_string_literal: true

module GnomeLogs
  # Describes what to read from the journal. Ports GlQuery: category matches,
  # a search term restricted to a journal field, a search type (exact or
  # substring) and a timestamp range or boot.
  class Query
    # The C version pages the journal cursor in idle callbacks and grows the
    # list as the user scrolls; this port reads one batch, so it caps how many
    # rows a single query may build.
    DAY_SECONDS = 86_400
    TIME_FORMAT = '%Y-%m-%d %H:%M:%S'
    ENTRY_LIMIT = 1_000

    # Ports query_add_search_matches. The all-fields entry searches every field
    # the C version searched, always as a substring.
    SEARCH_FIELDS = {
      all: %w[_PID _UID _GID MESSAGE _COMM _SYSTEMD_UNIT _KERNEL_DEVICE _AUDIT_SESSION _EXE],
      pid: %w[_PID],
      uid: %w[_UID],
      gid: %w[_GID],
      message: %w[MESSAGE],
      process_name: %w[_COMM],
      systemd_unit: %w[_SYSTEMD_UNIT],
      kernel_device: %w[_KERNEL_DEVICE],
      audit_session: %w[_AUDIT_SESSION],
      executable_path: %w[_EXE]
    }.freeze

    SEARCH_FIELD_TITLES = {
      all: 'All Available Fields', pid: 'PID', uid: 'UID', gid: 'GID',
      message: 'Message', process_name: 'Process Name', systemd_unit: 'Systemd Unit',
      kernel_device: 'Kernel Device', audit_session: 'Audit Session',
      executable_path: 'Executable Path'
    }.freeze

    SEARCH_TYPE_TITLES = { substring: 'Containing', exact: 'Matching' }.freeze

    RANGE_TITLES = {
      current_boot: 'Current Boot', previous_boot: 'Previous Boot',
      today: 'Today', last_three_days: 'Last 3 days', entire_journal: 'Entire Journal',
      custom_range: 'Set Custom Range…'
    }.freeze

    attr_accessor :category, :search_text, :search_field, :search_type, :range,
                  :boot_id, :start_time, :end_time, :descending

    def initialize(descending: true)
      @descending = descending
      @category = Category.default
      @search_text = ''
      @search_field = :all
      @search_type = :substring
      @range = :current_boot
      @boot_id = ''
      @start_time = nil
      @end_time = nil
    end

    # --lines always takes the newest N entries; --reverse only decides which
    # end they come out of. So the ascending-time sort order shows the same
    # recent window as descending, oldest first, rather than the start of the
    # journal.
    def journalctl_args
      ['--output=json', '--no-pager', "--lines=#{ENTRY_LIMIT}"] +
        (descending ? ['--reverse'] : []) + range_args + category.matches
    end

    # The substring half of a search cannot be expressed as a journalctl match,
    # so every search term is applied here instead and the same code path
    # serves both search types.
    def matches?(entry)
      category.matches?(entry) && search_matches?(entry)
    end

    def search_matches?(entry)
      search_text.empty? || SEARCH_FIELDS.fetch(search_field).any? do |field|
        field_value(entry, field).then do |value|
          # The all-fields search is always a substring search upstream.
          if search_type == :exact && search_field != :all
            value.casecmp?(search_text)
          else
            value.downcase.include?(search_text.downcase)
          end
        end
      end
    end

    def field_value(entry, field) = entry.public_send(JournalEntry::FIELDS.key(field))

    def range_args
      case range
      when :current_boot then ['--boot=0']
      when :previous_boot then ['--boot=-1']
      when :today then ['--since=today']
      when :last_three_days then ["--since=#{(Time.now - (3 * DAY_SECONDS)).strftime(TIME_FORMAT)}"]
      when :custom_range then custom_range_args
      else [] # :entire_journal, which reads the whole journal
      end
    end

    def custom_range_args
      [start_time && "--since=#{start_time.strftime(TIME_FORMAT)}",
       end_time && "--until=#{end_time.strftime(TIME_FORMAT)}"].compact
    end
  end
end
