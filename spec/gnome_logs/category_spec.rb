# frozen_string_literal: true

require 'gnome_logs/translation'
require 'gnome_logs/journal_entry'
require 'gnome_logs/category'

RSpec.describe GnomeLogs::Category do
  let(:entry) { GnomeLogs::JournalEntry.from_json(attrs) }
  let(:attrs) { {} }

  describe '.all' do
    it 'matches every entry, having no matches and the default predicate' do
      expect(described_class.all.matches).to eq([])
      expect(described_class.all.matches?(entry)).to be(true)
    end
  end

  describe '.important' do
    it 'restricts to journalctl priority matches 0 through 3' do
      expect(described_class.important.matches).to eq(%w[PRIORITY=0 PRIORITY=1 PRIORITY=2 PRIORITY=3])
    end
  end

  describe '.applications' do
    let(:attrs) { { '_TRANSPORT' => 'journal', '_UID' => described_class.uid } }

    it 'matches the journal/stdout/syslog transports restricted to this uid' do
      expect(described_class.applications.matches).to include('_TRANSPORT=journal', "_UID=#{described_class.uid}")
    end
  end

  describe '.system' do
    it 'matches the kernel transport' do
      expect(described_class.system.matches).to eq(['_TRANSPORT=kernel'])
    end
  end

  describe '.security' do
    it 'has no journalctl matches, only a predicate requiring an audit session' do
      expect(described_class.security.matches).to eq([])
    end

    it 'matches an entry with a non-empty audit session' do
      entry = GnomeLogs::JournalEntry.from_json('_AUDIT_SESSION' => '5')

      expect(described_class.security.matches?(entry)).to be(true)
    end

    it 'does not match an entry with no audit session' do
      expect(described_class.security.matches?(entry)).to be(false)
    end
  end

  describe '.hardware' do
    it 'matches the kernel transport further refined by a kernel device' do
      expect(described_class.hardware.matches).to eq(['_TRANSPORT=kernel'])
    end

    it 'matches a kernel entry carrying a kernel device' do
      entry = GnomeLogs::JournalEntry.from_json('_KERNEL_DEVICE' => '+sound:card0')

      expect(described_class.hardware.matches?(entry)).to be(true)
    end

    it 'does not match a kernel entry with no kernel device' do
      expect(described_class.hardware.matches?(entry)).to be(false)
    end
  end

  describe '.visible' do
    it 'lists only the six categories the C version actually implements' do
      expect(described_class.visible.map(&:id)).to eq(%i[important all applications system security hardware])
    end
  end

  describe '.default' do
    it 'is the All category' do
      expect(described_class.default).to eq(described_class.all)
    end
  end

  describe '.label_for' do
    it 'labels an application entry (journal/stdout/syslog transport, this uid)' do
      entry = GnomeLogs::JournalEntry.from_json('_TRANSPORT' => 'stdout', '_UID' => described_class.uid)

      expect(described_class.label_for(entry)).to eq('Applications')
    end

    it 'labels a kernel entry with a kernel device as hardware' do
      entry = GnomeLogs::JournalEntry.from_json('_TRANSPORT' => 'kernel', '_KERNEL_DEVICE' => '+sound:card0')

      expect(described_class.label_for(entry)).to eq('Hardware')
    end

    it 'labels a kernel entry with no kernel device as system' do
      entry = GnomeLogs::JournalEntry.from_json('_TRANSPORT' => 'kernel')

      expect(described_class.label_for(entry)).to eq('System')
    end

    it 'labels an entry with an audit session as security' do
      entry = GnomeLogs::JournalEntry.from_json('_AUDIT_SESSION' => '5')

      expect(described_class.label_for(entry)).to eq('Security')
    end

    it 'labels anything else as other' do
      entry = GnomeLogs::JournalEntry.from_json('_TRANSPORT' => 'driver')

      expect(described_class.label_for(entry)).to eq('Other')
    end
  end
end
