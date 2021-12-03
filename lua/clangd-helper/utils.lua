local function async_walk(dir, callback)
  local function onread(err, data)
    if err then
      return callback(err, nil)
    end
    if data then
      local results = {}
      local vals = vim.split(data, "\n")
      for _, d in pairs(vals) do
        if d ~= "" then
          table.insert(results, d)
        end
      end
      callback(nil, results)
    end
  end

  local stdout = vim.loop.new_pipe(false)
  handle = vim.loop.spawn('rg', {
      args = {'--type', 'cpp', '--files', dir},
      stdio = {nil, stdout, nil}
    },
    vim.schedule_wrap(function()
      stdout:read_stop()
      stdout:close()
      handle:close()
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

return {
  async_walk = async_walk,
  async_read = async_read
}
