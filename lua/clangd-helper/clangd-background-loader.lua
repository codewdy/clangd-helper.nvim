local utils = require("clangd-helper/utils")

local config = {
  configure_file = '.root'
}

local handled_client = {
}

local function clangd_load(client, filename)
  utils.async_read(filename, function (err, data)
    if err ~= nil then
      require("log").info("Processing:", processor_args.processed, '/', processor_args.error, '/', #processor_args.filelist)
      return
    end
    local params = {
      textDocument = {
        version = 0,
        uri = 'file://' .. filename,
        languageId = "cpp",
        text = data
      }
    }
    client.notify('textDocument/didOpen', params)
  end)
end

local function handle_client(client)
  if client.config.name ~= 'clangd' or client.config.root_dir == nil or client.config.root_dir == "" then
    return
  end
  if handled_client[client.id] == nil then
    handled_client[client.id] = true
  else
    return
  end
  utils.async_read(client.config.root_dir .. '/' .. config.configure_file, vim.schedule_wrap(function(err, data)
    if err then
      print("No configure_file was found, skip")
      return
    end
    local status, result = pcall(vim.fn.json_decode, data)
    xxx = status
    if not status then
      print("configure_file cannot be parsed, skip")
      return
    end
    local source_dir = result.source_dir
    if source_dir == nil then
      print("no source_dir is configured, skip")
      return
    end
    local absolute_source_dir = {}
    for _,s in ipairs(source_dir) do
      if string.sub(s, 1, 1) == '/' then
        table.insert(absolute_source_dir, vim.loop.fs_realpath(s) .. '/')
      else
        table.insert(absolute_source_dir,
            vim.loop.fs_realpath(client.config.root_dir .. '/' .. s) .. '/')
      end
    end
    utils.async_walk(client.config.root_dir, function(err, filelist)
      if err then
        print("file list is not found, check rg is installed")
        return
      end
      local filtered_filelist = {}
      for _,filename in ipairs(filelist) do
        for _,s in ipairs(absolute_source_dir) do
          if string.sub(filename, 1, #s) == s then
            table.insert(filtered_filelist, filename)
            break
          end
        end
      end
      for _,filename in ipairs(filtered_filelist) do
        clangd_load(client, filename)
      end
    end)
  end))
end

local function on_attach(client, bufnr)
  handle_client(client)
end

local function setup(cfg)
  config = vim.tbl_extend("force", config, cfg)
end

return {
  on_attach = on_attach,
  setup = setup
}
