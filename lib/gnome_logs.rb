# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

module GnomeLogs
  # Translation is a plain module the widget classes include, so it is required
  # eagerly rather than autoloaded.
  require 'gnome_logs/translation'

  autoload :Application, 'gnome_logs/application'
  autoload :Catalog, 'gnome_logs/catalog'
  autoload :Category, 'gnome_logs/category'
  autoload :CategoryList, 'gnome_logs/category_list'
  autoload :EventToolbar, 'gnome_logs/event_toolbar'
  autoload :EventViewDetail, 'gnome_logs/event_view_detail'
  autoload :EventViewList, 'gnome_logs/event_view_list'
  autoload :EventViewRow, 'gnome_logs/event_view_row'
  autoload :Journal, 'gnome_logs/journal'
  autoload :JournalEntry, 'gnome_logs/journal_entry'
  autoload :Query, 'gnome_logs/query'
  autoload :SearchPopover, 'gnome_logs/search_popover'
  autoload :Settings, 'gnome_logs/settings'
  autoload :ShortcutsWindow, 'gnome_logs/shortcuts_window'
  autoload :Window, 'gnome_logs/window'
end
