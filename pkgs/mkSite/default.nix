{
  pkgs,
  lib,
  postsSrc,
  baseUrl ? "https://example.com",
}: let
  frontmatter = pkgs.callPackage ../../lib/frontmatter.nix {};
  postDirs = lib.filter (d: d != ".." && d != ".") (
    lib.map (f: builtins.elemAt f 0)
    (lib.filter (f: builtins.elemAt f 1 == "directory")
      (lib.mapAttrsToList (n: t: [n t]) (builtins.readDir postsSrc)))
  );

  mkPost = postDir: let
    src = "${postsSrc}/${postDir}";
    meta = frontmatter.parseFrontmatter "${src}/main.md";
  in {
    meta = meta;
    drv = pkgs.callPackage ../mkBlogPost {
      inherit src;
      title = meta.title;
      description = meta.description;
      pubDate = meta.pubDate;
      slug = meta.slug;
      inherit baseUrl;
    };
  };

  generatedPosts = map mkPost postDirs;

  indexHtml = pkgs.writeTextFile {
    name = "index.html";
    text = pkgs.lib.replaceStrings ["{{posts}}"] [
      (lib.concatMapStringsSep "\n" (post: ''
          <li><a href="/blog/${post.meta.slug}/">${post.meta.title}</a></li>
        '')
        generatedPosts)
    ] (builtins.readFile ../../templates/template_index.html);
  };

  rssFeed = pkgs.callPackage ../../scripts/generate-rss.nix {
    posts = map (p: p.meta) generatedPosts;
    inherit baseUrl;
    rssTemplate = builtins.readFile ../../templates/rss.xml;
  };
in
  pkgs.stdenv.mkDerivation {
    name = "site";
    src = postsSrc;
    buildInputs = [pkgs.jq];

    buildPhase = ''
      mkdir -p $out/blog $out/css $out/js

      ${lib.concatMapStrings (post: ''
          mkdir -p $out/blog/${post.meta.slug}
          cp -r ${post.drv}/* $out/blog/${post.meta.slug}/
        '')
        generatedPosts}

      cp -r ${../../css}/* $out/css/
      cp ${rssFeed} $out/rss.xml
      cp ${indexHtml} $out/index.html
    '';

    installPhase = ''
      mkdir -p $out
    '';
  }
