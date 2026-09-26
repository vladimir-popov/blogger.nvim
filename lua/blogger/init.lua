local M = {}
local markdown = require('blogger.markdown')

local sep = package.config:sub(1, 1)

---Builds a normalized filesystem path from path components.
---@param ... string|table Path components, or a table containing components.
---@return string normalized_path
local function path(...)
    local args = { ... }
    args = type(args[1]) == 'table' and args[1] or args
    return vim.fs.normalize(table.concat(args, sep))
end

---Returns the root directory containing the plugin's bundled template files.
---@return string plugin_root Absolute path to the plugin root.
local function script_root_path()
    local script_path = vim.fn.split(debug.getinfo(1, 'S').source:sub(2), sep)
    return sep .. path(vim.list_slice(script_path, 1, #script_path - 3))
end

---Returns the temporary preview directory for the current buffer.
---@return string directory_path Directory used for the current buffer's preview.
local function tmpDirForBuffer()
    local tmp_dir = os.getenv('TMPDIR') or os.getenv('TEMP') or os.getenv('TMP') or '/tmp'
    local bufname = vim.fn.expand('%:t')
    return path(tmp_dir, 'blogger', bufname)
end

---Runs an external command and raises an error when it exits unsuccessfully.
---@param ... string Command name followed by its arguments.
---@return nil
local function execute(...)
    local args = { ... }
    local output = vim.system(args, { text = true }):wait()
    if output.code > 0 then
        error(output.stderr)
    end
end

---Returns the SHA-256 digest of a file.
---@param filename string File to hash.
---@return string digest Hexadecimal SHA-256 digest.
local function file_digest(filename)
    local result = vim.system({ 'shasum', '-a', '256', filename }, { text = true }):wait()
    if result.code > 0 then
        error(result.stderr)
    end
    return result.stdout:match('^(%x+)')
end

---Extracts bundled assets when the archive has changed.
---@param source_path string Plugin root directory.
---@param tmp_path string Preview directory.
---@param force boolean Extract even when the archive digest is unchanged.
---@return nil
local function ensure_assets(source_path, tmp_path, force)
    local archive = path(source_path, 'assets.tar')
    local stamp = path(tmp_path, '.assets.sha256')
    local digest = file_digest(archive)
    local saved_digest
    local stamp_file = io.open(stamp, 'r')
    if stamp_file then
        saved_digest = stamp_file:read('*l')
        stamp_file:close()
    end

    if force or saved_digest ~= digest or vim.fn.isdirectory(path(tmp_path, 'assets')) == 0 then
        execute('tar', '-xf', archive, '-C', tmp_path)
        stamp_file = assert(io.open(stamp, 'w'))
        stamp_file:write(digest, '\n')
        stamp_file:close()
    end
end

---Writes a preview file by replacing the template content marker with buffer content.
---Markdown buffers are rendered as HTML; other buffers are copied unchanged.
---Returns the current buffer content in the format expected by Blogger.
---@return string content Rendered HTML or unchanged buffer content.
local function buffer_content()
    local buffer_lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local filename = vim.api.nvim_buf_get_name(0)
    local is_markdown = vim.bo.filetype == 'markdown' or filename:match('%.[mM][dD]$') ~= nil
    if is_markdown then
        return markdown.render(buffer_lines)
    end
    return table.concat(buffer_lines, '\n')
end

---Writes a preview file by replacing the template content marker with buffer content.
---@param source string Path to the bundled HTML template.
---@param dest string Path where the generated preview should be written.
---@return nil
local function copy_template_with_buffer(source, dest)
    local dest_file, err = io.open(dest, 'w+')
    if err then
        dest_file:close()
        error(err)
    end
    for line in io.lines(source) do
        if line:find('--CONTENT--') then
            dest_file:write(buffer_content(), '\n')
        else
            dest_file:write(line, '\n')
        end
    end
    dest_file:close()
end

---Generates or refreshes the local HTML preview for the current buffer.
---@return string preview_html Absolute path to the generated preview file.
M.refresh = function()
    local source_path = script_root_path()
    local tmp_path = tmpDirForBuffer()
    if vim.fn.isdirectory(tmp_path) == 0 then
        execute('mkdir', '-p', tmp_path)
    end
    ensure_assets(source_path, tmp_path, false)
    local preview_html = path(tmp_path, 'index.html')
    copy_template_with_buffer(path(source_path, 'index.html'), preview_html)
    return preview_html
end

---Forces extraction of the bundled assets for the current buffer.
---@return nil
M.refresh_assets = function()
    local source_path = script_root_path()
    local tmp_path = tmpDirForBuffer()
    if vim.fn.isdirectory(tmp_path) == 0 then
        execute('mkdir', '-p', tmp_path)
    end
    ensure_assets(source_path, tmp_path, true)
end

---Copies the current article HTML to the system clipboard.
---@return nil
M.copy = function()
    vim.fn.setreg('+', buffer_content(), 'v')
    vim.notify('Blogger article HTML copied to the system clipboard')
end

---Opens the current buffer's preview and enables refresh-on-save for its name.
---@return nil
M.preview = function()
    vim.api.nvim_create_autocmd('BufWritePost', {
        group = vim.api.nvim_create_augroup('blogger', { clear = true }),
        pattern = vim.fn.expand('%:t'),
        callback = M.refresh,
    })
    execute('open', M.refresh())
end

---Registers the BloggerPreview and BloggerRefresh Neovim user commands.
---@return nil
M.setup = function()
    vim.api.nvim_create_user_command('BloggerPreview', require('blogger').preview, {})
    vim.api.nvim_create_user_command('BloggerRefresh', require('blogger').refresh, {})
    vim.api.nvim_create_user_command('BloggerRefreshAssets', require('blogger').refresh_assets, {})
    vim.api.nvim_create_user_command('BloggerCopy', require('blogger').copy, {})
end

return M
