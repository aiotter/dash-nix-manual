{
  lib,
  symlinkJoin,
  runCommandCC,
  pandoc,
}:

let
  pandoc-highlighting-css =
    runCommandCC "pandoc-highlighting-css" { nativeBuildInputs = [ pandoc ]; }
      ''
        mkdir -p "$out/pandoc/defaults"
        echo '$highlighting-css$' >highlight.template.css
        echo $'```html\n<p>placeholder</p>\n```' >placeholder.md

        cat <<-EOF >"$out/pandoc/defaults/highlighting-css.yaml"
        	variables:
        	  highlighting-css: |
        	    @media (prefers-color-scheme: light) {
        	      $(pandoc --highlight-style=haddock --template=highlight.template.css placeholder.md | sed 's/^/      /')
        	    }
        	    @media (prefers-color-scheme: dark) {
        	      $(pandoc --highlight-style=espresso --template=highlight.template.css placeholder.md | sed 's/^/      /')
        	    }
        EOF
      '';
in

symlinkJoin {
  name = "xdg_data_home";
  paths = [
    (lib.fileset.toSource {
      root = ../.;
      fileset = ./.;
    })
    pandoc-highlighting-css
  ];
}
