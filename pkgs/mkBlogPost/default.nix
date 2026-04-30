{
  pkgs,
  src,
  title,
  description,
  pubDate,
  slug,
  baseUrl,
}:
pkgs.stdenv.mkDerivation {
  name = slug;
  inherit src;

  buildInputs = [pkgs.pandoc];

  buildPhase = ''
    mkdir -p $out/img
    cp -r img/* $out/img/ 2>/dev/null || true
    cp ${../../templates/template_article.html} ./template_article.html

    pandoc main.md \
      --from gfm+alerts \
      --standalone \
      --template=./template_article.html \
      --highlight-style=breezedark \
      -o $out/index.html \
      -V title="${title}" \
      -V description="${description}" \
      -V pubDate="${pubDate}" \
      -V slug="${slug}" \
      -V base="${baseUrl}/blog/${slug}" \
      -V document-css=false
  '';

  installPhase = ''
    mkdir -p $out
    cp -r * $out/
  '';
}
