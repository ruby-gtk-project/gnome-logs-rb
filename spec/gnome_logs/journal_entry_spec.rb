# frozen_string_literal: true

require 'gnome_logs/journal_entry'

RSpec.describe GnomeLogs::JournalEntry do
  describe '.from_json' do
    it 'maps the journalctl JSON field names onto plain attributes' do
      entry = described_class.from_json(
        '__CURSOR' => 'abc', '__REALTIME_TIMESTAMP' => '1423486800000000',
        'MESSAGE' => 'hello', 'PRIORITY' => '6', '_COMM' => 'sshd'
      )

      expect(entry.cursor).to eq('abc')
      expect(entry.timestamp).to eq('1423486800000000')
      expect(entry.message).to eq('hello')
      expect(entry.priority).to eq('6')
      expect(entry.comm).to eq('sshd')
    end

    it 'defaults every other field to an empty string' do
      entry = described_class.from_json('MESSAGE' => 'hi')

      expect(entry.kernel_device).to eq('')
      expect(entry.audit_session).to eq('')
      expect(entry.command_line).to eq('')
    end
  end

  describe '.stringify' do
    it 'passes a plain string through unchanged' do
      expect(described_class.stringify('hi')).to eq('hi')
    end

    it 'turns a nil field into an empty string' do
      expect(described_class.stringify(nil)).to eq('')
    end

    it 'joins a repeated field (array of strings) with a space' do
      expect(described_class.stringify(%w[one two])).to eq('one two')
    end

    it 'packs an array of byte values (non-UTF-8 field) into a scrubbed string' do
      expect(described_class.stringify([104, 105])).to eq('hi')
    end

    it 'calls to_s on anything else' do
      expect(described_class.stringify(42)).to eq('42')
    end
  end

  describe '#timestamp_usec' do
    it 'parses the realtime timestamp as an integer' do
      entry = described_class.from_json('__REALTIME_TIMESTAMP' => '1423486800000000')

      expect(entry.timestamp_usec).to eq(1_423_486_800_000_000)
    end
  end

  describe '#priority_name' do
    it 'maps a known priority number onto its name' do
      entry = described_class.from_json('PRIORITY' => '3')

      expect(entry.priority_name).to eq('Error')
    end

    it 'falls back to the raw value for an unknown priority' do
      entry = described_class.from_json('PRIORITY' => '9')

      expect(entry.priority_name).to eq('9')
    end
  end

  describe '#sender' do
    it 'prefers the process name when present' do
      entry = described_class.from_json('_COMM' => 'sshd', '_EXE' => '/usr/sbin/sshd')

      expect(entry.sender).to eq('sshd')
    end

    it 'falls back to the executable path when there is no process name' do
      entry = described_class.from_json('_EXE' => '/usr/sbin/sshd')

      expect(entry.sender).to eq('/usr/sbin/sshd')
    end
  end

  describe '#single_line_message' do
    it 'replaces newlines with the symbol-for-newline character' do
      entry = described_class.from_json('MESSAGE' => "one\ntwo")

      expect(entry.single_line_message).to eq("one␤two")
    end
  end

  describe '#to_export_line' do
    it 'formats the time, sender and single-line message as one line' do
      entry = described_class.from_json(
        '__REALTIME_TIMESTAMP' => '1423486800000000', '_COMM' => 'sshd', 'MESSAGE' => "one\ntwo"
      )

      expect(entry.to_export_line).to eq(
        "#{entry.time.strftime('%b %d %H:%M:%S')} sshd: one␤two"
      )
    end
  end

  describe 'row_type and compressed_entries' do
    it 'starts every entry as a normal, uncompressed row' do
      entry = described_class.from_json({})

      expect(entry.row_type).to eq(:normal)
      expect(entry.compressed_entries).to eq(0)
    end
  end

  describe '#display_time_label' do
    it 'starts true, as every entry is its own display before grouping' do
      expect(described_class.from_json({}).display_time_label).to be(true)
    end
  end
end
