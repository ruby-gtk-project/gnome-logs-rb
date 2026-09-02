{
  description = "GNOME Logs — a Ruby GTK4/Libadwaita port of the systemd journal viewer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        ruby = pkgs.ruby_3_4;

        # The gtk4/adwaita gems are thin wrappers over the system libraries via
        # gobject-introspection, so the C extensions need the GNOME stack at
        # build time and the typelibs need it again at run time.
        nativeLibs = with pkgs; [
          glib
          gtk4
          libadwaita
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          harfbuzz
          atk
        ];

        mkGems = { name, groups }: pkgs.bundlerEnv {
          inherit name ruby groups;
          gemdir = ./.;

          # nixpkgs already knows how to build the GTK3-era ruby-gnome gems
          # (glib2, gio2, pango, atk, cairo-gobject, gdk_pixbuf2,
          # gobject-introspection), so those defaults are kept as-is. Only the
          # GTK4-era gems are missing, and they need the same shape as gtk3.
          gemConfig = pkgs.defaultGemConfig // (
            let
              gtk4Deps = with pkgs; {
                nativeBuildInputs = [ binutils pkg-config ];
                buildInputs = [ util-linux libselinux libsepol systemd ];
                propagatedBuildInputs = [
                  atk
                  cairo
                  fribidi
                  gdk-pixbuf
                  glib
                  gobject-introspection
                  graphene
                  gtk4
                  harfbuzz
                  lerc
                  libadwaita
                  libdatrie
                  libdeflate
                  libepoxy
                  libpthread-stubs
                  libsysprof-capture
                  libthai
                  libwebp
                  libxdmcp
                  libxkbcommon
                  pango
                  pcre2
                  xz
                  zstd
                ];
              };
            in
            {
              gdk4 = attrs: gtk4Deps;
              gtk4 = attrs: gtk4Deps;
              adwaita = attrs: gtk4Deps;
            }
          );
        };

        # The package ships only the runtime gems; the dev shell adds rubocop.
        gems = mkGems { name = "gnome-logs-ruby-gems"; groups = [ "default" ]; };
        devGems = mkGems { name = "gnome-logs-ruby-dev-gems"; groups = [ "default" "development" ]; };

        gnome-logs = pkgs.stdenv.mkDerivation {
          pname = "gnome-logs-ruby";
          version = "45.alpha";
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper pkgs.wrapGAppsHook4 pkgs.glib pkgs.gettext ];
          buildInputs = nativeLibs ++ [ gems gems.wrappedRuby ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/gnome-logs
            cp -r lib data $out/share/gnome-logs/

            mkdir -p $out/bin
            makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/gnome-logs \
              --add-flags "-I$out/share/gnome-logs/lib" \
              --add-flags "$out/share/gnome-logs/lib/gnome_logs/main.rb" \
              --set GNOME_LOGS_DATA_DIR "$out/share/gnome-logs/data" \
              --set GNOME_LOGS_LOCALE_DIR "$out/share/locale" \
              --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.systemd ]}

            install -Dm644 data/org.gnome.Logs.desktop \
              $out/share/applications/org.gnome.Logs.desktop

            install -Dm644 data/org.gnome.Logs.gschema.xml \
              $out/share/gsettings-schemas/${"$"}{pname}-${"$"}{version}/glib-2.0/schemas/org.gnome.Logs.gschema.xml
            glib-compile-schemas \
              $out/share/gsettings-schemas/${"$"}{pname}-${"$"}{version}/glib-2.0/schemas

            install -Dm644 data/icons/scalable/org.gnome.Logs.svg \
              $out/share/icons/hicolor/scalable/apps/org.gnome.Logs.svg
            install -Dm644 data/icons/symbolic/org.gnome.Logs-symbolic.svg \
              $out/share/icons/hicolor/symbolic/apps/org.gnome.Logs-symbolic.svg

            # The po catalogues carry over from the C version; the msgids are
            # the same strings the Ruby passes to Translation.t.
            for po in po/*.po; do
              lang=$(basename "$po" .po)
              install -d $out/share/locale/$lang/LC_MESSAGES
              msgfmt "$po" -o $out/share/locale/$lang/LC_MESSAGES/gnome-logs.mo
            done

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "View and search systemd journal logs";
            homepage = "https://apps.gnome.org/Logs/";
            license = licenses.gpl3Plus;
            mainProgram = "gnome-logs";
            platforms = platforms.linux;
          };
        };
      in
      {
        packages.default = gnome-logs;
        packages.gnome-logs = gnome-logs;

        apps.default = flake-utils.lib.mkApp { drv = gnome-logs; };

        devShells.default = pkgs.mkShell {
          packages = [
            devGems
            devGems.wrappedRuby
            pkgs.bundix
            pkgs.pkg-config
          ] ++ nativeLibs;

          shellHook = ''
            echo "gnome-logs (Ruby GTK4) — run: ruby -Ilib bin/gnome-logs"
          '';
        };

        # Regenerating gemset.nix after a Gemfile change:
        #   nix develop .#bundle -c bundle lock && nix develop .#bundle -c bundix
        devShells.bundle = pkgs.mkShell {
          packages = [ ruby pkgs.bundler pkgs.bundix pkgs.pkg-config ] ++ nativeLibs;
        };
      });
}
