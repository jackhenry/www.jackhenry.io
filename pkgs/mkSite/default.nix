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

  generatedPosts = lib.pipe postDirs [
    (map mkPost)
    (lib.sort (a: b: a.meta.pubDate > b.meta.pubDate))
  ];

  mkPage = pageDir: let
    src = "${pagesSrc}/${pageDir}";
    meta = frontmatter.parseFrontmatter "${src}/main.md";
  in {
    meta = meta // {pageName = pageDir;};
    drv = pkgs.callPackage ../mkPage {
      inherit src baseUrl;
      metadata = meta // {pageName = pageDir;};
      postList = generatedPosts;
    };
  };

  generatedPages = map mkPage pageDirs;

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

      ${lib.concatMapStrings (page: let
          dest =
            if page.meta.pageName == "index"
            then "$out"
            else "$out/${page.meta.pageName}";
        in ''
          mkdir -p ${dest}
          cp -r ${page.drv}/* ${dest}/
        '')
        generatedPages}

      cp -r ${../../css}/* $out/css/
      cp ${rssFeed} $out/rss.xml
    '';

    installPhase = ''
      mkdir -p $out
    '';
  }
