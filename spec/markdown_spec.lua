local helpers = require('nvim-test.helpers')
local exec_lua = helpers.exec_lua

local function render(lines)
    return exec_lua([[return require("blogger.markdown").render(...)]], lines)
end

describe('blogger.markdown', function()
    before_each(function()
        helpers.clear()
        exec_lua('package.path = ...', package.path)
    end)

    describe('headings and paragraphs', function()
        it('renders headings using Blogger-compatible levels', function()
            assert.are.equal(
                table.concat({
                    '<h3>Title</h3>',
                    '',
                    '<h4>Section</h4>',
                    '',
                    '<h5>Details</h5>',
                    '',
                    '<h6>Deep details</h6>',
                }, '\n'),
                render({
                    '# Title',
                    '',
                    '## Section',
                    '',
                    '### Details',
                    '',
                    '#### Deep details',
                })
            )
        end)

        it('groups non-empty lines into paragraphs', function()
            assert.are.equal(
                table.concat({
                    '<p>First line',
                    'second line.</p>',
                    '',
                    '<p>Second paragraph.</p>',
                }, '\n'),
                render({
                    'First line',
                    'second line.',
                    '',
                    'Second paragraph.',
                })
            )
        end)

        it('renders hard line breaks', function()
            assert.are.equal(
                '<p>First line<br>\nSecond line</p>',
                render({ 'First line  ', 'Second line' })
            )
        end)
    end)

    describe('inline markup', function()
        it('renders emphasis, strong emphasis, and inline code', function()
            assert.are.equal(
                '<p><strong>bold</strong>, <em>italic</em>, and <code>&lt;code&gt;</code>.</p>',
                render({ '**bold**, *italic*, and `<code>`.' })
            )
        end)

        it('renders links and images', function()
            assert.are.equal(
                '<p><a href="https://example.com">Example</a> <img src="image.png" alt="An image"></p>',
                render({ '[Example](https://example.com) ![An image](image.png)' })
            )
        end)

        it('escapes HTML in ordinary text', function()
            assert.are.equal(
                '<p>&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt; &amp; text</p>',
                render({ "<script>alert('x')</script> & text" })
            )
        end)
    end)

    describe('block elements', function()
        it('renders unordered and ordered lists', function()
            assert.are.equal(
                table.concat({
                    '<ul>',
                    '<li>one</li>',
                    '<li><strong>two</strong></li>',
                    '</ul>',
                    '',
                    '<ol>',
                    '<li>first</li>',
                    '<li>second</li>',
                    '</ol>',
                }, '\n'),
                render({
                    '- one',
                    '- **two**',
                    '',
                    '1. first',
                    '2. second',
                })
            )
        end)

        it('renders blockquotes', function()
            assert.are.equal(
                table.concat({
                    '<blockquote>',
                    'A quote',
                    '<em>with emphasis</em>',
                    '</blockquote>',
                }, '\n'),
                render({ '> A quote', '> *with emphasis*' })
            )
        end)

        it('renders horizontal rules', function()
            assert.are.equal(
                table.concat({ '<p>Before</p>', '', '<hr>', '', '<p>After</p>' }, '\n'),
                render({ 'Before', '', '---', '', 'After' })
            )
        end)
    end)

    describe('tables', function()
        it('renders a table with inline markup in cells', function()
            assert.are.equal(
                table.concat({
                    '<table class="markdown-table">',
                    '<thead>',
                    '<tr>',
                    '<th align="left">Name</th>',
                    '<th align="left">Description</th>',
                    '</tr>',
                    '</thead>',
                    '<tbody>',
                    '<tr>',
                    '<td align="left">blogger</td>',
                    '<td align="left"><strong>Preview</strong> plugin</td>',
                    '</tr>',
                    '</tbody>',
                    '</table>',
                }, '\n'),
                render({
                    '| Name | Description |',
                    '| :--- | :--- |',
                    '| blogger | **Preview** plugin |',
                })
            )
        end)

        it('renders column alignment', function()
            assert.are.equal(
                table.concat({
                    '<table class="markdown-table">',
                    '<thead>',
                    '<tr>',
                    '<th align="left">Left</th>',
                    '<th align="center">Center</th>',
                    '<th align="right">Right</th>',
                    '</tr>',
                    '</thead>',
                    '<tbody>',
                    '<tr>',
                    '<td align="left">1</td>',
                    '<td align="center">2</td>',
                    '<td align="right">3</td>',
                    '</tr>',
                    '</tbody>',
                    '</table>',
                }, '\n'),
                render({
                    '| Left | Center | Right |',
                    '| :--- | :----: | ----: |',
                    '| 1 | 2 | 3 |',
                })
            )
        end)

        it('renders tables with default alignment', function()
            local html = render({
                '| Name | Value |',
                '| --- | --- |',
                '| one | two |',
            })

            assert.is_truthy(html:match('<table>'))
            assert.is_truthy(html:match('<th>Name</th>'))
            assert.is_truthy(html:match('<td>one</td>'))
        end)
    end)

    describe('fenced code blocks', function()
        it('renders a language class and escapes code', function()
            assert.are.equal(
                table.concat({
                    '<div class="code">',
                    '<pre><code class="language-scala">if (a &lt; b) {',
                    '  println(&quot;a &amp; b&quot;)',
                    '}</code></pre>',
                    '</div>',
                }, '\n'),
                render({
                    '```scala',
                    'if (a < b) {',
                    '  println("a & b")',
                    '}',
                    '```',
                })
            )
        end)

        it('renders a code block without a language class', function()
            assert.are.equal(
                table.concat({
                    '<div class="code">',
                    '<pre><code>plain &lt;text&gt;</code></pre>',
                    '</div>',
                }, '\n'),
                render({ '```', 'plain <text>', '```' })
            )
        end)
    end)
end)
