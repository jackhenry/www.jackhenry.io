# Agents

## Project Overview

Nix-based static site generator using flakes. Converts Markdown posts to HTML with RSS generation.

## Tech Stack

- Build: Nix flakes with flake-parts
- Markdown: Pandoc
- Frontmatter: YAML parsed via Pandoc JSON + yq
- Syntax highlighting: highlight.js
- Dev shell: `nix develop`

## Key Commands

```bash
nix build        # Build site to result/
nix develop      # Enter dev shell (just, pandoc, yq, static-web-server, watchexec)
nix run          # Build and serve locally on port 8080
just dev         # Watch mode: rebuild on file changes
just clean       # Remove result/
```

## Directory Structure

```
pkgs/
  mkBlogPost/     # Single post → HTML derivation
    default.nix
    template_article.html
  mkSite/         # Site aggregator
    default.nix
lib/
  frontmatter.nix # YAML frontmatter parsing
scripts/
  generate-rss.nix
posts/            # Blog post sources (one dir per post)
  */main.md       # Post content with YAML frontmatter
templates/
  index.html
  rss.xml
css/main.css
```

## Post Format

```markdown
---
title: Post Title
description: A description
pubDate: 2026-04-29
---

Markdown content...
```

## Build Output

```
result/
  index.html
  rss.xml
  css/main.css
  js/highlight.min.js
  blog/{slug}/index.html
```

## Dependencies

- nixpkgs (github:NixOS/nixpkgs/nixos-25.11)
- flake-parts (github:hercules-ci/flake-parts)
