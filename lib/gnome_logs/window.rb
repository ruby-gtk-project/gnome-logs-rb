# frozen_string_literal: true

module GnomeLogs
  # The main window. Ports GlWindow: header bar, the journal-access warning
  # bar, the log view, and the window actions (close, search, export).
  class Window
    include Translation

    HELP_URI = 'help:gnome-logs'

    def initialize(application:)
      @application = application
      @journal = Journal.new
      @catalog = Catalog.new
      @settings = Settings.new
      @query = Query.new(descending: settings.descending?)
    end

    attr_reader :application, :journal, :catalog, :query, :settings

    def build
      @build ||= window.tap do |win|
        win.child = toolbar_view

        toolbar_view.tap do |tv|
          tv.add_top_bar(toolbar.build)
          tv.content = content_box

          content_box.tap do |box|
            box.append(info_bar)
            box.append(event_view_list.build)

            info_bar.tap do |bar|
              bar.add_child(info_message_label)
              bar.add_button(t('Help'), Gtk::ResponseType::HELP)
              bar.add_button(t('Ignore'), Gtk::ResponseType::CLOSE)

              bar.signal_connect('response') do |_, response|
                on_info_bar_response(response)
              end
            end
          end
        end

        %w[close search export].each do |name|
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect('activate') { public_send("on_#{name}") }
            win.add_action(action)
          end
        end

        win.add_action(view_boot_action)

        win.help_overlay = shortcuts_window.build
        event_view_list.search_bar.key_capture_widget = win

        watch_sort_order
        check_journal_access
      end
    end

    def present = build.present

    def on_close = window.close
    def on_search = toolbar.search_button.active = !toolbar.search_button.active?

    # Ports on_export: write every entry currently listed to a chosen file.
    def on_export
      Gtk::FileDialog.new.tap do |dialog|
        dialog.initial_name = t('log messages')
        dialog.save(window) do |_, result|
          save_export(dialog, result)
        end
      end
    end

    def save_export(dialog, result)
      dialog.save_finish(result).then { |file| export_to(file.path) }
    rescue StandardError => e
      show_error(t('Export Failed'), "#{t('Unable to export log messages to a file')}: #{e.message}")
    end

    def export_to(path)
      File.write(path, event_view_list.entries.map { |entry| "#{entry.to_export_line}\n" }.join)
    end

    # The Ignore button records the dismissal so the warning stays gone, which
    # is what the ignore-warning GSetting is for.
    def on_info_bar_response(response)
      case response
      when Gtk::ResponseType::HELP then open_help
      when Gtk::ResponseType::CLOSE then settings.ignore_warning!
      end
      info_bar.revealed = false
    end

    def open_help
      Gtk::UriLauncher.new(HELP_URI).tap do |launcher|
        launcher.launch(window) do |_, result|
          launcher.launch_finish(result)
        rescue StandardError => e
          show_error(t('Failed To Open Help'), "#{t('Failed to open the given help URI')}: #{e.message}")
        end
      end
    end

    # Ports gl_window_check_journal_access: warn when the journal cannot be
    # read at all rather than silently showing an empty list. journalctl being
    # missing is a case the C version cannot have, since it links against
    # libsystemd instead of shelling out.
    def check_journal_access
      if !journal.available?
        show_info(t('Unable to read system logs'))
      else
        check_journal_storage
      end
    end

    # The storage-type switch of gl_window_check_journal_access: which journal
    # files exist decides which of the three warnings applies.
    def check_journal_storage
      case Util.journal_storage_type
      when :persistent
        unless Util.can_read_system_journal?(:persistent)
          show_info(t('Unable to read system logs'))
        end

        unless Util.can_read_user_journal?
          show_info(t('Unable to read user logs'))
        end
      when :volatile
        unless Util.can_read_system_journal?(:volatile)
          show_info(t('Unable to read system logs'))
        end
      when :none
        show_info(t('No logs available'))
      end
    end

    def show_info(message)
      unless settings.ignore_warning?
        info_message_label.label = message
        info_bar.revealed = true
      end
    end

    def show_error(title, body)
      Adwaita::AlertDialog.new(title, body).tap do |dialog|
        dialog.add_response('close', t('_Close'))
        dialog.present(window)
      end
    end

    def on_entries_changed(entries)
      toolbar.export_button.sensitive = !entries.empty?
    end

    def on_boot_selected(boot)
      query.range = :custom_range
      query.start_time = boot.first_time
      query.end_time = boot.last_time
      event_view_list.reload
    end

    # Ports on_sort_order_changed: the C version watches the GSettings key at
    # the application level and pushes the new order into every open window;
    # here each window watches its own Settings instance, which GSettings
    # still notifies for a key changed by any process.
    def watch_sort_order
      settings.settings&.signal_connect('changed::sort-order') { on_sort_order_changed }
    end

    def on_sort_order_changed
      query.descending = settings.descending?
      event_view_list.reload
    end

    # Ports the win.view-boot stateful radio action installed by GActionEntry
    # actions[] in gl-window.c, which the header bar's boot GMenu targets.
    # change-state (not activate) is where a stateful action commits its new
    # value; activate alone would leave the action's own state unmoved.
    def view_boot_action
      @view_boot_action ||= Gio::SimpleAction.new(
        'view-boot', GLib::VariantType.new('s'), GLib::Variant.new(default_boot_target)
      ).tap do |action|
        action.signal_connect('change-state') { |a, value| on_view_boot_changed(a, value) }
      end
    end

    def default_boot_target = toolbar.boots_newest_first.first&.index.to_s

    def on_view_boot_changed(action, value)
      action.set_state(GLib::Variant.new(value))
      journal.boots.find { |boot| boot.index.to_s == value }&.then { |boot| toolbar.select_boot(boot) }
    end

    def event_view_list
      @event_view_list ||= EventViewList.new(journal: journal, catalog: catalog, query: query,
                                             on_entries_changed: ->(entries) { on_entries_changed(entries) })
    end

    def toolbar
      @toolbar ||= EventToolbar.new(journal: journal, query: query,
                                    on_boot_selected: ->(boot) { on_boot_selected(boot) },
                                    on_search_toggled: ->(active) { event_view_list.search_bar.search_mode = active })
    end

    def shortcuts_window = @shortcuts_window ||= ShortcutsWindow.new
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def window
      @window ||= Gtk::ApplicationWindow.new(application).tap do |win|
        win.title = t('Logs')
        win.set_default_size(1200, 600)
      end
    end

    def info_bar
      @info_bar ||= Gtk::InfoBar.new.tap do |bar|
        bar.message_type = :error
        bar.revealed = false
      end
    end

    def info_message_label
      @info_message_label ||= Gtk::Label.new.tap do |lbl|
        lbl.hexpand = true
        lbl.halign = :start
      end
    end
  end
end
