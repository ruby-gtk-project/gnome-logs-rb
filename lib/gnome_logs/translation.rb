# frozen_string_literal: true

require 'gettext'

module GnomeLogs
  # Message translation against the gnome-logs text domain, so the po/
  # catalogues carried over from the C version keep working. Nearly every
  # msgid is unchanged, because the Ruby strings are the same strings.
  #
  # GetText resolves a text domain per including class, so a class that merely
  # includes this module would look up messages in a domain nobody bound and
  # get the msgid back. Every lookup therefore delegates to this module, which
  # is the one place the domain is bound.
  #
  # The .mo files live beside the app when installed; a source checkout has
  # none, and GetText returns the msgid, which is the English original.
  module Translation
    DOMAIN = 'gnome-logs'

    extend GetText

    bindtextdomain(DOMAIN, path: ENV.fetch('GNOME_LOGS_LOCALE_DIR', File.expand_path('../../po', __dir__)))

    # Named `t` rather than `_` so it reads as a method call in the middle of
    # a widget definition instead of disappearing into the punctuation.
    def t(message) = Translation.translate(message)

    def self.translate(message) = _(message)
  end
end
