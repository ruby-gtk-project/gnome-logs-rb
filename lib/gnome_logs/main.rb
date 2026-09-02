# frozen_string_literal: true

# Installed entry point. bin/gnome-logs is the equivalent for running from a
# source checkout; both end in the same single expression.
require 'gnome_logs'

GnomeLogs::Application.new.build.run
