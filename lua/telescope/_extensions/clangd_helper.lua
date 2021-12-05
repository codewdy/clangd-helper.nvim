local telescope = require "telescope"
local pickers = require "telescope.pickers"
local conf = require("telescope.config").values
local finders = require "telescope.finders"
local entry_display = require "telescope.pickers.entry_display"
local sorters = require "telescope.sorters"
local channel = require("plenary.async.control").channel
local fzy = require("telescope.algos.fzy")

local utils = require("clangd-helper/utils")

local function concat_namespace(ns, v)
  if ns == "" then
    return v
  else
    return ns .. "::" .. v
  end
end

local function get_workspace_symbols_requester(bufnr, opts)
  local cancel = function() end

  return function(prompt)
    local tx, rx = channel.oneshot()
    cancel()
    queries = utils.string_split(prompt, opts.sep)
    for i=#queries,2,-1 do
      if queries[i] == "" then
        queries[i] = nil
      else
        break
      end
    end
    _, cancel = vim.lsp.buf_request(bufnr, "workspace/symbol", { query = queries[#queries] }, tx)

    -- Handle 0.5 / 0.5.1 handler situation
    local err, res_1, res_2 = rx()
    local results_lsp
    if type(res_1) == "table" then
      results_lsp = res_1
    else
      results_lsp = res_2
    end
    assert(not err, err)

    return results_lsp
  end
end

local function gen_from_lsp_symbols(opts)
  opts = opts or {}

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local display_items = {
    { remaining = true }
  }

  local displayer = entry_display.create {
    separator = " ",
    hl_chars = { ["["] = "TelescopeBorder", ["]"] = "TelescopeBorder" },
    items = display_items,
  }

  local make_display = function(entry)
    local display_columns = {
      -- entry.containerName .. "::" .. entry.name,
      entry.text,
    }

    return displayer(display_columns)
  end

  return function(entry)
    return {
      valid = true,

      value = concat_namespace(entry.containerName, entry.name),
      kind = tostring(entry.kind),
      ordinal = concat_namespace(entry.containerName, entry.name),
      display = make_display,

      node_text = concat_namespace(entry.containerName, entry.name),

      filename = string.sub(entry.location.uri, 8),
      lnum = entry.location.range.start.line + 1,
      col = entry.location.range.start.character,
      text = concat_namespace(entry.containerName, entry.name),
      start = entry.location.range.start.line,
      finish = entry.location.range.start.line,
    }
  end
end

local function sort(sep, prompt, line)
  local split_prompt = utils.string_split(prompt, sep)
  local split_line = utils.string_split(line, sep)
  for i=#split_prompt,2,-1 do
    if split_prompt[i] == "" then
      split_prompt[i] = nil
    else
      break
    end
  end
  if #split_prompt > #split_line then
    return -1
  end
  for i=0,#split_prompt -1 do
    if not fzy.has_match(split_prompt[#split_prompt - i], split_line[#split_line - i]) then
      return -1
    end
  end
  local total_score = 0
  for i=0,#split_prompt -1 do
    local fzy_score = fzy.score(split_prompt[#split_prompt - i], split_line[#split_line - i])
    total_score = total_score * 2 + 1 / (fzy_score + fzy.get_score_floor() + 1)
  end
  return total_score
end

local function highlighter(sep, prompt, line)
  local t = string.match(line, "%s+")
  if t == nil then
    return {}
  end
  local _, pos = string.find(line, t)
  pos = pos + 1
  local split_prompt = utils.string_split(prompt, sep)
  local split_line, loc = utils.string_split_with_loc(string.sub(line, pos), sep)
  for i=#split_prompt,2,-1 do
    if split_prompt[i] == "" then
      split_prompt[i] = nil
    else
      break
    end
  end
  local ret = {}
  for i=#split_prompt-1,0,-1 do
    local position = fzy.positions(split_prompt[#split_prompt - i], split_line[#split_line - i])
    for _,j in ipairs(position) do
      table.insert(ret, pos + loc[#split_line - i] + j - 2)
    end
  end
  return ret
end

local function clangd_symbol(opts)
  local curr_bufnr = vim.api.nvim_get_current_buf()
  
  opts.sep = opts.sep or {"::", "."}

  pickers.new(opts, {
    prompt_title = "Clangd Workspace Symbols",
    finder = finders.new_dynamic {
      entry_maker = opts.entry_maker or gen_from_lsp_symbols(opts),
      fn = get_workspace_symbols_requester(curr_bufnr, opts),
    },
    previewer = conf.grep_previewer(opts),
    sorter = sorters.new{
      scoring_function = function(_, prompt, line)
        return sort(opts.sep, prompt, line)
      end,
      highlighter = function(_, prompt, line)
        return highlighter(opts.sep, prompt, line)
      end,
    },
  }):find()
end

return telescope.register_extension {
  setup = function(ext_config)
  end,
  exports = {
    clangd_helper = clangd_symbol,
  },
}
