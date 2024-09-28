local M = {}

local config = {
    location = '~/.ncks',
    use_telescope = true,
    layout_config = {
        prompt_position = 'top',
        width = 0.50,
        height = 0.20,
    },
    telescope_defaults = {
        include_location = true,
        selection_caret = '┃ ',
    },
    new_nickname = {
        prompt_title = 'New Nickname',
        prompt_prefix = '   ',
    },
    search = {
        prompt_title = 'Search Nicknames',
        prompt_prefix = '   ',
    },
}

local function reversed_contents(contents)
    local reversed = {}
    for i = #contents, 1, -1 do
        table.insert(reversed, contents[i])
    end
    return reversed
end

local function ensure_telescope()
    local ok, _ = pcall(require, 'telescope')
    return ok
end

local function get_prompt_title(base_title)
    if M.config.telescope_defaults.include_location then
        return string.format('%s (%s)', base_title, M.config.location)
    else
        return base_title
    end
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend('force', config, opts or {})
end

function M.write(nck)
    local file = io.open(vim.fn.expand(M.config.location), 'a')

    if file and nck and nck ~= '' then
        file:write(nck .. '\n')
        file:close()
        print('Added new nickname: ' .. '"' .. nck .. '"')
    else
        if not file then
            vim.api.nvim_err_writeln "err: Failed to open ncks file for writing. Doesn't exist."
        elseif not nck then
            vim.api.nvim_err_writeln 'err: Nickname is nil.'
        elseif nck == '' then
            vim.api.nvim_err_writeln 'err: Nickname is an empty string.'
        end
    end
end

function M.exists(callback)
    local path = vim.fn.expand(M.config.location)

    if vim.fn.filereadable(path) == 1 then
        callback(path)
        return true
    else
        local create = vim.fn.confirm("Nicknames file doesn't exist. (location: " .. M.config.location .. ') Create it?', '&Yes\n&No', 1)
        if create == 1 then
            local file = io.open(path, 'w')
            if file then
                file:close()
                print('Created nicknames file: ' .. path)
                callback(path)
                return true
            else
                vim.api.nvim_err_writeln('Failed to create nicknames file: ' .. path)
            end
        else
            print 'Nicknames file not created. Command aborted.'
        end
    end

    return false
end

function M.new(nck)
    local function toggle_telescope(contents)
        local function handle_input(prompt_bufnr)
            local entry = require('telescope.actions.state').get_current_line()
            if entry and entry ~= '' then
                require('telescope.actions').close(prompt_bufnr)
                M.write(entry)
            end
        end

        require('telescope.pickers')
            .new({
                prompt_prefix = M.config.new_nickname.prompt_prefix,
                selection_caret = M.config.telescope_defaults.selection_caret,
                prompt_title = get_prompt_title(M.config.new_nickname.prompt_title),
                results_title = M.config.location,
                finder = require('telescope.finders').new_table {
                    results = reversed_contents(contents),
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry,
                            ordinal = entry,
                        }
                    end,
                },
                layout_config = M.config.layout_config,
                sorting_strategy = 'ascending',
                attach_mappings = function(prompt_bufnr, map)
                    map('i', '<CR>', function()
                        handle_input(prompt_bufnr)
                    end)
                    map('n', '<CR>', function() end)
                    return true
                end,
            }, {})
            :find()
    end

    M.exists(function(_)
        if not nck or #nck == 0 then
            if ensure_telescope() then
                toggle_telescope(M.list())
            else
                vim.ui.input({
                    prompt = get_prompt_title(M.config.new_nickname.prompt_title),
                }, function(input)
                    if input then
                        M.write(input)
                    end
                end)
            end
        else
            M.write(nck)
        end
    end)
end

function M.open()
    M.exists(function(path)
        vim.cmd('edit ' .. vim.fn.expand(path))
        print('Opened ' .. path .. ' in a new buffer')
    end)
end

function M.list()
    local lines = {}

    M.exists(function(path)
        for line in io.lines(vim.fn.expand(path)) do
            table.insert(lines, line)
        end
    end)

    return lines
end

function M.search()
    if ensure_telescope() then
        local function copy_to_clipboard(prompt_bufnr)
            local selection = require('telescope.actions.state').get_selected_entry()
            if selection then
                vim.fn.setreg('+', selection.value)
                require('telescope.actions').close(prompt_bufnr)
                print('Copied to clipboard: ' .. selection.value)
            end
        end

        M.exists(function()
            require('telescope.pickers')
                .new({
                    prompt_prefix = M.config.search.prompt_prefix,
                    selection_caret = M.config.telescope_defaults.selection_caret,
                    prompt_title = get_prompt_title(M.config.search.prompt_title),
                    finder = require('telescope.finders').new_table {
                        results = reversed_contents(M.list()),
                        entry_maker = function(entry)
                            return {
                                value = entry,
                                display = entry,
                                ordinal = entry,
                            }
                        end,
                    },
                    sorting_strategy = 'ascending',
                    sorter = require('telescope.sorters').get_generic_fuzzy_sorter(),
                    attach_mappings = function(_, map)
                        map('i', '<CR>', function(pb)
                            copy_to_clipboard(pb)
                        end)
                        map('n', '<CR>', function(pb)
                            copy_to_clipboard(pb)
                        end)
                        return true
                    end,
                    layout_config = M.config.layout_config,
                }, {})
                :find()
        end)
    else
        M.exists(function()
            local nicknames = M.list()
            if #nicknames == 0 then
                print 'No nicknames found.'
                return
            end
            for i, nick in ipairs(nicknames) do
                print(string.format('%d. %s', i, nick))
            end
            vim.ui.input({ prompt = 'Enter number to copy (or q to quit): ' }, function(input)
                if input and input ~= 'q' then
                    local num = tonumber(input)
                    if num and nicknames[num] then
                        vim.fn.setreg('+', nicknames[num])
                        print('Copied to clipboard: ' .. nicknames[num])
                    else
                        print 'Invalid selection.'
                    end
                end
            end)
        end)
    end
end

function M.random()
    M.exists(function(path)
        local lines = M.list()
        if lines and #lines > 0 then
            local random_nck = lines[math.random(#lines)]
            vim.fn.setreg('+', random_nck)
            print('Copied random nickname to clipboard: ' .. '"' .. random_nck .. '"')
        else
            vim.api.nvim_err_writeln('Ncks file (' .. path .. ') is empty')
        end
    end)
end

function M.copy_all()
    M.exists(function(path)
        local lines = M.list()

        if lines and #lines > 0 then
            local contents = table.concat(lines, '\n')
            vim.fn.setreg('+', contents)
            print('Copied all nicknames from file (' .. path .. ') to clipboard')
        else
            vim.api.nvim_err_writeln('Ncks file (' .. path .. ') is empty')
        end
    end)
end

function M.info()
    M.exists(function(_)
        local lines = M.list()

        print 'Ncks File Information:'
        print('  - File Location: ' .. M.config.location)
        print('  - Entry Count: ' .. #lines)
    end)
end

local function command(name, func, opts)
    return {
        name = name,
        func = function(cmd_opts)
            M.exists(function(_)
                func(cmd_opts)
            end)
        end,
        opts = opts,
    }
end

local commands = {
    command('NcksInfo', M.info, { desc = 'Display information about the ncks file' }),
    command('NcksSearch', M.search, { desc = 'Search nicknames and copy selection to clipboard' }),
    command('NcksOpen', M.open, { desc = 'Open the ncks file in a new buffer' }),
    command('NcksCopyAll', M.copy_all, { desc = 'Copy all entries in the ncks file to clipboard' }),
    command('NcksRandom', M.random, { desc = 'Pick a random entry from the ncks file and copy it to clipboard' }),

    command('NcksList', function()
        local lines = M.list()
        M.exists(function(path)
            if lines and #lines > 0 then
                print('Ncks (' .. path .. '):')
                for _, line in ipairs(lines) do
                    print('  - ' .. line)
                end
            else
                vim.api.nvim_err_writeln('Ncks file (' .. M.config.location .. ') is empty')
            end
        end)
    end, { desc = 'List all entries in the ncks file' }),

    command('NcksNew', function(opts)
        M.new(opts.args)
    end, { nargs = '?', desc = 'Add a new nickname to the ncks file' }),
}

for _, cmd in ipairs(commands) do
    vim.api.nvim_create_user_command(cmd.name, cmd.func, cmd.opts)
end

return M
