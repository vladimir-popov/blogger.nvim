local M = {}
local render_inline

---Escapes text for safe insertion into HTML text and attribute values.
---@param value string Raw text.
---@return string escaped_value HTML-escaped text.
local function escape(value)
    return value
        :gsub('&', '&amp;')
        :gsub('<', '&lt;')
        :gsub('>', '&gt;')
        :gsub('"', '&quot;')
        :gsub("'", '&#39;')
end

---Removes whitespace from both ends of a string.
---@param value string Input text.
---@return string trimmed_value
local function trim(value)
    return value:match('^%s*(.-)%s*$')
end

---Splits a Markdown table row into trimmed cell values.
---@param line string Markdown table row.
---@return string[]|nil cells Cell values, or nil for a line without a pipe.
local function split_table_row(line)
    if not line:find('|', 1, true) then
        return nil
    end

    line = trim(line)
    if line:sub(1, 1) == '|' then
        line = line:sub(2)
    end
    if line:sub(-1) == '|' then
        line = line:sub(1, -2)
    end

    local cells = {}
    local start = 1
    while true do
        local separator = line:find('|', start, true)
        if not separator then
            cells[#cells + 1] = trim(line:sub(start))
            break
        end
        cells[#cells + 1] = trim(line:sub(start, separator - 1))
        start = separator + 1
    end

    return cells
end

---Parses one Markdown table separator cell.
---@param cell string Separator cell such as `:---`, `:---:`, or `---:`.
---@return string|nil alignment `left`, `center`, `right`, or nil if invalid.
local function parse_table_alignment(cell)
    cell = trim(cell)
    local left = cell:sub(1, 1) == ':'
    local right = cell:sub(-1) == ':'
    local dashes = cell:gsub(':', '')

    if #dashes < 3 or not dashes:match('^%-+$') then
        return nil
    end
    if left and right then
        return 'center'
    elseif left then
        return 'left'
    elseif right then
        return 'right'
    end
    return 'default'
end

---Recognizes a Markdown table header and its separator row.
---@param lines string[] Markdown buffer lines.
---@param index number Candidate header line index.
---@return string[]|nil header Header cells, or nil when no table starts here.
---@return string[]|nil alignments Column alignments.
local function parse_table_header(lines, index)
    local header = split_table_row(lines[index])
    local separator = split_table_row(lines[index + 1] or '')
    if not header or #header < 2 or not separator or #separator ~= #header then
        return nil
    end

    local alignments = {}
    for column, cell in ipairs(separator) do
        alignments[column] = parse_table_alignment(cell)
        if not alignments[column] then
            return nil
        end
    end

    return header, alignments
end

---Appends a Markdown table to the rendered output.
---@param output string[] Rendered block fragments.
---@param header string[] Header cell values.
---@param alignments string[] Column alignments.
---@param rows string[][] Table body rows.
---@return nil
local function add_table(output, header, alignments, rows)
    local rendered = {
        '<table class="markdown-table">',
        '<thead>',
        '<tr>',
    }
    for column, cell in ipairs(header) do
        local align = alignments[column]
        local attribute = align ~= 'default' and ' align="' .. align .. '"' or ''
        rendered[#rendered + 1] = '<th' .. attribute .. '>' .. render_inline(cell) .. '</th>'
    end
    rendered[#rendered + 1] = '</tr>'
    rendered[#rendered + 1] = '</thead>'

    if #rows > 0 then
        rendered[#rendered + 1] = '<tbody>'
        for _, row in ipairs(rows) do
            rendered[#rendered + 1] = '<tr>'
            for column, cell in ipairs(row) do
                local align = alignments[column]
                local attribute = align ~= 'default' and ' align="' .. align .. '"' or ''
                rendered[#rendered + 1] = '<td'
                    .. attribute
                    .. '>'
                    .. render_inline(cell)
                    .. '</td>'
            end
            rendered[#rendered + 1] = '</tr>'
        end
        rendered[#rendered + 1] = '</tbody>'
    end

    rendered[#rendered + 1] = '</table>'
    output[#output + 1] = table.concat(rendered, '\n')
end

---Converts inline Markdown constructs into HTML.
---@param text string A single Markdown text fragment.
---@return string html Rendered inline HTML.
render_inline = function(text)
    local result = {}
    local position = 1

    ---Appends a plain-text fragment after escaping and rendering emphasis.
    ---@param value string Plain-text fragment.
    ---@return nil
    local function add_text(value)
        value = escape(value)
        value = value:gsub('%*%*(.-)%*%*', '<strong>%1</strong>')
        value = value:gsub('__(.-)__', '<strong>%1</strong>')
        value = value:gsub('%*(.-)%*', '<em>%1</em>')
        value = value:gsub('_(.-)_', '<em>%1</em>')
        result[#result + 1] = value
    end

    while position <= #text do
        local start, finish, code = text:find('`([^`]+)`', position)
        local kind = 'code'

        local image_start, image_finish, image_alt, image_url =
            text:find('!%[([^%]]*)%]%(([^%)]+)%)', position)
        if image_start and (not start or image_start < start) then
            start, finish, kind = image_start, image_finish, 'image'
        end

        local link_start, link_finish, link_text, link_url =
            text:find('%[([^%]]+)%]%(([^%)]+)%)', position)
        if link_start and (not start or link_start < start) then
            start, finish, kind = link_start, link_finish, 'link'
        end

        if not start then
            add_text(text:sub(position))
            break
        end

        if start > position then
            add_text(text:sub(position, start - 1))
        end

        if kind == 'code' then
            result[#result + 1] = '<code>' .. escape(code) .. '</code>'
        elseif kind == 'image' then
            result[#result + 1] = '<img src="'
                .. escape(image_url)
                .. '" alt="'
                .. escape(image_alt)
                .. '">'
        else
            result[#result + 1] = '<a href="'
                .. escape(link_url)
                .. '">'
                .. render_inline(link_text)
                .. '</a>'
        end

        position = finish + 1
    end

    return table.concat(result)
end

---Checks whether a line is a Markdown horizontal rule.
---@param line string Markdown source line.
---@return string|nil is_rule Matching rule text, or nil when the line is not a rule.
local function is_horizontal_rule(line)
    return line:match('^%s*%-%s*%-%s*%-%s*[%-%s]*$')
        or line:match('^%s*%*%s*%*%s*%*%s*[%*%s]*$')
        or line:match('^%s*_%s*_%s*_%s*[_%s]*$')
end

---Appends a paragraph assembled from consecutive Markdown lines.
---@param output string[] Rendered block fragments.
---@param paragraph string[] Source lines belonging to the paragraph.
---@return nil
local function add_paragraph(output, paragraph)
    if #paragraph == 0 then
        return
    end

    local rendered = {}
    for _, line in ipairs(paragraph) do
        local hard_break = line:match('%s%s$') ~= nil
        line = line:gsub('%s%s$', '')
        rendered[#rendered + 1] = render_inline(line)
        if hard_break then
            rendered[#rendered] = rendered[#rendered] .. '<br>'
        end
    end

    output[#output + 1] = '<p>' .. table.concat(rendered, '\n') .. '</p>'
end

---Appends an ordered or unordered list to the rendered output.
---@param output string[] Rendered block fragments.
---@param items string[] List item source text.
---@param ordered boolean Whether to render an ordered list.
---@return nil
local function add_list(output, items, ordered)
    local tag = ordered and 'ol' or 'ul'
    local rendered = { '<' .. tag .. '>' }
    for _, item in ipairs(items) do
        rendered[#rendered + 1] = '<li>' .. render_inline(item) .. '</li>'
    end
    rendered[#rendered + 1] = '</' .. tag .. '>'
    output[#output + 1] = table.concat(rendered, '\n')
end

---Appends a syntax-highlightable code block to the rendered output.
---@param output string[] Rendered block fragments.
---@param language string Optional language identifier for highlight.js.
---@param lines string[] Raw source lines inside the code fence.
---@return nil
local function add_code_block(output, language, lines)
    local class = language ~= '' and ' class="language-' .. escape(language) .. '"' or ''
    output[#output + 1] = table.concat({
        '<div class="code">',
        '<pre><code' .. class .. '>' .. escape(table.concat(lines, '\n')) .. '</code></pre>',
        '</div>',
    }, '\n')
end

---Converts a Markdown buffer into HTML suitable for the Blogger template.
---
---Supported constructs include headings, paragraphs, emphasis, inline code,
---links, images, blockquotes, lists, horizontal rules, and fenced code blocks.
---@param lines string[] Markdown buffer lines.
---@return string html Rendered HTML fragment.
function M.render(lines)
    local output = {}
    local paragraph = {}
    local index = 1

    ---Writes the pending paragraph and starts collecting a new one.
    ---@return nil
    local function flush_paragraph()
        add_paragraph(output, paragraph)
        paragraph = {}
    end

    while index <= #lines do
        local line = lines[index]
        local language = line:match('^%s*```([%w_+.-]*)%s*$')
        local table_header, table_alignments = parse_table_header(lines, index)

        if language then
            flush_paragraph()
            local code_lines = {}
            index = index + 1
            while index <= #lines and not lines[index]:match('^%s*```%s*$') do
                code_lines[#code_lines + 1] = lines[index]
                index = index + 1
            end
            add_code_block(output, language, code_lines)
            if index <= #lines then
                index = index + 1
            end
        else
            local heading_marks, heading_text = line:match('^%s*(#+)%s+(.+)%s*$')
            local unordered_item = line:match('^%s*[-+*]%s+(.+)%s*$')
            local ordered_item = line:match('^%s*%d+[.)]%s+(.+)%s*$')
            local quote_text = line:match('^%s*>%s?(.*)$')

            if line:match('^%s*$') then
                flush_paragraph()
            elseif table_header then
                flush_paragraph()
                local rows = {}
                index = index + 2
                while index <= #lines do
                    local row = split_table_row(lines[index])
                    if not row or #row ~= #table_header then
                        break
                    end
                    rows[#rows + 1] = row
                    index = index + 1
                end
                add_table(output, table_header, table_alignments, rows)
                goto continue
            elseif heading_marks then
                flush_paragraph()
                local level = math.min(#heading_marks + 2, 6)
                output[#output + 1] =
                    string.format('<h%d>%s</h%d>', level, render_inline(heading_text), level)
            elseif is_horizontal_rule(line) then
                flush_paragraph()
                output[#output + 1] = '<hr>'
            elseif unordered_item or ordered_item then
                flush_paragraph()
                local items = {}
                local ordered = ordered_item ~= nil
                repeat
                    local item = ordered and lines[index]:match('^%s*%d+[.)]%s+(.+)%s*$')
                        or lines[index]:match('^%s*[-+*]%s+(.+)%s*$')
                    if not item then
                        break
                    end
                    items[#items + 1] = item
                    index = index + 1
                until index > #lines
                add_list(output, items, ordered)
                goto continue
            elseif quote_text then
                flush_paragraph()
                local quote_lines = { render_inline(quote_text) }
                index = index + 1
                while index <= #lines do
                    local next_quote = lines[index]:match('^%s*>%s?(.*)$')
                    if not next_quote then
                        break
                    end
                    quote_lines[#quote_lines + 1] = render_inline(next_quote)
                    index = index + 1
                end
                output[#output + 1] = '<blockquote>\n'
                    .. table.concat(quote_lines, '\n')
                    .. '\n</blockquote>'
                goto continue
            else
                paragraph[#paragraph + 1] = line
            end

            index = index + 1
        end

        ::continue::
    end

    flush_paragraph()
    return table.concat(output, '\n\n')
end

return M
