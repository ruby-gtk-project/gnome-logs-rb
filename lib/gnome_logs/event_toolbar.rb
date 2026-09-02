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
        bar.pack_start(main_menu_button)
        bar.pack_start(boot_button)
        bar.pack_end(search_button)
        bar.pack_end(export_button)

        title_box.tap do |box|
          box.append(title_label)
          box.append(boot_label)
        end

        boot_button.tap do |btn|
          btn.popover = boot_popover

          boot_popover.tap do |popover|
            popover.child = boot_list

            boot_list.tap do |lb|
              journal.boots.reverse_each { |boot| lb.append(boot_row(boot)) }

              lb.signal_connect('row-activated') do |_, row|
                select_boot(boots_newest_first[row.index])
              end
            end
          end
        end

        search_button.tap do |btn|
          btn.signal_connect('toggled') { on_search_toggled.call(btn.active?) }
        end
      end
    end

    def select_boot(boot)
      boot_label.label = boot.display_name
      boot_popover.popdown
      on_boot_selected.call(boot)
    end

    def boots_newest_first = @boots_newest_first ||= journal.boots.reverse

    def boot_row(boot)
      Gtk::ListBoxRow.new.tap do |row|
        row.child = Gtk::Label.new(boot.display_name).tap do |lbl|
          lbl.xalign = 0
          lbl.margin_top = 6
          lbl.margin_bottom = 6
          lbl.margin_start = 12
          lbl.margin_end = 12
        end
      end
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def boot_popover = @boot_popover ||= Gtk::Popover.new

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
        lbl.add_css_class('subtitle')
        lbl.add_css_class('dim-label')
        lbl.ellipsize = :end
      end
    end

    def boot_button
      @boot_button ||= Gtk::MenuButton.new.tap do |btn|
        btn.icon_name = 'pan-down-symbolic'
        btn.tooltip_text = t('Choose the boot from which to view logs')
      end
    end

    def boot_list
      @boot_list ||= Gtk::ListBox.new.tap do |lb|
        lb.selection_mode = :none
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

    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |menu|
        menu.append(t('_New Window'), 'app.new-window')
        menu.append(t('_Keyboard Shortcuts'), 'win.show-help-overlay')
        menu.append(t('_Help'), 'app.help')
        menu.append(t('_About Logs'), 'app.about')
      end
    end
  end
end
