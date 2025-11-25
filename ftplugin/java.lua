local home = os.getenv 'HOME'
local workspace_path = home .. '/.local/share/nvim/jdtls-workspace/'
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
local workspace_dir = workspace_path .. project_name

-- Get Java 21 Homebrew path
local java21_home = vim.fn.systemlist('brew --prefix openjdk@21')[1] .. '/libexec/openjdk.jdk/Contents/Home'

local java_bin = java21_home .. '/bin/java'

-- Lombok jar path
local lombok_path = home .. '/.local/share/lombok/lombok.jar'
if vim.fn.filereadable(lombok_path) == 0 then
  vim.fn.mkdir(vim.fn.fnamemodify(lombok_path, ':h'), 'p')
  vim.fn.system {
    'curl',
    '-L',
    'https://projectlombok.org/downloads/lombok.jar',
    '-o',
    lombok_path,
  }
end

local status, jdtls = pcall(require, 'jdtls')
if not status then
  return
end

local extendedClientCapabilities = jdtls.extendedClientCapabilities

local config = {
  cmd = {
    java_bin,
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=ALL',
    '-Xmx1g',
    '--add-modules=ALL-SYSTEM',
    '--add-opens',
    'java.base/java.util=ALL-UNNAMED',
    '--add-opens',
    'java.base/java.lang=ALL-UNNAMED',
    '-javaagent:' .. lombok_path,
    '-jar',
    vim.fn.glob(home .. '/.local/share/nvim/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar'),
    '-configuration',
    home .. '/.local/share/nvim/mason/packages/jdtls/config_mac',
    '-data',
    workspace_dir,
  },
  root_dir = require('jdtls.setup').find_root { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle', '.classpath' },
  settings = {
    eclipse = { downloadSources = true },
    java = {
      configuration = {
        runtimes = {
          { name = 'JavaSE-21', path = java21_home },
        },
      },
      signatureHelp = { enabled = true },
      extendedClientCapabilities = extendedClientCapabilities,
      maven = { downloadSources = true },
      referencesCodeLens = { enabled = true },
      references = { includeDecompiledSources = true },
      inlayHints = { parameterNames = { enabled = 'all' } },
      format = { enabled = false },
    },
  },
  init_options = { bundles = {} },
}

jdtls.start_or_attach(config)
