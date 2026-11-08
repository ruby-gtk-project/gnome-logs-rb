# frozen_string_literal: true

# Installed entry point. bin/gnome-logs is the equivalent for running from a
# source checkout; both end in the same single expression.
require 'gnome_logs'

# build returns the plain Gtk::Application (so build.run reads as one widget
# expression); passing the real argv here, rather than letting Gtk::Application#run
# default to none, is what lets --version/-v reach on_handle_local_options.
GnomeLogs::Application.new.build.run([$PROGRAM_NAME, *ARGV])
