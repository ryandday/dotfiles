-- fidget.nvim integration for CodeCompanion
-- Lifted from: https://github.com/olimorris/codecompanion.nvim/discussions/813#discussioncomment-12031954

local progress = require("fidget.progress")

local M = {}

function M:init()
  local group = vim.api.nvim_create_augroup("CodeCompanionFidgetHooks", { clear = true })

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestStarted",
    group = group,
    callback = function(request)
      local handle = M:create_progress_handle(request)
      M:store_progress_handle(request.data.bufnr or "default", handle)
    end,
  })

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestFinished",
    group = group,
    callback = function(request)
      local handle = M:pop_progress_handle(request.data.bufnr or "default")
      if handle then
        M:report_exit_status(handle, request)
        handle:finish()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestError",
    group = group,
    callback = function(request)
      local handle = M:pop_progress_handle(request.data.bufnr or "default")
      if handle then
        handle.message = " Error"
        handle:finish()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestCancelled",
    group = group,
    callback = function(request)
      local handle = M:pop_progress_handle(request.data.bufnr or "default")
      if handle then
        handle.message = "󰜺 Cancelled"
        handle:finish()
      end
    end,
  })
end

M.handles = {}

function M:store_progress_handle(id, handle)
  M.handles[id] = handle
end

function M:pop_progress_handle(id)
  local handle = M.handles[id]
  M.handles[id] = nil
  return handle
end

function M:create_progress_handle(request)
  -- Get chat information if available
  local chat = nil
  if request.data.bufnr then
    local ok, codecompanion = pcall(require, "codecompanion")
    if ok then
      chat = codecompanion.buf_get_chat(request.data.bufnr)
    end
  end

  local title = " Requesting assistance"
  local client_name = "CodeCompanion"
  
  if chat then
    if chat.adapter then
      client_name = M:llm_role_title(chat.adapter)
    end
  end

  return progress.handle.create({
    title = title,
    message = "In progress...",
    lsp_client = {
      name = client_name,
    },
  })
end

function M:llm_role_title(adapter)
  local parts = {}
  
  -- Add formatted name if available
  if adapter.formatted_name then
    table.insert(parts, adapter.formatted_name)
  end
  
  -- Add model information
  local model = nil
  if adapter.schema and adapter.schema.model and adapter.schema.model.default then
    model = adapter.schema.model.default
  elseif adapter.model then
    model = adapter.model
  end
  
  if model and model ~= "" then
    table.insert(parts, "(" .. model .. ")")
  end
  
  return #parts > 0 and table.concat(parts, " ") or "CodeCompanion"
end

function M:report_exit_status(handle, request)
  if request.data and request.data.status == "success" then
    handle.message = " Completed"
  elseif request.data and request.data.status == "error" then
    handle.message = " Error"
  else
    handle.message = " Finished"
  end
end

return M 