{
  pkgs,
  lib,
  postsSrc,
  pagesSrc,
  baseUrl ? "https://example.com",
}: let
  frontmatter = pkgs.callPackage ../../lib/frontmatter.nix {};
  postDirs = lib.pipe (builtins.readDir postsSrc) [
    (lib.filterAttrs (name: type: type == "directory"))
    lib.attrNames
  ];
  pageDirs = lib.pipe (builtins.readDir pagesSrc) [
    (lib.filterAttrs (name: type: type == "directory"))
    lib.attrNames
  ];

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

  mkPage = pageDir: let
    src = "${pagesSrc}/${pageDir}";
    meta = frontmatter.parseFrontmatter "${src}/main.md";
  in {
    meta = meta // { pageName = pageDir; };
    drv = pkgs.callPackage ../mkPage {
      inherit src;
      title = meta.title;
      description = meta.description;
      pubDate = meta.pubDate;
      pageName = pageDir;
      inherit baseUrl;
    };
  };

  generatedPosts = map mkPost postDirs;
  generatedPages = map mkPage pageDirs;

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

      ${lib.concatMapStrings (page: ''
          mkdir -p $out/${page.meta.pageName}
          cp -r ${page.drv}/* $out/${page.meta.pageName}/
        '')
        generatedPages}

      cp -r ${../../css}/* $out/css/
      cp ${rssFeed} $out/rss.xml
      cp ${indexHtml} $out/index.html
    '';

    installPhase = ''
      mkdir -p $out
    '';
  }
