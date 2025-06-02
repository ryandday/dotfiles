-- CodeCompanion notification integration using vim.notify
-- Inspired by: https://github.com/olimorris/codecompanion.nvim/discussions/813#discussioncomment-12031954

local M = {}

function M:init()
  local group = vim.api.nvim_create_augroup("CodeCompanionNotifyHooks", { clear = true })

  -- Keep track of active requests for better UX
  local active_requests = {}

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestStarted",
    group = group,
    callback = function(request)
      local client_name = M:get_client_name(request)
      local key = request.data.bufnr or "default"
      active_requests[key] = true
      
      vim.notify("🤖 " .. client_name .. " • Requesting assistance...", vim.log.levels.INFO, {
        title = "CodeCompanion",
        timeout = false, -- Keep it visible until finished
      })
    end,
  })

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestFinished",
    group = group,
    callback = function(request)
      local client_name = M:get_client_name(request)
      local key = request.data.bufnr or "default"
      active_requests[key] = nil
      
      local status_message = M:get_status_message(request, "Completed")
      vim.notify("✅ " .. client_name .. " • " .. status_message, vim.log.levels.INFO, {
        title = "CodeCompanion",
        timeout = 3000,
      })
    end,
  })

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestError",
    group = group,
    callback = function(request)
      local client_name = M:get_client_name(request)
      local key = request.data.bufnr or "default"
      active_requests[key] = nil
      
      vim.notify("❌ " .. client_name .. " • Error occurred", vim.log.levels.ERROR, {
        title = "CodeCompanion",
        timeout = 5000,
      })
    end,
  })

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestCancelled",
    group = group,
    callback = function(request)
      local client_name = M:get_client_name(request)
      local key = request.data.bufnr or "default"
      active_requests[key] = nil
      
      vim.notify("🚫 " .. client_name .. " • Request cancelled", vim.log.levels.WARN, {
        title = "CodeCompanion",
        timeout = 3000,
      })
    end,
  })
end

function M:get_client_name(request)
  -- Get chat information if available
  local chat = nil
  if request.data.bufnr then
    local ok, codecompanion = pcall(require, "codecompanion")
    if ok then
      chat = codecompanion.buf_get_chat(request.data.bufnr)
    end
  end

  if chat and chat.adapter then
    return M:llm_role_title(chat.adapter)
  end
  
  return "CodeCompanion"
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

function M:get_status_message(request, default_message)
  if request.data and request.data.status == "success" then
    return "Completed"
  elseif request.data and request.data.status == "error" then
    return "Error"
  else
    return default_message
  end
end

return M 