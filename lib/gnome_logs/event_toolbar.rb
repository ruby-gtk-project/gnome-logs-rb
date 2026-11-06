# frozen_string_literal: true

module GnomeLogs
  # The header bar. Ports GlEventToolbar: the title, the boot selector, the
  # export button, the search toggle and the primary menu.
  class EventToolbar
    include Translation

    def initialize(journal:, query:, on_boot_selected:, on_search_toggled:)
      @journal = journal
      @query = query
      @on_boot_selected = on_boot_selected
      @on_search_toggled = on_search_toggled
    end

    attr_reader :journal, :query, :on_boot_selected, :on_search_toggled

    def build
      @build ||= header_bar.tap do |bar|
        bar.title_widget = title_box
        bar.pack_start(boot_button)
        bar.pack_end(main_menu_button)
        bar.pack_end(export_button)
        bar.pack_end(search_button)

        title_box.tap do |box|
          box.append(title_label)
          box.append(boot_label)
        end

        boot_button.menu_model = boot_menu

        search_button.tap do |btn|
          btn.signal_connect('toggled') { on_search_toggled.call(btn.active?) }
        end
      end
    end

    # Called externally once Window's win.view-boot action commits a new
    # state, and once from build to show the default selection.
    def select_boot(boot)
      boot_label.label = boot.display_name
      on_boot_selected.call(boot)
    end

    def boots_newest_first = @boots_newest_first ||= journal.boots.reverse

    # Ports the runtime-built boot GMenu of gl-eventtoolbar.c: a single
    # "Boot" section of win.view-boot radio items, newest boot first.
    def boot_menu
      @boot_menu ||= Gio::Menu.new.tap do |menu|
        boot_section.tap do |section|
          boots_newest_first.each do |boot|
            section.append_item(boot_menu_item(boot))
          end
        end

        menu.append_section(t('Boot'), boot_section)
      end
    end

    def boot_section = @boot_section ||= Gio::Menu.new

    def boot_menu_item(boot)
      Gio::MenuItem.new(boot.display_name, nil).tap do |item|
        item.set_action_and_target_value('win.view-boot', GLib::Variant.new(boot.index.to_s))
      end
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def title_box
      @title_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.valign = :center
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new(t('Logs')).tap do |lbl|
        lbl.add_css_class('title')
      end
    end

    def boot_label
      @boot_label ||= Gtk::Label.new(boots_newest_first.first&.display_name.to_s).tap do |lbl|
        lbl.add_css_class('caption')
        lbl.add_css_class('dim-label')
        lbl.ellipsize = :end
      end
    end

    # The title-menu-button and flat classes are the ones the C version's
    # header bar template sets on this button; data/style-hc.css styles the
    # former.
    def boot_button
      @boot_button ||= Gtk::MenuButton.new.tap do |btn|
        btn.icon_name = 'pan-down-symbolic'
        btn.tooltip_text = t('Choose the boot from which to view logs')
        btn.add_css_class('title-menu-button')
        btn.add_css_class('flat')
      end
    end

    def main_menu_button
      @main_menu_button ||= Gtk::MenuButton.new.tap do |btn|
        btn.icon_name = 'open-menu-symbolic'
        btn.menu_model = primary_menu
        btn.tooltip_text = t('Main Menu')
      end
    end

    def search_button
      @search_button ||= Gtk::ToggleButton.new.tap do |btn|
        btn.icon_name = 'edit-find-symbolic'
        btn.tooltip_text = t('Search all the logs of the current category')
      end
    end

    def export_button
      @export_button ||= Gtk::Button.new.tap do |btn|
        btn.icon_name = 'document-save-symbolic'
        btn.action_name = 'win.export'
        btn.tooltip_text = t('Export logs to a file')
      end
    end

    # Ports the two-section primary-menu of gl-eventtoolbar.ui: New Window on
    # its own, separated from the help/about group below it.
    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, new_window_section)
        menu.append_section(nil, help_section)
      end
    end

    def new_window_section
      @new_window_section ||= Gio::Menu.new.tap do |section|
        section.append(t('_New Window'), 'app.new-window')
      end
    end

    def help_section
      @help_section ||= Gio::Menu.new.tap do |section|
        section.append(t('_Keyboard Shortcuts'), 'win.show-help-overlay')
        section.append(t('_Help'), 'app.help')
        section.append(t('_About Logs'), 'app.about')
      end
    end
  end
end
