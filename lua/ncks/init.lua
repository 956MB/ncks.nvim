local M = {}

local config = {
    location = '~/.ncks',
    layout_config = {
        prompt_position = 'top',
        width = 0.50,
        height = 0.20,
    },
    prompt_title = 'New Nickname',
}

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
    local path = M.config.location
    if vim.loop.fs_stat(vim.fn.expand(path)) then
        callback(path)
    else
        vim.api.nvim_err_writeln('err: Ncks file (' .. path .. ") doesn't exist.")
    end
end

function M.new(nck)
    M.exists(function(path)
        if not nck or #nck == 0 then
            vim.ui.input({
                prompt = M.config.prompt_title .. ' (' .. path .. ')',
            }, function(input)
                if input then
                    M.write(input)
                end
            end)
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
    return { name = name, func = func, opts = opts }
end

local commands = {
    command('NcksInfo', M.info, { desc = 'Display information about the ncks file' }),
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
