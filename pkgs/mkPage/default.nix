{
  pkgs,
  lib,
  src,
  metadata,
  baseUrl,
  postList,
}: let
  postListMarkdown =
    lib.concatMapStringsSep "\n" (
      post: "- [${post.meta.title}](/blog/${post.meta.slug}/)"
    )
    postList;
  metadataWithDefaults =
    {
      pubDate = "";
      template = "template_page.html";
      base = "${baseUrl}/${metadata.pageName}";
    }
    // metadata;

  inherit (metadataWithDefaults) title description pubDate pageName template base;
in
  pkgs.stdenv.mkDerivation {
    name = pageName;
    inherit src;

    buildInputs = [pkgs.pandoc];

    buildPhase = let
      resolvedTemplate = ../../templates/${template};
      markdownSource = builtins.readFile "${src}/main.md";
      hydratedMarkdownSource = builtins.replaceStrings ["{{post-list}}"] [postListMarkdown] markdownSource;
    in ''
      mkdir -p $out
      cp ${resolvedTemplate} ./template.html

      echo "${markdownSource}"

      echo "${hydratedMarkdownSource}" | pandoc \
        --from gfm+alerts \
        --standalone \
        --template=./template.html \
        --highlight-style=breezedark \
        -o $out/index.html \
        -V title="${title}" \
        -V description="${description}" \
        -V pubDate="${pubDate}" \
        -V base="${base}"
    '';

    installPhase = ''
      mkdir -p $out
    '';
  }
