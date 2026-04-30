{ pkgs, lib, posts, baseUrl, rssTemplate }:

let
  rssItems = lib.concatMapStrings (post: ''
    <item>
      <title>${post.title}</title>
      <link>${baseUrl}/blog/${post.slug}/</link>
      <description>${post.description}</description>
      <pubDate>${post.pubDate}</pubDate>
    </item>
  '') posts;

  lastBuildDate = pkgs.runCommand "lastbuilddate" {} ''
    date -R > $out
  '';
in
  pkgs.writeTextFile {
    name = "rss.xml";
    text = lib.replaceStrings [ "{{items}}" "{{lastBuildDate}}" ] [
      rssItems
      (builtins.readFile lastBuildDate)
    ] rssTemplate;
  }