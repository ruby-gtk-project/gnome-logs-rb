# frozen_string_literal: true

require 'gnome_logs/catalog'

RSpec.describe GnomeLogs::Catalog do
  subject(:catalog) { described_class.new }

  let(:dump) do
    <<~CATALOG
      -- 240000864d2f41f9118100fd5177945c
      Subject: The system has booted up
      Defined-By: systemd
      Support: https://example.com/support
      Documentation: man:systemd-bootup(7)

      The system has finished booting up.

      -- 06d6d0046d2340bfb3c7e9e6a5d2e2e3
      Subject: No headers at all, just a body

      Just the body text here.
    CATALOG
  end

  before { allow(catalog).to receive(:dump).and_return(dump) }

  describe '#entry_for' do
    it 'finds an entry by its message id, case-insensitively' do
      entry = catalog.entry_for('240000864D2F41F9118100FD5177945C')

      expect(entry.subject).to eq('The system has booted up')
      expect(entry.defined_by).to eq('systemd')
      expect(entry.support).to eq('https://example.com/support')
      expect(entry.documentation).to eq('man:systemd-bootup(7)')
      expect(entry.body).to eq('The system has finished booting up.')
    end

    it 'leaves unrecognized headers as empty strings' do
      entry = catalog.entry_for('06d6d0046d2340bfb3c7e9e6a5d2e2e3')

      expect(entry.subject).to eq('No headers at all, just a body')
      expect(entry.defined_by).to eq('')
      expect(entry.body).to eq('Just the body text here.')
    end

    it 'returns the empty entry for an unknown message id' do
      entry = catalog.entry_for('does-not-exist')

      expect(entry).to eq(described_class::EMPTY)
    end
  end

  describe '#entries' do
    it 'memoizes the parsed dump' do
      catalog.entries

      expect(catalog).to have_received(:dump).once
    end
  end
end
