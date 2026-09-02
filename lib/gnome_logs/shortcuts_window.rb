# frozen_string_literal: true

module GnomeLogs
  # The Ctrl+? shortcuts window, ported from data/help-overlay.ui.
  #
  # GtkShortcutsWindow, GtkShortcutsSection and GtkShortcutsGroup cannot be
  # constructed from the Ruby bindings — their inherited GtkWindow/GtkBox
  # constructors reject the subtype ("GtkWindow is not subtype of
  # GtkShortcutsWindow"). Gtk::Builder instantiates them fine, so the window is
  # described as a table here and rendered to the interface XML the builder
  # wants.
  class ShortcutsWindow
    include Translation

    GROUPS = {
      'General' => {
        'app.new-window' => 'Open a new window',
        'win.close' => 'Close a window',
        'app.help' => 'Show help',
        'win.show-help-overlay' => 'Keyboard shortcuts'
      },
      'Application' => {
        'win.search' => 'Find',
        'win.export' => 'Export logs to a file'
      }
    }.freeze

    def build = @build ||= builder.get_object('help_overlay')

    def builder = @builder ||= Gtk::Builder.new(string: interface_xml)

    def interface_xml
      <<~XML
        <interface>
          <object class="GtkShortcutsWindow" id="help_overlay">
            <child>
              <object class="GtkShortcutsSection">
                #{GROUPS.map { |title, shortcuts| group_xml(title, shortcuts) }.join}
              </object>
            </child>
          </object>
        </interface>
      XML
    end

    def group_xml(title, shortcuts)
      <<~XML
        <child>
          <object class="GtkShortcutsGroup">
            <property name="title">#{t(title)}</property>
            #{shortcuts.map { |action, label| shortcut_xml(action, label) }.join}
          </object>
        </child>
      XML
    end

    def shortcut_xml(action, label)
      <<~XML
        <child>
          <object class="GtkShortcutsShortcut">
            <property name="action-name">#{action}</property>
            <property name="title">#{t(label)}</property>
          </object>
        </child>
      XML
    end
  end
end
