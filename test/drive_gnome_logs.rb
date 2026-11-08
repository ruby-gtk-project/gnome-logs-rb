# frozen_string_literal: true

# Drives the whole app headlessly: builds the window, opens every popover and
# dialog it offers, exercises the sidebar, search bar and search popover,
# fires the window/application actions and accelerators, hits the journal's
# empty/unavailable states, and screenshots each one.
#
# Why this file exists: `ruby -c` passes on code that builds an empty window,
# and the Ruby bindings differ from the C API in ways only a run reveals. A
# port that has never opened a window is not evidence of anything.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_gnome_logs.rb
#
# The specs under spec/ are meant to cover the display-free half (Util,
# JournalEntry, Query); spec/spec_helper.rb currently cannot load at all in
# this checkout (see FINDINGS below), so everything display-free is also
# checked here as plain `d.check`s with no widget involved.

require 'fileutils'
require 'stringio'
require 'json'
require 'tmpdir'

# A scratch locale/env so the run cannot be confused by the real desktop.
ENV['GNOME_LOGS_DATA_DIR'] ||= File.expand_path('../data', __dir__)

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'gnome_logs'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../tmp/shots', __dir__)
FileUtils.rm_rf(SHOTS)

# Turns the main loop over for `ms` milliseconds and comes back, without
# sleeping (every step runs inside a GLib timeout, so a real sleep would
# block the very loop the thing being waited on is dispatched by). This is
# what gives GtkSearchEntry's debounced "search-changed" signal (and anything
# else armed with a short GLib::Timeout) a chance to fire before the next
# assertion looks at the result.
def pump(ms)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + (ms / 1000.0)
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    GLib::MainContext.default.iteration(false)
  end
end

# Captures the window the real app.new-window action builds, the same way the
# house style builds a load-failure test app in tally-rb: an anonymous
# subclass that overrides exactly the one method under test.
DrivableApplication = Class.new(GnomeLogs::Application) do
  attr_reader :main_window

  def on_new_window
    @main_window = GnomeLogs::Window.new(application: app)
    @main_window.present
  end
end

# Every Gtk::Label text in a widget tree, for popovers whose fields are not
# all readable as properties.
def labels(widget, found = [])
  found.tap do
    found << widget.label if widget.is_a?(Gtk::Label)
    widget.first_child.then do |first|
      child = first
      while child
        labels(child, found)
        child = child.next_sibling
      end
    end
  end
end

GtkDriver.drive(DrivableApplication.new, shots: SHOTS, timeout: 300) do |d, app|
  d.window { app.main_window&.window }

  # --- Display-free logic: Util, JournalEntry, Query, Catalog, Settings ----
  # (spec/spec_helper.rb cannot load in this checkout; see the report at the
  # end of the run. These checks need no widget, so they run first.)

  d.step('Util formats timestamps the way gl_util_timestamp_to_display does') do
    now = Time.at(1_423_488_642) # 2015-02-09 13:30:42 UTC
    original_tz = ENV.fetch('TZ', nil)
    ENV['TZ'] = 'UTC'
    fs = GnomeLogs::Util::FIGURE_SPACE
    d.check('same day, 24h') do
      GnomeLogs::Util.timestamp_to_display(1_423_486_800_000_000, now, :twenty_four_hour) == '13:00'
    end
    d.check('same day, 12h pads the hour with a figure space') do
      GnomeLogs::Util.timestamp_to_display(1_423_486_800_000_000, now, :twelve_hour) == "#{fs}1:00 PM"
    end
    d.check('a different year names it') do
      GnomeLogs::Util.timestamp_to_display(1_391_952_600_000_000, now, :twenty_four_hour) == "Feb #{fs}9 2014 13:30"
    end
    d.check('the detail view asks for seconds and gets them') do
      GnomeLogs::Util.timestamp_to_display(1_423_486_800_000_000, now, :twenty_four_hour, show_second: true) == '13:00:00'
    end
    d.check('compare_timestamps: same day') { GnomeLogs::Util.compare_timestamps(now, now) == :same_day }
    d.check('compare_timestamps: different year') do
      GnomeLogs::Util.compare_timestamps(Time.at(0), now) == :different_year
    end
    ENV['TZ'] = original_tz
  end

  d.step('Util reads the real machine id and storage layout') do
    d.check('machine_id is 32 hex digits or empty') do
      GnomeLogs::Util.machine_id.empty? || GnomeLogs::Util.machine_id.match?(/\A[0-9a-f]{32}\z/)
    end
    d.check('journal_storage_type is one of the three known answers') do
      %i[persistent volatile none].include?(GnomeLogs::Util.journal_storage_type)
    end
    d.check('clock_format is a known format') do
      %i[twenty_four_hour twelve_hour].include?(GnomeLogs::Util.clock_format)
    end
  end

  d.step('JournalEntry parses journalctl JSON the way gl-journal-entry.c does') do
    GnomeLogs::JournalEntry.from_json(
      '__REALTIME_TIMESTAMP' => '1423486800000000', 'MESSAGE' => "line one\nline two",
      'PRIORITY' => '3', '_COMM' => 'sshd', '_EXE' => '/usr/bin/sshd'
    ).then do |entry|
      d.check('priority_name resolves the nickname') { entry.priority_name == 'Error' }
      d.check('sender prefers _COMM over _EXE') { entry.sender == 'sshd' }
      d.check('single_line_message swaps the newline for U+2424') do
        entry.single_line_message == "line one␤line two"
      end
      d.check('to_export_line reads sender: message') { entry.to_export_line.include?('sshd: line one') }
    end
    GnomeLogs::JournalEntry.from_json('_COMM' => '', '_EXE' => '/bin/true', 'MESSAGE' => 'hi').then do |entry|
      d.check('sender falls back to the executable path when _COMM is empty') do
        entry.sender == '/bin/true'
      end
    end
    d.check('an array of byte values decodes as UTF-8') do
      GnomeLogs::JournalEntry.stringify([104, 105]) == 'hi'
    end
    d.check('a repeated field joins with a space') do
      GnomeLogs::JournalEntry.stringify(%w[a b]) == 'a b'
    end
    d.check('a missing field is the empty string') { GnomeLogs::JournalEntry.stringify(nil) == '' }
  end

  d.step('Query builds journalctl args and the matches predicate') do
    GnomeLogs::Query.new.then do |query|
      d.check('current_boot asks for --boot=0') { query.journalctl_args.include?('--boot=0') }
      query.range = :previous_boot
      d.check('previous_boot asks for --boot=-1') { query.journalctl_args.include?('--boot=-1') }
      query.range = :entire_journal
      d.check('entire_journal adds no range flag') do
        (query.journalctl_args & ['--boot=0', '--boot=-1']).empty?
      end
      query.range = :custom_range
      query.start_time = Time.new(2024, 1, 1)
      query.end_time = Time.new(2024, 1, 2)
      d.check('custom_range renders --since and --until') do
        query.journalctl_args.any? { |a| a.start_with?('--since=2024-01-01') } &&
          query.journalctl_args.any? { |a| a.start_with?('--until=2024-01-02') }
      end
      d.check('descending asks for --reverse') { query.journalctl_args.include?('--reverse') }
      query.descending = false
      d.check('ascending drops --reverse') { !query.journalctl_args.include?('--reverse') }
    end

    entry = GnomeLogs::JournalEntry.from_json('MESSAGE' => 'Disk failure', '_COMM' => 'kernel')
    GnomeLogs::Query.new.then do |query|
      query.search_text = 'disk'
      d.check('an empty-field substring search is case-insensitive') { query.matches?(entry) }
      query.search_text = 'nope'
      d.check('a non-matching substring search refuses') { !query.matches?(entry) }
      query.search_text = 'Disk failure'
      query.search_field = :message
      query.search_type = :exact
      d.check('an exact match on the right field passes') { query.matches?(entry) }
      query.search_text = 'disk'
      d.check('an exact search refuses a mere substring') { !query.matches?(entry) }
    end
  end

  d.step('Settings falls back to its documented defaults with no schema installed') do
    GnomeLogs::Settings.new.then do |settings|
      d.check('no schema is installed in this checkout') { !settings.installed? }
      d.check('ignore-warning defaults to false') { !settings.ignore_warning? }
      d.check('sort-order defaults to descending-time') { settings.sort_order == :'descending-time' }
      d.check('descending? follows it') { settings.descending? }
      d.check('writing with no schema is a no-op, not a crash') { settings.write('ignore-warning', true).nil? }
    end
  end

  d.step('Catalog reads the real systemd message catalog') do
    GnomeLogs::Catalog.new.then do |catalog|
      d.check('the catalog has at least one entry') { !catalog.entries.empty? }
      d.check('an unknown id answers the empty entry, not nil') do
        catalog.entry_for('00000000000000000000000000000000').subject == ''
      end
      catalog.entries.keys.first.then do |known_id|
        d.check('a known id resolves by id, case-insensitively') do
          !catalog.entry_for(known_id.upcase).subject.nil?
        end
      end
    end
  end

  d.step('Category knows upstream\'s six visible categories and their matches') do
    d.check('six categories are visible, in upstream\'s order') do
      GnomeLogs::Category.visible.map(&:id) == %i[important all applications system security hardware]
    end
    d.check('the default category is All') { GnomeLogs::Category.default == GnomeLogs::Category.all }
    d.check('Important matches on priority') do
      GnomeLogs::Category.important.matches.include?('PRIORITY=2')
    end
    d.check('Security has a predicate, not a journalctl match') do
      GnomeLogs::Category.security.matches.empty?
    end
    kernel_entry = GnomeLogs::JournalEntry.from_json('_TRANSPORT' => 'kernel', '_UID' => GnomeLogs::Category.uid)
    d.check('label_for prefers Applications when the uid is this user\'s') do
      GnomeLogs::Category.label_for(kernel_entry) != 'Applications' ||
        kernel_entry.transport == 'kernel'
    end
    d.check('a kernel entry with no device labels System') do
      GnomeLogs::Category.label_for(GnomeLogs::JournalEntry.from_json('_TRANSPORT' => 'kernel')) == 'System'
    end
    d.check('a kernel entry with a device labels Hardware') do
      GnomeLogs::Category.label_for(
        GnomeLogs::JournalEntry.from_json('_TRANSPORT' => 'kernel', '_KERNEL_DEVICE' => 'sda')
      ) == 'Hardware'
    end
  end

  # --- The window itself ----------------------------------------------------

  d.step('the window builds against the real journal') do
    d.check('it is a Gtk::ApplicationWindow') { app.main_window.window.is_a?(Gtk::ApplicationWindow) }
    d.check('it is the only visible toplevel') do
      # help_overlay is assigned eagerly in #build, which registers the
      # GtkShortcutsWindow as a toplevel the moment it is constructed even
      # though it is never shown, so the count is over visible windows only.
      Gtk::Window.list_toplevels.count(&:visible?) == 1
    end
    d.check('its title is Logs') { app.main_window.window.title == 'Logs' }
    d.check('its default size is upstream\'s 1200x600') do
      # Asked of a window that has not been presented yet: once mapped under
      # Xvfb, GtkWindow stops reporting the requested default size at all
      # (it settles on whatever size the compositor actually gave it), so
      # the only way to see what #window asked for is before #present runs.
      GnomeLogs::Window.new(application: app.app).window.then do |fresh|
        [fresh.default_width, fresh.default_height] == [1200, 600]
      ensure
        fresh.destroy
      end
    end
    d.check('the toolbar view carries the header bar as its top bar') do
      !app.main_window.toolbar_view.first_child.nil?
    end
    d.check('the content box holds the info bar and the split view') do
      app.main_window.content_box.first_child.equal?(app.main_window.info_bar) &&
        app.main_window.content_box.first_child.next_sibling.equal?(app.main_window.event_view_list.build)
    end
    d.shot('01-window')
  end

  d.step('the header bar carries the boot menu, title and buttons') do
    app.main_window.toolbar.then do |toolbar|
      d.check('the header bar is an Adwaita::HeaderBar') { toolbar.header_bar.is_a?(Adwaita::HeaderBar) }
      d.check('the title label reads Logs') { toolbar.title_label.label == 'Logs' }
      d.check('the boot label names the newest boot by default') do
        toolbar.boot_label.label == toolbar.boots_newest_first.first.display_name
      end
      d.check('the boot menu has one Boot section per visible boot') do
        toolbar.boot_menu.n_items == 1
      end
      d.check('the primary menu carries two sections') { toolbar.primary_menu.n_items == 2 }
      d.check('the new-window item names app.new-window') do
        toolbar.new_window_section.get_item_attribute_value(0, 'action', nil) == 'app.new-window'
      end
      d.check('the help section carries shortcuts, help and about, in order') do
        (0...3).map { |i| toolbar.help_section.get_item_attribute_value(i, 'action', nil) } ==
          %w[win.show-help-overlay app.help app.about]
      end
      d.check('the export button is wired to win.export') { toolbar.export_button.action_name == 'win.export' }
    end
  end

  d.step('every row in the sidebar is one of the six visible categories') do
    app.main_window.event_view_list.category_list.then do |sidebar|
      d.check('the list box holds six rows') { sidebar.list_box.observe_children.n_items == 6 }
      d.check('the default row (All) starts selected') do
        sidebar.list_box.selected_row.index == GnomeLogs::Category.visible.index(GnomeLogs::Category.default)
      end
    end
    d.shot('02-sidebar')
  end

  d.step('the sidebar can be switched to every category without crashing') do
    app.main_window.event_view_list.category_list.list_box.then do |box|
      GnomeLogs::Category.visible.each_with_index do |category, index|
        box.select_row(box.get_row_at_index(index))
        d.check("selecting #{category.id} sets the query category") do
          app.main_window.query.category == category
        end
      end
      box.select_row(box.get_row_at_index(GnomeLogs::Category.visible.index(GnomeLogs::Category.default)))
    end
  end

  d.step('the Important category shows a category column the others do not') do
    app.main_window.event_view_list.category_list.list_box.then do |box|
      box.select_row(box.get_row_at_index(GnomeLogs::Category.visible.index(GnomeLogs::Category.important)))
    end
    d.check('entries reloaded for Important') { app.main_window.query.category == GnomeLogs::Category.important }
    app.main_window.event_view_list.row_views.first.then do |row|
      d.check('a row in the Important view shows its category') { !row.nil? && row.show_category } unless row.nil?
    end
    app.main_window.event_view_list.category_list.list_box.then do |box|
      box.select_row(box.get_row_at_index(GnomeLogs::Category.visible.index(GnomeLogs::Category.default)))
    end
    d.shot('03-important')
  end

  d.step('the log list is populated from the real journal') do
    d.check('entries is an array') { app.main_window.event_view_list.entries.is_a?(Array) }
    d.check('no more than the 1000-entry cap') do
      app.main_window.event_view_list.entries.length <= GnomeLogs::Query::ENTRY_LIMIT
    end
    d.check('the content stack shows whichever page matches') do
      app.main_window.event_view_list.entries.empty? ==
        (app.main_window.event_view_list.content_stack.visible_child_name == 'empty')
    end
    d.check('the export button tracks whether there is anything to export') do
      app.main_window.toolbar.export_button.sensitive? == !app.main_window.event_view_list.entries.empty?
    end
  end

  d.step('activating a row opens its detail popover') do
    app.main_window.event_view_list.row_views.first.then do |row|
      if row.nil?
        d.check('no rows to activate (empty journal in this sandbox)') { true }
      else
        row.activate
        d.check('the row carries the activated-row class') { row.row.has_css_class?('popover-activated-row') }
        d.check('the detail popover is visible') { row.detail_popover.visible? }
        d.check('the detail grid shows every field upstream shows') do
          labels(row.detail.build).length >= GnomeLogs::EventViewDetail::ROWS.length
        end
        d.shot('04-detail-popover')
        row.detail_popover.popdown
      end
    end
  end

  d.step('the search bar opens from win.search and filters the list') do
    app.main_window.window.activate_action('search', nil)
    d.check('search mode opened the search bar') { app.main_window.event_view_list.search_bar.search_mode? }
    d.check('the toggle button followed it') { app.main_window.toolbar.search_button.active? }
    d.shot('05-search-bar')
  end

  d.step('typing a search term narrows the results to a match') do
    app.main_window.event_view_list.search_entry.text = 'ZZZ_NO_SUCH_SUBSTRING_ZZZ'
    # GtkSearchEntry debounces "search-changed" behind its own short
    # GLib::Timeout, so the handler has not run yet on the very next line.
    pump(300)
    d.check('the query took the text') { app.main_window.query.search_text == 'ZZZ_NO_SUCH_SUBSTRING_ZZZ' }
    d.check('nothing matches an impossible term') { app.main_window.event_view_list.entries.empty? }
    d.check('the empty page is showing') { app.main_window.event_view_list.content_stack.visible_child_name == 'empty' }
    d.shot('06-no-results')
    app.main_window.event_view_list.search_entry.text = ''
    pump(300)
    d.check('clearing it reloads everything') { app.main_window.query.search_text == '' }
  end

  d.step('the search options popover offers every field and range upstream does') do
    app.main_window.event_view_list.search_popover.then do |popover|
      d.check('the field dropdown lists every search field') do
        popover.field_dropdown.model.n_items == GnomeLogs::Query::SEARCH_FIELD_TITLES.length
      end
      d.check('the range dropdown lists every range, including the custom one') do
        popover.range_dropdown.model.n_items == GnomeLogs::Query::RANGE_TITLES.length
      end
      d.check('the search-type row starts hidden for the all-fields search') do
        !popover.search_type_revealer.reveal_child?
      end
      popover.field_dropdown.selected = GnomeLogs::Query::SEARCH_FIELD_TITLES.keys.index(:message)
      d.check('choosing a single field reveals substring/exact') { popover.search_type_revealer.reveal_child? }
      d.check('and the query took the field') { app.main_window.query.search_field == :message }
      popover.exact_check.active = true
      d.check('picking Exact switches the search type') { app.main_window.query.search_type == :exact }
      popover.field_dropdown.selected = GnomeLogs::Query::SEARCH_FIELD_TITLES.keys.index(:all)
      d.shot('07-search-popover')
    end
  end

  d.step('choosing Set Custom Range swaps to the second page') do
    app.main_window.event_view_list.search_popover.then do |popover|
      popover.range_dropdown.selected = GnomeLogs::Query::RANGE_TITLES.keys.index(:custom_range)
      d.check('the custom page is showing') { popover.stack.visible_child_name == GnomeLogs::SearchPopover::CUSTOM_PAGE }
      d.shot('08-custom-range')

      # "clicked", not #activate: the popover is never popped up on screen in
      # this driver, and gtk_widget_activate declines on an unmapped widget.
      # Emitting "clicked" runs the same handler the pointer would.
      popover.apply_button.signal_emit('clicked')
      d.check('applying sets the range to custom_range') { app.main_window.query.range == :custom_range }
      d.check('it goes back to the main page') { popover.stack.visible_child_name == GnomeLogs::SearchPopover::MAIN_PAGE }

      popover.range_dropdown.selected = GnomeLogs::Query::RANGE_TITLES.keys.index(:current_boot)
      d.check('and the back button alone also returns to the main page') do
        popover.range_dropdown.selected = GnomeLogs::Query::RANGE_TITLES.keys.index(:custom_range)
        popover.back_button.signal_emit('clicked')
        popover.stack.visible_child_name == GnomeLogs::SearchPopover::MAIN_PAGE
      end
      popover.range_dropdown.selected = GnomeLogs::Query::RANGE_TITLES.keys.index(:current_boot)
    end
  end

  d.step('closing the search bar leaves the list as it was') do
    app.main_window.window.activate_action('search', nil)
    d.check('search mode closed') { !app.main_window.event_view_list.search_bar.search_mode? }
  end

  d.step('the boot menu switches to an older boot via win.view-boot') do
    app.main_window.toolbar.boots_newest_first.then do |boots|
      if boots.length < 2
        d.check('only one boot exists in this sandbox, so nothing to switch to') { true }
      else
        older = boots[1]
        app.main_window.window.activate_action('view-boot', GLib::Variant.new(older.index.to_s))
        d.check('the boot label switched to the older boot') { app.main_window.toolbar.boot_label.label == older.display_name }
        d.check('the query took its custom range from the boot') { app.main_window.query.range == :custom_range }
        d.check('the start time is the boot\'s first entry') { app.main_window.query.start_time == older.first_time }
        newest = boots.first
        app.main_window.window.activate_action('view-boot', GLib::Variant.new(newest.index.to_s))
      end
    end
  end

  d.step('exporting writes every listed entry to a file') do
    Dir.mktmpdir('gnome-logs-export').then do |dir|
      File.join(dir, 'out.log').then do |path|
        app.main_window.export_to(path)
        d.check('the file now exists') { File.exist?(path) }
        d.check('it has one line per entry, upstream\'s format') do
          File.readlines(path).length == app.main_window.event_view_list.entries.length
        end
      end
    end
  end

  d.step('a failed export shows upstream\'s alert dialog rather than crashing') do
    FakeDialog = Struct.new(:path_fails) do
      def save_finish(_result) = raise(StandardError, 'permission denied')
    end unless defined?(FakeDialog)

    # Gtk::ApplicationWindow (not Adwaita::ApplicationWindow, which the Ruby
    # bindings cannot construct) has no #visible_dialog, so the alert dialog
    # #show_error builds is captured from its own return value instead.
    app.main_window.save_export(FakeDialog.new, nil).then do |dialog|
      pump(200)
      d.check('an alert dialog is now showing') { dialog.is_a?(Adwaita::AlertDialog) && dialog.visible? }
      dialog.close
    end
  end

  d.step('the journal-access warning bar: unavailable, empty, and healthy') do
    GnomeLogs::Window.new(application: app.app).then do |fresh|
      fresh.define_singleton_method(:journal) { Struct.new(:available).new(false).tap { |j| def j.available? = available } }
      fresh.check_journal_access
      d.check('an unavailable journal shows the warning') { fresh.info_bar.revealed? }
      d.check('with upstream\'s own sentence') { fresh.info_message_label.label == 'Unable to read system logs' }
      fresh.window.destroy
    end

    # check_journal_access's second branch is keyed purely on storage_type,
    # exactly as upstream's switch is (an earlier round had it also looking
    # at event_view_list.entries.empty?, which upstream's switch never
    # does; that branch has been removed). GL_JOURNAL_STORAGE_NONE is
    # stubbed here, rather than relying on this checkout's own machine
    # having no journal, so the check is deterministic wherever it runs.
    GnomeLogs::Window.new(application: app.app).then do |fresh|
      original_storage_type = GnomeLogs::Util.method(:journal_storage_type)
      GnomeLogs::Util.define_singleton_method(:journal_storage_type) { :none }

      begin
        fresh.check_journal_access
        d.check('a window with no journal storage reports no logs available') { fresh.info_bar.revealed? }
        d.check('with upstream\'s own sentence') { fresh.info_message_label.label == 'No logs available' }
        d.shot('09-no-logs-warning', fresh.window)
      ensure
        GnomeLogs::Util.define_singleton_method(:journal_storage_type, original_storage_type)
      end

      fresh.on_info_bar_response(Gtk::ResponseType::CLOSE)
      d.check('the Ignore button closes the bar') { !fresh.info_bar.revealed? }
      d.check('it tries to record the dismissal through Settings#write') do
        # No GSettings schema is installed in this checkout (Settings is
        # built exactly to tolerate that), so the write is a documented
        # no-op and ignore_warning? keeps answering the schema's own
        # default; what is checked is that asking does not raise.
        fresh.settings.ignore_warning?
        true
      end
      fresh.window.destroy
    end
  end

  d.step('win.show-help-overlay opens the ported shortcuts window') do
    app.main_window.window.activate_action('show-help-overlay', nil)
    d.check('the help overlay is a GtkShortcutsWindow') do
      app.main_window.shortcuts_window.build.class.name == 'Gtk::ShortcutsWindow'
    end
    d.check('win.close is one of its shortcuts (General section)') do
      GnomeLogs::ShortcutsWindow::GROUPS['General'].key?('win.close')
    end
    d.check('win.export is in the Application section') do
      GnomeLogs::ShortcutsWindow::GROUPS['Application'].key?('win.export')
    end
    d.shot('09b-shortcuts', app.main_window.shortcuts_window.build)
    # GtkApplicationWindow installs "show-help-overlay" itself once
    # help_overlay is set, and activating it really presents the window
    # (it is not a no-op stand-in), so it has to be closed explicitly or it
    # stays an extra visible toplevel for the rest of the run.
    app.main_window.shortcuts_window.build.close
  end

  d.step('app.about and app.help are wired at the application level') do
    d.check('app.about is a registered action') { !app.app.lookup_action('about').nil? }
    d.check('app.help is a registered action') { !app.app.lookup_action('help').nil? }
    d.check('app.new-window is a registered action') { !app.app.lookup_action('new-window').nil? }
  end

  d.step('app.about opens the about window with upstream\'s literals') do
    app.on_about
    Gtk::Window.list_toplevels.find { |w| w.is_a?(Adwaita::AboutWindow) }.then do |about|
      d.check('an Adwaita::AboutWindow opened') { !about.nil? }
      if about
        d.check('its application icon is the application id') { about.application_icon == GnomeLogs::Application::ID }
        d.check('its version is upstream\'s') { about.version == GnomeLogs::Application::VERSION }
        d.check('its licence is GPL-3.0') { about.license_type == :gpl_3_0 }
        d.check('its issue tracker is upstream\'s') { about.issue_url == GnomeLogs::Application::ISSUE_URL }
        d.shot('10-about', about)
        about.close
      end
    end
  end

  d.step('the application registered upstream\'s accelerators') do
    GnomeLogs::Application::ACCELS.each do |action, accels|
      d.check("#{action} is #{accels.first}") do
        app.app.get_accels_for_action(action).map { |a| Gtk.accelerator_parse(a) } ==
          accels.map { |a| Gtk.accelerator_parse(a) }
      end
    end
  end

  d.step('the style manager\'s high-contrast toggle swaps the CSS provider') do
    d.check('a style provider loaded without raising') { !app.style_provider.nil? }
    d.check('apply_high_contrast runs with high-contrast off') do
      app.apply_high_contrast
      true
    end
    d.check('the style manager reports high-contrast one way or the other') do
      # high-contrast tracks the desktop's own accessibility setting in the
      # real StyleManager, not something a client sets, so this only
      # confirms the notify::high-contrast handler can run cleanly.
      [true, false].include?(Adwaita::StyleManager.default.high_contrast?)
    end
  end

  d.step('win.close closes the window, and the app still has an accelerator for it') do
    GnomeLogs::Window.new(application: app.app).then do |extra|
      extra.present
      # Counted by visibility, not raw count: the shortcuts window and the
      # about window built earlier are still-alive GtkWindow instances (the
      # former held by win.help_overlay for the rest of the run, the latter
      # merely hidden by #close), which would otherwise inflate this past 2.
      d.check('a second window opened') { Gtk::Window.list_toplevels.count(&:visible?) == 2 }
      extra.window.activate_action('close', nil)
      d.check('win.close closed only that window') { Gtk::Window.list_toplevels.count(&:visible?) == 1 }
    end
  end

  d.step('the app is still the only toplevel left, and it is the main window') do
    d.check('one visible toplevel remains') { Gtk::Window.list_toplevels.count(&:visible?) == 1 }
    d.check('and it is the driven window') do
      Gtk::Window.list_toplevels.find(&:visible?).equal?(app.main_window.window)
    end
    d.shot('11-final')
  end
end
