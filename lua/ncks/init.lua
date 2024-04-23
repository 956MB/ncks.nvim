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

local function exists()
    local path = vim.fn.expand(M.config.location)

    if vim.loop.fs_stat(path) then
        return true, path
    else
        vim.api.nvim_err_writeln('err: Ncks file (' .. M.config.location .. ") doesn't exist.")
        return false, path
    end
end

function M.new(nck)
    local exist, _ = exists()

    if exist then
        if not nck or #nck == 0 then
            vim.ui.input({
                prompt = M.config.prompt_title .. ' (' .. M.config.location .. ')',
            }, function(input)
                if input then
                    M.write(input)
                end
            end)
        else
            M.write(nck)
        end
    end
end

function M.open()
    local exist, path = exists()

    if exist then
        vim.cmd('edit ' .. path)
        print('Opened ' .. M.config.location .. ' in a new buffer')
    end
end

function M.list()
    local lines = {}
    local exist, path = exists()

    if exist then
        for line in io.lines(path) do
            table.insert(lines, line)
        end
    end

    return exist, lines
end

function M.random()
    local exist, lines = M.list()

    if exist then
        if lines and #lines > 0 then
            local random_nck = lines[math.random(#lines)]
            vim.fn.setreg('+', random_nck)
            print('Copied random nickname to clipboard: ' .. '"' .. random_nck .. '"')
        else
            vim.api.nvim_err_writeln('Ncks file (' .. M.config.location .. ') is empty')
        end
    end
end

function M.copy_all()
    local exist, lines = M.list()

    if exist then
        if lines and #lines > 0 then
            local contents = table.concat(lines, '\n')
            vim.fn.setreg('+', contents)
            print('Copied all nicknames from file (' .. M.config.location .. ') to clipboard')
        else
            vim.api.nvim_err_writeln('Ncks file (' .. M.config.location .. ') is empty')
        end
    end
end

function M.info()
    local exist, lines = M.list()

    if exist then
        print 'Ncks File Information:'
        print('  - File Location: ' .. M.config.location)
        print('  - Entry Count: ' .. #lines)
    end
end

local commands = {
    {
        name = 'NcksNew',
        func = function(opts)
            M.new(opts.args)
        end,
        opts = { nargs = '?', desc = 'Add a new nickname to the ncks file' },
    },
    {
        name = 'NcksInfo',
        func = M.info,
        opts = { desc = 'Display information about the ncks file' },
    },
    {
        name = 'NcksOpen',
        func = M.open,
        opts = { desc = 'Open the ncks file in a new buffer' },
    },
    {
        name = 'NcksCopyAll',
        func = M.copy_all,
        opts = { desc = 'Copy all entries in the ncks file to clipboard' },
    },
    {
        name = 'NcksList',
        func = function()
            local exist, lines = M.list()
            if exist then
                if lines and #lines > 0 then
                    print('Ncks (' .. M.config.location .. '):')
                    for _, line in ipairs(lines) do
                        print('  - ' .. line)
                    end
                else
                    vim.api.nvim_err_writeln('Ncks file (' .. M.config.location .. ') is empty')
                end
            end
        end,
        opts = { desc = 'List all entries in the ncks file' },
    },
    {
        name = 'NcksRandom',
        func = M.random,
        opts = { desc = 'Pick a random entry from the ncks file and copy it to clipboard' },
    },
}

for _, cmd in ipairs(commands) do
    vim.api.nvim_create_user_command(cmd.name, cmd.func, cmd.opts)
end

return M
