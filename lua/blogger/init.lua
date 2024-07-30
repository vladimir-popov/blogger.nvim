local M = {}

local sep = package.config:sub(1, 1)

local function path(...)
    local args = { ... }
    args = type(args[1]) == 'table' and args[1] or args
    return vim.fs.normalize(table.concat(args, sep))
end

local function script_root_path()
    local script_path = vim.fn.split(debug.getinfo(1, 'S').source:sub(2), sep)
    return sep .. path(vim.list_slice(script_path, 1, #script_path - 3))
end

local function tmpDirForBuffer()
    local tmp_dir = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
    local bufname = vim.fn.expand("%:t")
    return path(tmp_dir, 'blogger', bufname)
end

local function execute(...)
    local args = { ... }
    local output = vim.system(args, { text = true }):wait()
    if output.code > 0 then
        error(output.stderr)
    end
end

local function copy_template_with_buffer(source, dest)
    local dest_file, err = io.open(dest, "w+")
    if err then
        dest_file:close()
        error(err)
    end
    for line in io.lines(source) do
        if line:find('--CONTENT--') then
            local buffer_lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
            for _, ln in ipairs(buffer_lines) do
                dest_file:write(ln, '\n')
            end
        else
            dest_file:write(line, '\n')
        end
    end
    dest_file:close()
end

M.preview = function()
    local source_path = script_root_path()
    local tmp_path = tmpDirForBuffer()
    if vim.fn.isdirectory(tmp_path) == 0 then
        execute('mkdir', '-p', tmp_path)
    end
    local assets_dir = vim.fs.find(
        'assets',
        { type = 'directory', path = tmp_path }
    )
    if vim.tbl_isempty(assets_dir) then
        execute('tar', '-xf', path(source_path, 'assets.tar'), '-C', tmp_path)
    end
    local preview_html = path(tmp_path, 'index.html')
    copy_template_with_buffer(path(source_path, 'index.html'), preview_html)
    execute('open', preview_html)
end

M.setup = function()
    vim.api.nvim_create_user_command('BloggerPreview', require('blogger').preview, {})
end

return M
