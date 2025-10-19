{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          nix-version = pkgs.nix.version;
          nixpkgs-version = pkgs.lib.trivial.version;
        in
        {
          default = self.packages.${system}.docset;

          pandoc-xdg-data = pkgs.callPackage ./pandoc { };

          nix-doc = pkgs.nix.out.doc;
          nixpkgs-doc = pkgs.nixpkgs-manual;

          nixpkgs-docset-html =
            with self.packages.${system};
            pkgs.runCommandNoCC "nixpkgs-docset-html-${nixpkgs-version}"
              {
                XDG_DATA_HOME = pandoc-xdg-data;
                nativeBuildInputs = with pkgs; [
                  pandoc
                  unzip
                ];
                input = self.packages.${system}.builtins-json;
                reader = ./pandoc/custom/builtins-reader.lua;
              }
              ''
                mkdir -p "$out"
                cp -r "${nixpkgs-doc}/share/doc/nixpkgs/style.css" "$out/style.css"

                pandoc "${nixpkgs-doc}/share/doc/nixpkgs/index.html" \
                  -o nixpkgs.zip --defaults=nixpkgs.yaml --metadata outputdir=nixpkgs
                unzip nixpkgs.zip -d "$out"
              '';

          nixpkgs-lib-markdown = pkgs.nixpkgs-manual.lib-docs;

          nixpkgs-lib-docset-html =
            with self.packages.${system};
            pkgs.runCommandNoCC "nixpkgs-lib-docset-html-${nixpkgs-version}"
              {
                XDG_DATA_HOME = pandoc-xdg-data;
                nativeBuildInputs = with pkgs; [ pandoc ];
                input = self.packages.${system}.builtins-json;
                reader = ./pandoc/custom/builtins-reader.lua;
              }
              ''
                mkdir -p "$out"

                for file in "${nixpkgs-lib-markdown}"/*.md; do
                  [[ "$(basename "$file")" = "index.md" ]] && continue

                  local title="nixpkgs.lib.$(basename "$file" .md)"
                  pandoc "$file" -o "$out/$(basename "$file" .md).html" \
                    --defaults=create-docset-html.yaml \
                    --defaults=add-margin-to-code-block.yaml \
                    --metadata title="$title"
                done
              '';

          builtins-json =
            pkgs.runCommandNoCC "nix-builtins-json"
              {
                nativeBuildInputs = [ pkgs.nixVersions.latest ];

                ASAN_OPTIONS = "abort_on_error=1:print_summary=1:detect_leaks=0";
                HOME = "/dummy";
                NIX_CONF_DIR = "/dummy";
                NIX_SSL_CERT_FILE = "/dummy/no-ca-bundle.crt";
                NIX_STATE_DIR = "/dummy";
                NIX_CONFIG = "cores = 0";
              }
              ''
                mkdir -p "$out"
                nix __dump-language >"$out/builtins.json"
              '';

          builtins-docset-html =
            with self.packages.${system};
            pkgs.runCommandNoCC "nix-builtins-docset-html-${nix-version}"
              {
                XDG_DATA_HOME = pandoc-xdg-data;
                nativeBuildInputs = with pkgs; [ pandoc ];
                input = self.packages.${system}.builtins-json;
              }
              ''
                mkdir -p "$out"
                pandoc "${builtins-json}/builtins.json" \
                  -f builtins-reader.lua -o "$out/builtins.html" \
                  --defaults=create-docset-html.yaml \
                  --defaults=add-margin-to-code-block.yaml
              '';

          docset =
            with self.packages.${system};
            pkgs.stdenv.mkDerivation {
              # https://kapeli.com/docsets#dashDocset
              pname = "nix-docset";
              version = "nix-${nix-version}+nixpkgs-${nixpkgs-version}";

              XDG_DATA_HOME = pandoc-xdg-data;

              srcs = [
                builtins-docset-html
                nixpkgs-docset-html
                nixpkgs-lib-docset-html
              ];
              sourceRoot = ".";

              nativeBuildInputs = with pkgs; [
                sqlite
                pandoc
              ];

              dirname = "nix.docset";

              buildPhase = ''
                runHook preBuild

                mkdir -p "$dirname/Contents/Resources/Documents"
                cp ${./Info.plist} "$dirname/Contents/Info.plist"
                cp "${pkgs.nixos-icons}/share/icons/hicolor/16x16/apps/nix-snowflake.png" "$dirname/icon.png"
                cp "${pkgs.nixos-icons}/share/icons/hicolor/32x32/apps/nix-snowflake.png" "$dirname/icon@2x.png"

                pushd "$dirname/Contents/Resources/Documents"

                find ''${srcs[@]} -maxdepth 1 -mindepth 1 -exec cp {} . \;

                # Generate sqlite3 database file
                find . -name '*.html' | xargs -n1 pandoc -t sql-writer.lua | sqlite3 ../docSet.dsidx

                popd
                runHook postBuild
              '';

              installPhase = ''
                runHook preInstall

                mkdir -p "$out"
                mv "$dirname" "$out/$dirname"

                runHook postInstall
              '';
            };
        }
      );

      apps = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = self.apps.${system}.generate-docset;

          generate-docset = {
            type = "app";
            program =
              let
                docset = self.packages.${system}.docset;
              in
              builtins.toString (
                pkgs.writeShellScript "generate-docset" ''
                  [[ -d ./${docset.dirname} ]] && rm -rf ./${docset.dirname}
                  cp -r "${docset}/${docset.dirname}" ./${docset.dirname}
                  chmod -R +rwx ./${docset.dirname}
                ''
              );
            meta.description = "Generate docset on the current directory";
          };
        }
      );
    };
}
