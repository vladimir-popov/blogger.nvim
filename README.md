# blogger.nvim

`blogger.nvim` is a small Neovim plugin for previewing Blogger post content in a local copy of a Blogger HTML template.

The plugin takes the contents of the current buffer, inserts them into the bundled template, extracts the required static assets into a temporary directory, and opens the generated HTML file in the default macOS browser.

Markdown buffers are converted to HTML before insertion. Buffers with another
`filetype`, including HTML buffers, are inserted as-is.

## Requirements

- Neovim with support for `vim.system`, `vim.fs`, and `vim.list_slice` (Neovim 0.10 or newer is recommended).
- macOS, because the plugin uses the `open` command to launch the preview.
- The `tar` command, available by default on macOS.
- A named current buffer. The buffer name is used as part of the temporary preview path.

## Installation

### lazy.nvim

```lua
{
  "vladimir-popov/blogger.nvim",
  config = function()
    require("blogger").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "vladimir-popov/blogger.nvim",
  config = function()
    require("blogger").setup()
  end,
}
```

The plugin does not define commands automatically. Call `require("blogger").setup()` from your Neovim configuration to register them.

## Usage

Open the content you want to preview in a named buffer and run:

```vim
:BloggerPreview
```

This command:

1. Creates a temporary directory for the current buffer.
2. Extracts the bundled `assets.tar` archive on the first run, or when its SHA-256 digest changes.
3. Replaces the `<!--CONTENT-->` marker in the template with the current buffer contents.
4. Opens the generated `index.html` in the default browser.
5. Refreshes the generated preview automatically whenever the buffer is saved.

After the preview has been opened, use:

```vim
:BloggerRefresh
```

to regenerate the HTML file without opening another browser window.

To copy only the article HTML (without the Blogger template) to the system
clipboard, use:

```vim
:BloggerCopy
```

Markdown buffers are converted before copying. HTML buffers are copied as-is.

If the bundled CSS or JavaScript files were changed and you want to force their
extraction, use:

```vim
:BloggerRefreshAssets
```

Normally this is not necessary: the plugin stores the archive digest in
`.assets.sha256` and refreshes the extracted files automatically when
`assets.tar` changes.

The preview is written to a path similar to:

```text
$TMPDIR/blogger/<buffer-name>/index.html
```

If `TMPDIR`, `TEMP`, and `TMP` are not set, `/tmp` is used.

## How the template works

The repository contains a Blogger HTML template in [`index.html`](index.html). The exact line containing `<!--CONTENT-->` is replaced with every line from the current Neovim buffer. All other template markup remains unchanged.

The bundled [`assets.tar`](assets.tar) archive contains the CSS and JavaScript files required by the template. The archive is extracted only when its SHA-256 digest differs from the digest stored in the temporary preview directory's `.assets.sha256` file. Use `:BloggerRefreshAssets` to force extraction.

## Markdown conversion

The preview converter supports the Markdown constructs most useful for blog posts:

- headings (`#` through `######`), mapped to Blogger-friendly `<h3>` through `<h6>`;
- paragraphs and hard line breaks;
- emphasis, strong emphasis, and inline code;
- links and images;
- blockquotes;
- ordered and unordered lists;
- tables with optional column alignment;
- horizontal rules;
- fenced code blocks with an optional language name.

For example:

````markdown
## Queue implementation

```scala
class Node[A] {
  val value: A
}
```
````

becomes:

```html
<h4>Queue implementation</h4>

<div class="code">
  <pre><code class="language-scala">class Node[A] {
  val value: A
}</code></pre>
</div>
```

The `<div class="code"><pre><code>...</code></pre></div>` structure matches the existing Blogger template. The template loads Highlight.js 11.12.0 together with Scala and Zig language definitions, then performs syntax highlighting in the browser.

Tables use standard HTML elements (`table`, `thead`, `tbody`, `tr`, `th`, and
`td`). Markdown alignment markers are converted to `align` attributes:

```markdown
| Left | Center | Right |
| :--- | :----: | ----: |
| 1 | 2 | 3 |
```

The conversion is selected by the current buffer's `filetype`:

- `filetype=markdown` enables Markdown-to-HTML conversion;
- any other `filetype` inserts the buffer contents unchanged.

For an unnamed or manually created Markdown buffer, set the filetype explicitly:

```vim
:set filetype=markdown
```

## Commands

| Command | Description |
| --- | --- |
| `:BloggerPreview` | Generate the preview, open it in the default browser, and enable refresh-on-save for the current buffer. |
| `:BloggerRefresh` | Generate or update the preview without opening the browser. |
| `:BloggerRefreshAssets` | Force re-extraction of the bundled CSS and JavaScript assets. |
| `:BloggerCopy` | Copy only the article HTML to the system clipboard (`+` register). |

## Limitations

- The current implementation is macOS-specific because it calls `open`.
- The preview is a static local HTML file; it does not publish anything to Blogger.
- The plugin uses the buffer's file name to isolate preview files. Use a named buffer to avoid an empty or ambiguous preview directory.
- The template and its assets are bundled with the plugin. To change the visual layout or dependencies, edit `index.html` and rebuild `assets.tar` as appropriate.
- Re-running `:BloggerPreview` replaces the `blogger` autocmd group, so only the most recently previewed buffer remains configured for automatic refresh.

## Project layout

```text
.
├── assets.tar          # Bundled CSS and JavaScript assets
├── index.html          # Blogger template and <!--CONTENT--> insertion point
└── lua/blogger/init.lua
                         # Plugin implementation and user commands
```

## Tests

The tests use [nvim-test](https://github.com/lewis6991/nvim-test), which runs
Busted specs inside a controlled Neovim process. This lets the suite load the
plugin with the real Neovim Lua runtime instead of a standalone system Lua.

### Requirements

You need the following tools available in `PATH`:

- Neovim;
- Git;
- GNU Make or the system `make` command.

No global Busted or LuaRocks installation is required. The test runner is
downloaded into the project-local `.nvim-test/` directory, which is ignored by
Git.

### First run

From the repository root, initialize the local runner:

```sh
make setup
```

The setup target performs two steps:

1. clones `nvim-test` into `.nvim-test/` if it is not present;
2. runs `nvim-test --init`, which downloads the Neovim test collateral used by
   the runner.

After setup, run the complete suite:

```sh
make test
```

The current suite is located in `spec/markdown_spec.lua`. To run only this
file, use:

```sh
make test-file FILE=spec/markdown_spec.lua
```

`test-file` requires the `FILE` variable. If it is omitted, Make prints the
expected command and exits with an error.

### Make targets

| Target | Description |
| --- | --- |
| `make setup` | Downloads and initializes the local `nvim-test` runner. |
| `make test` | Runs every test under `spec/`. |
| `make test-file FILE=...` | Runs one selected test file. |

### Selecting the runner version

The Makefile uses the `main` branch of `nvim-test` by default. A different
branch or tag can be selected during setup:

```sh
make setup NVIM_TEST_REF=v1.4.0
```

The runner itself can also be configured to test a specific Neovim version:

```sh
.nvim-test/bin/nvim-test \
  --runner_version 0.11.0 \
  --target_version 0.10.4 \
  spec \
  --lpath "$(pwd)/lua/?.lua"
```

Here `runner_version` is the Neovim process that executes the test framework,
while `target_version` is the Neovim process in which the plugin is tested.

### How the tests are loaded

The test file uses `nvim-test.helpers.exec_lua()` to execute
`blogger.markdown` inside the target Neovim process. The plugin's `lua/`
directory is passed to the runner through:

```text
--lpath <project>/lua/?.lua
```

This is why tests can load the plugin with:

```lua
require("blogger.markdown")
```

without installing the plugin system-wide.

### Troubleshooting

If `.nvim-test/` is partially downloaded or corrupted, remove only that
project-local directory and initialize it again:

```sh
rm -rf .nvim-test
make setup
```

If the test process cannot find Neovim, verify:

```sh
nvim --version
make --version
git --version
```

## License

This project is licensed under the MIT License. See [`LICENSE`](LICENSE) for the full text.
