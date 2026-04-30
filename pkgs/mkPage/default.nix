{
  pkgs,
  src,
  title,
  description,
  pubDate,
  pageName,
  baseUrl,
}:
pkgs.stdenv.mkDerivation {
  name = pageName;
  inherit src;

  buildInputs = [pkgs.pandoc];

  buildPhase = ''
    mkdir -p $out
    cp ${../../templates/template_page.html} ./template_page.html

    pandoc main.md \
      --from gfm+alerts \
      --standalone \
      --template=./template_page.html \
      --highlight-style=breezedark \
      -o $out/index.html \
      -V title="${title}" \
      -V description="${description}" \
      -V pubDate="${pubDate}" \
      -V base="${baseUrl}/${pageName}" \
      -V document-css=false
  '';

  installPhase = ''
    mkdir -p $out
  '';
}