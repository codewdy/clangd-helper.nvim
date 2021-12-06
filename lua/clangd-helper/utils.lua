local function async_walk(dir, callback)
  local whole_err = nil
  local datas = ""
  local function onread(err, data)
    if err then
      whole_err = err
    end
    if data then
      datas = datas .. data
    end
  end

  local stdout = vim.loop.new_pipe(false)
  handle = vim.loop.spawn('rg', {
      args = {'--type', 'cpp', '--files', vim.loop.fs_realpath(dir)},
      stdio = {nil, stdout, nil}
    },
    vim.schedule_wrap(function()
      pcall(function() stdout:read_stop() end)
      pcall(function() stdout:close() end)
      pcall(function() handle:close() end)
      if whole_err ~= nil then
        callback(whole_err, {})
      else
        local results = {}
        local vals = vim.split(datas, "\n")
        for _, d in pairs(vals) do
          if d ~= "" then
            table.insert(results, d)
          end
        end
        callback(nil, results)
      end
    end)
  )
  vim.loop.read_start(stdout, onread)
end

local function async_read(filename, callback)
  vim.loop.fs_open(filename, "r", 438, function(err_open, fd)
    if err_open then
      return callback(err_open, nil)
    end
    vim.loop.fs_fstat(fd, function(err_fstat, stat)
      if stat.type ~= "file" then
        return callback(err_fstat, nil)
      end
      vim.loop.fs_read(fd, stat.size, 0, function(err_read, data)
        assert(not err_read, err_read)
        if err_read then
          return callback(err_read, nil)
        end
        vim.loop.fs_close(fd, function(err_close)
          if err_close then
            return callback(err_close, nil)
          end
          return callback(nil, data)
        end)
      end)
    end)
  end)
end

local function string_split(str, seps)
  local sep = seps[1]
  for _,s in ipairs(seps) do
    if string.find(str, s, 1, true) ~= nil then
      sep = s
    end
  end
  local ptr = 1
  local result = {}
  while true do
    local b, e = string.find(str, sep, ptr, true)
    if b == nil then
      table.insert(result, string.sub(str, ptr))
      return result
    else
      table.insert(result, string.sub(str, ptr, b - 1))
      ptr = e + 1
    end
  end
end

local function string_split_with_loc(str, seps)
  local sep = seps[1]
  for _,s in ipairs(seps) do
    if string.find(str, s, 1, true) ~= nil then
      sep = s
    end
  end
  local ptr = 1
  local result = {}
  local loc = {}
  while true do
    local b, e = string.find(str, sep, ptr, true)
    if b == nil then
      table.insert(result, string.sub(str, ptr))
      table.insert(loc, ptr)
      return result, loc
    else
      table.insert(result, string.sub(str, ptr, b - 1))
      table.insert(loc, ptr)
      ptr = e + 1
    end
  end
end

return {
  async_walk = async_walk,
  async_read = async_read,
  string_split = string_split,
  string_split_with_loc = string_split_with_loc
}
