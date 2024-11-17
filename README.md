# file-extra-metadata

This is a Yazi plugin that replaces the default file metadata with extra information.

## Preview

Before:

![Before](assets/2024-11-17-07-44-42.png)

After:

![After](assets/2024-11-17-07-42-17.png)

## Installation

Install the plugin:

```sh
ya pack -a boydaihungst/file-extra-metadata
```

Create `~/.config/yazi/yazi.toml` and add:

```toml
[plugin]
append_previewers = [
    { name = "*", run = "file-extra-metadata" },
]
```
