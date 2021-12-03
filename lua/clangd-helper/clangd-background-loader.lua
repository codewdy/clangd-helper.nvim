local utils = require("clangd-helper/utils")

local config = {
  thread_num = 5
}

local file_handler = {
}

local handled_client = {
}

local function load_processor(processor_args)
  local idx = processor_args.ptr
  if idx > #processor_args.filelist then
    return
  end
  processor_args.ptr = idx + 1
  local filename = processor_args.filelist[idx]
  local client_id = processor_args.client_id
  utils.async_read(filename, function (err, data)
    if err ~= nil then
      processor_args.error = processor_args.error + 1
      print("Processing:", processor_args.processed, '/', processor_args.error, '/', #processor_args.filelist)
      load_processor(processor_args)
      return
    end
    local handler_name = tostring(client_id) .. ':file://' .. filename
    file_handler[handler_name] = function()
      processor_args.processed = processor_args.processed + 1
      print("Processing:", processor_args.processed, '/', processor_args.error, '/', #processor_args.filelist, '\n')
      load_processor(processor_args)
    end
    local client = vim.lsp.get_client_by_id(client_id)
    local params = {
      textDocument = {
        version = 0,
        uri = 'file://' .. filename,
        languageId = "cpp",
        text = data
      }
    }
    if client.notify('textDocument/didOpen', params) then
      file_handler[handler_name] = nil
    end
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
  utils.async_walk(client.config.root_dir, function(err, filelist)
    if err then
      print("ERROR")
      return
    end
    local processor_args = {
      client_id = client.id,
      filelist = filelist,
      ptr = 1,
      processed = 0,
      error = 0
    }
    for i=1,config.thread_num do
      load_processor(processor_args)
    end
  end)
end

local function on_publish_diagnostics(_, result, ctx, config)
  local client_id = ctx.client_id
  local uri = result.uri

  local handler_name = tostring(client_id) .. ':' .. uri

  local hanlder = file_handler[handler_name]
  file_handler[handler_name] = nil

  if hanlder ~= nil then
    handler()
  end
end

local function on_attach(client, bufnr)
  handle_client(client)
end

local function on_publish_diagnostics_wapper(func)
  return function(a,b,c,d)
    on_publish_diagnostics(a,b,c,d)
    func(a,b,c,d)
  end
end

local function setup(cfg)
  config = vim.tbl_extend("force", config, cfg)
end

return {
  on_attach = on_attach,
  on_publish_diagnostics_wapper = on_publish_diagnostics_wapper,
  setup = setup
}
