# wp-publish.nvim

A Neovim plugin to publish Markdown files directly to WordPress using the REST API.

## Features

- **Publish & Update**: Automatically create or update posts/podcasts based on YAML frontmatter.
- **Podcast Support**: Handles custom post types (e.g., `podcast`) with metadata for season and episode.
- **Automatic Timestamps**: Updates the `updated:` field in your Markdown frontmatter every time you save.
- **Asynchronous**: Uses `curl` in the background to avoid freezing Neovim during network requests.

## Requirements

- Neovim >= 0.7.0
- `curl` installed on your system.
- A WordPress site with [Application Passwords](https://make.wordpress.org/core/2020/11/05/application-passwords-integration-guide/) enabled.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'atareao/wp-publish.nvim',
    config = function()
        -- Optional configuration if needed
    end
}
```

## Configuration

The plugin relies on environment variables for authentication:

```bash
export ATAREAO_URL="https://your-site.com/wp-json/wp/v2/posts"
export ATAREAO_USER="your-username"
export ATAREAO_APP_PASS="your-application-password"
```

## Usage

### Markdown Frontmatter

Your markdown files should include a YAML frontmatter like this:

```markdown
---
title: "My Awesome Post"
updated: 2024-03-20T10:00:00
---

Content goes here...
```

For podcasts:

```markdown
---
title: "Episode Title"
season: 1
episode: 42
updated: 2024-03-20T10:00:00
---

Podcast show notes...
```

### Commands

- `:WPPublish`: Publishes the current buffer to WordPress. If the post already exists (based on metadata for podcasts), it will be updated.

### Autocommands

The plugin automatically updates the `updated:` field in the first 20 lines of any `*.md` file when saving.

## License

MIT
