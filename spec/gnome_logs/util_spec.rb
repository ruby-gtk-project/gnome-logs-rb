# frozen_string_literal: true

# Ported from tests/test-gl-util.c.

require 'gnome_logs/util'

# The C test's expectations are spelled with U+2007 FIGURE SPACE, which is
# what GLib (and so this port) pads %e and %l with.
figure_space = GnomeLogs::Util::FIGURE_SPACE

RSpec.describe GnomeLogs::Util do
  # The C test builds `now` as a UTC date and compares it against the local
  # rendering of each timestamp, so it only agrees with itself where local
  # time is UTC. The port says so out loud instead of relying on the
  # environment.
  around do |example|
    original = ENV.fetch('TZ', nil)
    ENV['TZ'] = 'UTC'
    example.run
  ensure
    ENV['TZ'] = original
  end

  # 2015-02-09 13:30:42, the moment the C test compares every timestamp
  # against. Seconds since the epoch rather than Time.utc, so that the local
  # zone the around hook fixes is the only zone in play.
  let(:now) { Time.at(1_423_488_642) }

  describe '.timestamp_to_display' do
    # Three cases for each clock format: same day, same year, different year.
    {
      "#{figure_space}1:00 PM" => [1_423_486_800_000_000, :twelve_hour],
      "Feb #{figure_space}8 #{figure_space}1:30 PM" => [1_423_402_200_000_000, :twelve_hour],
      "Feb #{figure_space}9 2014 #{figure_space}1:30 PM" => [1_391_952_600_000_000, :twelve_hour],
      '13:00' => [1_423_486_800_000_000, :twenty_four_hour],
      "Feb #{figure_space}8 13:30" => [1_423_402_200_000_000, :twenty_four_hour],
      "Feb #{figure_space}9 2014 13:30" => [1_391_952_600_000_000, :twenty_four_hour]
    }.each do |expected, (microsecs, clock_format)|
      it "renders #{microsecs} as #{expected.inspect} in #{clock_format} format" do
        expect(described_class.timestamp_to_display(microsecs, now, clock_format)).to eq(expected)
      end
    end

    it 'shows seconds when asked for them' do
      displayed = described_class.timestamp_to_display(
        1_423_486_800_000_000,
        now,
        :twenty_four_hour,
        show_second: true
      )

      expect(displayed).to eq('13:00:00')
    end

    it 'discards the part of a timestamp finer than a second, as the C version does' do
      expect(described_class.timestamp_to_display(1_423_486_800_999_999, now, :twenty_four_hour)).to eq('13:00')
    end

    it 'falls back to the desktop clock format when none is given' do
      allow(described_class).to receive(:clock_format).and_return(:twelve_hour)

      expect(described_class.timestamp_to_display(1_423_486_800_000_000, now)).to eq("#{figure_space}1:00 PM")
    end
  end

  describe '.boot_time_to_display' do
    it 'joins the first and last timestamps of the boot with an en dash' do
      allow(described_class).to receive(:clock_format).and_return(:twenty_four_hour)

      expect(described_class.boot_time_to_display(1_391_952_600_000_000, 1_423_402_200_000_000))
        .to eq("Feb #{figure_space}9 2014 13:30 – Feb #{figure_space}8 2015 13:30")
    end
  end

  describe '.compare_timestamps' do
    # 2015-02-09 01:00, 2015-02-08 13:30 and 2014-02-09 13:30.
    it 'reports two times on the same day as the same day' do
      expect(described_class.compare_timestamps(Time.at(1_423_443_600), now)).to eq(:same_day)
    end

    it 'reports a different day of the same year as the same year' do
      expect(described_class.compare_timestamps(Time.at(1_423_402_200), now)).to eq(:same_year)
    end

    it 'reports the same month and day of another year as a different year' do
      expect(described_class.compare_timestamps(Time.at(1_391_952_600), now)).to eq(:different_year)
    end
  end

  describe '.clock_format' do
    it 'maps the clock-format setting onto the GlUtilClockFormat members' do
      allow(described_class).to receive(:desktop_setting).with('clock-format').and_return('12h')

      expect(described_class.clock_format).to eq(:twelve_hour)
    end

    it 'falls back to 24 hour format when the desktop schema is not installed' do
      allow(described_class).to receive(:desktop_setting).and_return(nil)

      expect(described_class.clock_format).to eq(:twenty_four_hour)
    end
  end

  describe '.uid' do
    it 'reports the uid of this process, as g_credentials_get_unix_user does' do
      expect(described_class.uid).to eq(Process.uid)
    end
  end

  describe '.machine_id' do
    it 'is the 32 hex digits systemd writes, or empty when there is no id to read' do
      expect(described_class.machine_id).to match(/\A([0-9a-f]{32})?\z/)
    end

    it 'rejects a file whose contents are not a machine id' do
      expect(described_class.read_machine_id(File::NULL)).to be_nil
    end

    it 'reports no id when the file does not exist' do
      expect(described_class.read_machine_id('/nonexistent/machine-id')).to be_nil
    end
  end

  describe '.journal_storage_type' do
    it 'is one of the GlJournalStorage members' do
      expect(described_class.journal_storage_type).to be_in(%i[none persistent volatile])
    end

    it 'reports no storage when the machine id cannot be read' do
      allow(described_class).to receive(:machine_id).and_return('')

      expect(described_class.journal_storage_type).to eq(:none)
    end
  end

  describe '.system_journal_path' do
    it 'points at the persistent journal directory for persistent storage' do
      allow(described_class).to receive(:machine_id).and_return('0' * 32)

      expect(described_class.system_journal_path(:persistent))
        .to eq("/var/log/journal/#{'0' * 32}/system.journal")
    end

    it 'points at the volatile journal directory for volatile storage' do
      allow(described_class).to receive(:machine_id).and_return('0' * 32)

      expect(described_class.system_journal_path(:volatile))
        .to eq("/run/log/journal/#{'0' * 32}/system.journal")
    end

    it 'probes the null device when there is no journal, as the C version does' do
      expect(described_class.system_journal_path(:none)).to eq(File::NULL)
    end
  end

  describe '.can_read_user_journal?' do
    it 'looks for the per-user journal of this process in the persistent directory' do
      allow(described_class).to receive(:machine_id).and_return('0' * 32)
      allow(File).to receive(:readable?).and_return(true)

      described_class.can_read_user_journal?

      expect(File).to have_received(:readable?)
        .with("/var/log/journal/#{'0' * 32}/user-#{Process.uid}.journal")
    end
  end
end
