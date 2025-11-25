return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-neotest/neotest-jest',
    'rcasia/neotest-java',
  },
  config = function()
    local neotest = require 'neotest'

    local java_home = '/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
    
    -- Load adapters with error handling
    local adapters = {}
    
    -- Load Java adapter
    local java_ok, java_adapter = pcall(function()
      return require 'neotest-java' {
        command = './gradlew', -- always use wrapper
        args = { 'test' }, -- pass test arg
        cwd = function()
          return require('lspconfig.util').root_pattern('gradlew', 'settings.gradle', 'build.gradle')()
        end,
        env = {
          JAVA_HOME = java_home, -- ensure Neotest uses same Java
          PATH = java_home .. '/bin:' .. os.getenv 'PATH',
        },
      }
    end)
    
    if java_ok then
      table.insert(adapters, java_adapter)
    else
      vim.notify('Failed to load neotest-java: ' .. tostring(java_adapter), vim.log.levels.WARN)
    end
    
    -- Load Jest adapter
    local jest_ok, jest_adapter = pcall(function()
      return require('neotest-jest')({
        -- Find project root - simplified
        cwd = function()
          local root = require('lspconfig.util').root_pattern('package.json', 'next.config.js', 'next.config.mjs', '.git')()
          return root or vim.fn.getcwd()
        end,
        -- Detect package manager
        jestCommand = function()
          local root = require('lspconfig.util').root_pattern('package.json', '.git')() or vim.fn.getcwd()
          if vim.fn.filereadable(root .. '/pnpm-lock.yaml') == 1 then
            return 'pnpm jest'
          elseif vim.fn.filereadable(root .. '/yarn.lock') == 1 then
            return 'yarn jest'
          else
            return 'npm jest'
          end
        end,
        env = { CI = true },
        -- Let neotest-jest use its default test file detection
        -- Remove isTestFile to use defaults
      })
    end)
    
    if jest_ok then
      table.insert(adapters, jest_adapter)
    else
      vim.notify('Failed to load neotest-jest: ' .. tostring(jest_adapter), vim.log.levels.WARN)
    end
    
    if #adapters == 0 then
      vim.notify('No neotest adapters loaded!', vim.log.levels.ERROR)
    end
    
    neotest.setup {
      -- Enable debug logging to help troubleshoot
      log_level = vim.log.levels.DEBUG,
      adapters = adapters,
    }

    -- Keybindings
    local opts = { noremap = true, silent = true }

    -- Run nearest test
    vim.api.nvim_set_keymap('n', '<leader>tn', "<cmd>lua require('neotest').run.run()<CR>", opts)
    -- Run current file
    vim.api.nvim_set_keymap('n', '<leader>tf', "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<CR>", opts)
    -- Run last test
    vim.api.nvim_set_keymap('n', '<leader>tl', "<cmd>lua require('neotest').run.run_last()<CR>", opts)
    -- Toggle test summary
    vim.api.nvim_set_keymap('n', '<leader>ts', "<cmd>lua require('neotest').summary.toggle()<CR>", opts)
    -- Run all tests
    vim.api.nvim_set_keymap('n', '<leader>tp', "<cmd>lua require('neotest').run.run(vim.loop.cwd())<CR>", opts)
    -- View test output (logs/errors) - opens in a split window
    vim.api.nvim_set_keymap('n', '<leader>to', "<cmd>lua require('neotest').output.open()<CR>", opts)
    -- View test output for nearest test (cursor position)
    vim.api.nvim_set_keymap('n', '<leader>tO', "<cmd>lua require('neotest').output.open({ enter = true })<CR>", opts)
    -- View output for last run test (shows full error immediately - BEST FOR QUICK ERROR VIEWING)
    vim.api.nvim_set_keymap('n', '<leader>te', function()
      local neotest = require('neotest')
      local pos = neotest.run.get_last_run()
      if pos then
        neotest.output.open(pos)
      else
        vim.notify('No test has been run yet. Run a test first with <leader>tn or <leader>tf', vim.log.levels.INFO)
      end
    end, { desc = 'Show full error for last run test' })
    
    -- Debug command to check neotest status
    vim.api.nvim_create_user_command('NeotestDebug', function()
      local root = require('lspconfig.util').root_pattern('package.json', 'next.config.js', 'next.config.mjs', '.git')()
      local cwd = vim.fn.getcwd()
      local current_file = vim.fn.expand('%')
      
      local info = {
        '=== Neotest Debug Info ===',
        'Current directory: ' .. cwd,
        'Project root: ' .. (root or 'NOT FOUND'),
        'Current file: ' .. (current_file ~= '' and current_file or 'No file open'),
      }
      
      if root then
        local jest_cmd = 'pnpm jest'
        if vim.fn.filereadable(root .. '/pnpm-lock.yaml') == 1 then
          jest_cmd = 'pnpm jest'
        elseif vim.fn.filereadable(root .. '/yarn.lock') == 1 then
          jest_cmd = 'yarn jest'
        elseif vim.fn.filereadable(root .. '/package-lock.json') == 1 then
          jest_cmd = 'npm jest'
        end
        table.insert(info, 'Jest command: ' .. jest_cmd)
      end
      
      -- Check if adapters are loaded by trying to require them
      local jest_loaded = pcall(require, 'neotest-jest')
      local java_loaded = pcall(require, 'neotest-java')
      table.insert(info, 'neotest-jest loaded: ' .. (jest_loaded and 'YES' or 'NO'))
      table.insert(info, 'neotest-java loaded: ' .. (java_loaded and 'YES' or 'NO'))
      
      -- Try to check neotest state
      local neotest_ok, neotest_state = pcall(function()
        return require('neotest')
      end)
      if neotest_ok then
        table.insert(info, 'Neotest module: OK')
      else
        table.insert(info, 'Neotest module: ERROR - ' .. tostring(neotest_state))
      end
      
      vim.notify(table.concat(info, '\n'), vim.log.levels.INFO, { title = 'Neotest Debug' })
    end, { desc = 'Debug neotest configuration' })
  end,
}
