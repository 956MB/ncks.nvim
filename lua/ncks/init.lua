local M = {}

local config = {
    location = vim.fn.expand '~/.ncks',
    layout_config = {
        prompt_position = 'top',
        width = 0.50,
        height = 0.20,
    },
    prompt_title = 'New',
}

function M.write_nck(nck)
    local file = io.open(M.config.location, 'a')
    if file and nck and nck ~= '' then
        file:write(nck .. '\n')
        file:close()
        print('Added new nickname: ' .. nck)
    else
        if not file then
            print 'Failed to open ncks file for writing.'
        elseif not nck then
            print 'Nickname is nil.'
        elseif nck == '' then
            print 'Nickname is an empty string.'
        end
    end
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend('force', config, opts or {})
end

function M.new(nck)
    if not nck or #nck == 0 then
        vim.ui.input({
            prompt = M.config.prompt_title .. ' (' .. M.config.location .. ')',
        }, function(input)
            if input then
                M.write_nck(input)
            end
        end)
    else
        M.write_nck(nck)
    end
end

function M.open()
    local ncks_path = M.config.location
    if vim.loop.fs_stat(ncks_path) then
        vim.cmd('edit ' .. ncks_path)
    else
        print('The file does not exist: ' .. ncks_path)
    end
    print('Opened ' .. ncks_path .. ' in a new buffer...')
end

function M.list()
    local lines = {}
    local ncks_path = M.config.location
    if vim.loop.fs_stat(ncks_path) then
        for line in io.lines(ncks_path) do
            table.insert(lines, line)
        end
    end
    return lines
end

function M.random()
    local lines = M.list()
    if lines and #lines > 0 then
        local random_nck = lines[math.random(#lines)]
        vim.fn.setreg('+', random_nck)
        print('Copied random nickname to clipboard: ' .. random_nck)
    else
        print('Ncks file (' .. M.config.location .. ') empty...')
    end
end

function M.info()
    local file_location = M.config.location
    local entry_count = #M.list()
    print 'Ncks File Information:'
    print('  - File Location: ' .. file_location)
    print('  - Entry Count: ' .. entry_count)
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
        name = 'NcksOpen',
        func = M.open,
        opts = { desc = 'Open the ncks file in a new buffer' },
    },
    {
        name = 'NcksList',
        func = function()
            local lines = M.list()
            print('Ncks (' .. M.config.location .. '):')
            for _, line in ipairs(lines) do
                print('  - ' .. line)
            end
        end,
        opts = { desc = 'List all entries in the ncks file' },
    },
    {
        name = 'NcksRandom',
        func = M.random,
        opts = { desc = 'Pick a random entry from the ncks file and copy it to clipboard' },
    },
    {
        name = 'NcksInfo',
        func = M.info,
        opts = { desc = 'Display information about the ncks file' },
    },
}

for _, cmd in ipairs(commands) do
    vim.api.nvim_create_user_command(cmd.name, cmd.func, cmd.opts)
end

return M
