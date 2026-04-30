{ pkgs, lib }:

{
  parseFrontmatter = mdFile:
    let
      yamlString = pkgs.runCommand "frontmatter.yaml"
        { buildInputs = [ pkgs.yq ]; }
        ''
          awk '/^---$/ { 
            if(++count == 1) next
            if(count == 2) exit
          } 
          count == 1' ${mdFile} > $out
        '';
      json = pkgs.runCommand "meta.json"
        { buildInputs = [ pkgs.yq ]; }
        ''
          yq '.' ${yamlString} > $out
        '';
      meta = builtins.fromJSON (builtins.readFile json);
      slug = lib.last (lib.splitString "/" (builtins.dirOf mdFile));
    in
      meta // { inherit slug; };
}