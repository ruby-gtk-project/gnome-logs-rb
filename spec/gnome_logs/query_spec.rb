# frozen_string_literal: true

require 'gnome_logs/translation'
require 'gnome_logs/journal_entry'
require 'gnome_logs/category'
require 'gnome_logs/query'

RSpec.describe GnomeLogs::Query do
  subject(:query) { described_class.new }

  describe '#initialize' do
    it 'defaults to the All category, descending order and the current boot' do
      expect(query.category).to eq(GnomeLogs::Category.default)
      expect(query.descending).to be(true)
      expect(query.range).to eq(:current_boot)
      expect(query.search_field).to eq(:all)
      expect(query.search_type).to eq(:substring)
    end

    it 'accepts an explicit sort order' do
      expect(described_class.new(descending: false).descending).to be(false)
    end
  end

  describe '#journalctl_args' do
    it 'always asks for JSON, no pager, and the entry limit' do
      expect(query.journalctl_args).to include('--output=json', '--no-pager', '--lines=1000')
    end

    it 'reverses the output when sorting descending' do
      expect(query.journalctl_args).to include('--reverse')
    end

    it 'does not reverse the output when sorting ascending' do
      query.descending = false

      expect(query.journalctl_args).not_to include('--reverse')
    end

    it 'includes the current category matches' do
      query.category = GnomeLogs::Category.system

      expect(query.journalctl_args).to include('_TRANSPORT=kernel')
    end
  end

  describe '#range_args' do
    it 'asks for the current boot with --boot=0' do
      expect(query.range_args).to eq(['--boot=0'])
    end

    it 'asks for the previous boot with --boot=-1' do
      query.range = :previous_boot

      expect(query.range_args).to eq(['--boot=-1'])
    end

    it 'asks for today with --since=today' do
      query.range = :today

      expect(query.range_args).to eq(['--since=today'])
    end

    it 'reads the entire journal with no range argument at all' do
      query.range = :entire_journal

      expect(query.range_args).to eq([])
    end

    it 'builds a --since/--until pair for a custom range' do
      query.range = :custom_range
      query.start_time = Time.new(2016, 1, 22, 0, 0, 0)
      query.end_time = Time.new(2016, 1, 23, 0, 0, 0)

      expect(query.range_args).to eq(['--since=2016-01-22 00:00:00', '--until=2016-01-23 00:00:00'])
    end

    it 'omits a custom-range bound that has not been set yet' do
      query.range = :custom_range

      expect(query.range_args).to eq([])
    end
  end

  describe '#matches?' do
    let(:entry) { GnomeLogs::JournalEntry.from_json('MESSAGE' => 'hello world', '_COMM' => 'sshd') }

    it 'matches anything when the category and search are both unrestricted' do
      expect(query.matches?(entry)).to be(true)
    end

    it 'defers to the category predicate' do
      query.category = GnomeLogs::Category.security

      expect(query.matches?(entry)).to be(false)
    end

    it 'requires a search match across every field when searching all fields' do
      query.search_text = 'sshd'

      expect(query.matches?(entry)).to be(true)
    end

    it 'does not match when the search text is in none of the searched fields' do
      query.search_text = 'nonexistent'

      expect(query.matches?(entry)).to be(false)
    end
  end

  describe '#search_matches?' do
    let(:entry) { GnomeLogs::JournalEntry.from_json('MESSAGE' => 'Hello World') }

    it 'is case-insensitive for a substring search' do
      query.search_text = 'hello'

      expect(query.search_matches?(entry)).to be(true)
    end

    it 'restricts the search to one field when asked' do
      query.search_field = :message
      query.search_text = 'hello'

      expect(query.search_matches?(entry)).to be(true)
    end

    it 'does not find a substring match in a field it was not asked to search' do
      query.search_field = :process_name
      query.search_text = 'hello'

      expect(query.search_matches?(entry)).to be(false)
    end

    it 'requires an exact, case-insensitive match for a single-field exact search' do
      query.search_field = :message
      query.search_type = :exact
      query.search_text = 'hello world'

      expect(query.search_matches?(entry)).to be(true)
    end

    it 'rejects a substring under an exact single-field search' do
      query.search_field = :message
      query.search_type = :exact
      query.search_text = 'hello'

      expect(query.search_matches?(entry)).to be(false)
    end

    it 'treats an all-fields search as a substring search even when exact is selected' do
      query.search_field = :all
      query.search_type = :exact
      query.search_text = 'hello'

      expect(query.search_matches?(entry)).to be(true)
    end

    it 'matches everything when the search text is empty' do
      query.search_text = ''

      expect(query.search_matches?(entry)).to be(true)
    end
  end
end
