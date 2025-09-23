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

          nix-doc = pkgs.nix.out.doc;
          nixpkgs-doc = pkgs.nixpkgs-manual;

          nixpkgs-lib-markdown = pkgs.nixpkgs-manual.lib-docs;

          builtins-json =
            pkgs.runCommandNoCC "nix-builtins-json-${nix-version}"
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

          builtins-html =
            pkgs.runCommandNoCC "nix-builtins-html-${nix-version}"
              {
                nativeBuildInputs = with pkgs; [ pandoc ];
                input = self.packages.${system}.builtins-json;
                reader = ./builtins-reader.lua;
              }
              ''
                mkdir -p "$out"
                pandoc --standalone -f "$reader" -t html "$input/builtins.json" >"$out/builtins.html"
              '';

          docset =
            let
              pandoc-options =
                builtins.toJSON {
                  standalone = true;
                  highlight-style = "tango";
                  filters = [ ./filter.lua ];
                  variables = {
                    header-includes = ''
                      <style>
                        pre.sourceCode {
                          padding: 15px;
                        }

                        h2:not(:first-of-type) {
                          border-top: 1px solid darkgray;
                          margin-top: 2em;
                          padding-top: 2em;
                        }
                      </style>
                    '';
                  };
                }
                |> builtins.toFile "pandoc-options.json";
            in
            with self.packages.${system};
            pkgs.stdenv.mkDerivation {
              # https://kapeli.com/docsets#dashDocset
              pname = "nix-docset";
              version = "nix-${nix-version}+nixpkgs-${nixpkgs-version}";

              nativeBuildInputs = with pkgs; [
                sqlite
                pandoc
              ];

              srcs = [
                nixpkgs-lib-markdown
                builtins-html
              ];

              sourceRoot = ".";
              postUnpack = "rm ${nixpkgs-lib-markdown.name}/index.md";

              dirname = "nix.docset";

              buildPhase = ''
                runHook preBuild

                mkdir -p "$dirname/Contents/Resources/Documents"
                cp ${./Info.plist} "$dirname/Contents/Info.plist"

                local workdir="$(pwd)"
                pushd "$dirname/Contents/Resources/Documents"

                for file in "$workdir/${nixpkgs-lib-markdown.name}"/*.md; do
                  local title="lib.$(basename "$file" .md)"
                  local output_file="$(basename "$file" .md).html"
                  pandoc "$file" --defaults=${pandoc-options} --metadata title="$title" -o "$output_file"
                done

                pandoc "$workdir/${builtins-html.name}/builtins.html" -f html --defaults=${pandoc-options} -o "builtins.html"

                popd

                mv "$dirname/Contents/Resources/Documents/docSet.dsidx" "$dirname/Contents/Resources/docSet.dsidx"

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
