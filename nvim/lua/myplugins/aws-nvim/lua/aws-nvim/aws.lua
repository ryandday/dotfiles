-- aws.lua - AWS CLI interactions module
local M = {}

-- Run AWS CLI command and return the result
-- @param cmd The AWS CLI command to run
-- @param region The AWS region
-- @param profile The AWS profile (optional)
-- @param callback Function to call with results
function M.run_aws_command(cmd, region, profile, callback)
  -- Build the full command with region and profile
  local full_cmd = "aws " .. cmd .. " --region " .. region
  
  -- Add profile if provided
  if profile and profile ~= "" then
    full_cmd = full_cmd .. " --profile " .. profile
  end
  
  -- Add output format as JSON
  full_cmd = full_cmd .. " --output json"
  
  -- Create and run the job
  local stdout_data = ""
  local stderr_data = ""
  
  local job_id = vim.fn.jobstart(full_cmd, {
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            stdout_data = stdout_data .. line .. "\n"
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            stderr_data = stderr_data .. line .. "\n"
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      if exit_code == 0 and stdout_data ~= "" then
        -- Try to parse JSON output
        local success, result = pcall(vim.json.decode, stdout_data)
        if success then
          callback(nil, result)
        else
          callback("Failed to parse JSON: " .. stdout_data, nil)
        end
      else
        callback("AWS CLI error: " .. stderr_data, nil)
      end
    end,
    stdout_buffered = true,
    stderr_buffered = true
  })
  
  -- Check if job started successfully
  if job_id <= 0 then
    callback("Failed to start AWS CLI job", nil)
  end
  
  return job_id
end

-- List CloudFormation stacks
function M.list_stacks(region, profile, callback)
  local cmd = "cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE"
  
  M.run_aws_command(cmd, region, profile, function(err, result)
    if err then
      callback(err, nil)
      return
    end
    
    -- Process the stack data into our tree format
    local stacks = {}
    
    if result and result.StackSummaries then
      for _, stack in ipairs(result.StackSummaries) do
        table.insert(stacks, {
          id = stack.StackId,
          name = stack.StackName,
          type = 'stack',
          status = stack.StackStatus,
          expanded = false,
          children = {},
          has_children = true
        })
      end
    end
    
    callback(nil, stacks)
  end)
end

-- List ECS services for a stack
function M.list_stack_services(stack_id, stack_name, region, profile, callback)
  -- First get ECS services from the stack resources
  local cmd = "cloudformation list-stack-resources --stack-name " .. stack_name .. 
              " --query \"StackResourceSummaries[?ResourceType==`AWS::ECS::Service`].[LogicalResourceId,PhysicalResourceId]\""
  
  M.run_aws_command(cmd, region, profile, function(err, result)
    if err then
      callback(err, nil)
      return
    end
    
    -- Process services
    local services = {}
    
    if result then
      for _, service_data in ipairs(result) do
        local logical_id = service_data[1]
        local physical_id = service_data[2]
        
        -- Extract cluster name and service name from ARN
        local cluster_name = string.match(physical_id, "service/([^/]*)/")
        local service_name = string.match(physical_id, "/([^/]*)$")
        
        if cluster_name and service_name then
          table.insert(services, {
            id = physical_id,
            name = service_name,
            logical_id = logical_id,
            type = 'service',
            cluster = cluster_name,
            status = 'ACTIVE', -- We'll get actual status in the next step
            expanded = false,
            children = {},
            has_children = true,
            parent_stack = stack_id
          })
        end
      end
    end
    
    -- Now get the status for each service
    if #services > 0 then
      local pending = #services
      local service_errors = {}
      
      for i, service in ipairs(services) do
        local service_cmd = "ecs describe-services --cluster " .. service.cluster .. 
                          " --services " .. service.name
        
        M.run_aws_command(service_cmd, region, profile, function(service_err, service_result)
          pending = pending - 1
          
          if service_err then
            table.insert(service_errors, service_err)
          elseif service_result and service_result.services and #service_result.services > 0 then
            local service_details = service_result.services[1]
            services[i].status = service_details.status
            
            -- Add desiredCount and runningCount if available
            if service_details.desiredCount ~= nil then
              services[i].desired_count = service_details.desiredCount
              services[i].running_count = service_details.runningCount or 0
            end
          end
          
          -- When all services are processed, return the result
          if pending == 0 then
            if #service_errors > 0 then
              callback("Errors retrieving service details: " .. table.concat(service_errors, ", "), services)
            else
              callback(nil, services)
            end
          end
        end)
      end
    else
      callback(nil, services)
    end
  end)
end

-- List ECS tasks for a service
function M.list_service_tasks(service_id, cluster_name, service_name, region, profile, callback)
  local cmd = "ecs list-tasks --cluster " .. cluster_name .. 
              " --service-name " .. service_name
  
  M.run_aws_command(cmd, region, profile, function(err, result)
    if err then
      callback(err, nil)
      return
    end
    
    -- Process tasks
    local tasks = {}
    
    if result and result.taskArns and #result.taskArns > 0 then
      -- We have task ARNs, now describe them to get details
      local task_arns = table.concat(result.taskArns, " ")
      local describe_cmd = "ecs describe-tasks --cluster " .. cluster_name .. 
                          " --tasks " .. task_arns
      
      M.run_aws_command(describe_cmd, region, profile, function(describe_err, describe_result)
        if describe_err then
          callback(describe_err, nil)
          return
        end
        
        if describe_result and describe_result.tasks then
          for _, task in ipairs(describe_result.tasks) do
            local task_id = string.match(task.taskArn, "/([^/]*)$")
            
            table.insert(tasks, {
              id = task_id,
              name = task_id,
              type = 'task',
              status = task.lastStatus,
              health = task.healthStatus or "UNKNOWN",
              expanded = false,
              children = {},
              has_children = true,
              parent_service = service_id,
              task_definition = task.taskDefinitionArn,
              cluster = cluster_name
            })
          end
        end
        
        callback(nil, tasks)
      end)
    else
      callback(nil, tasks)
    end
  end)
end

-- List containers for a task
function M.list_task_containers(task_id, cluster_name, region, profile, callback)
  local cmd = "ecs describe-tasks --cluster " .. cluster_name .. 
              " --tasks " .. task_id
  
  M.run_aws_command(cmd, region, profile, function(err, result)
    if err then
      callback(err, nil)
      return
    end
    
    -- Process containers
    local containers = {}
    
    if result and result.tasks and #result.tasks > 0 then
      local task = result.tasks[1]
      
      -- Get task definition to get the log configuration
      local task_def_arn = task.taskDefinitionArn
      local describe_taskdef_cmd = "ecs describe-task-definition --task-definition " .. task_def_arn
      
      M.run_aws_command(describe_taskdef_cmd, region, profile, function(taskdef_err, taskdef_result)
        if taskdef_err then
          callback(taskdef_err, nil)
          return
        end
        
        local task_def = taskdef_result.taskDefinition
        local container_defs = {}
        
        -- Build a map of container name to log configuration
        if task_def and task_def.containerDefinitions then
          for _, container_def in ipairs(task_def.containerDefinitions) do
            container_defs[container_def.name] = {
              image = container_def.image,
              log_group = container_def.logConfiguration and 
                          container_def.logConfiguration.options and 
                          container_def.logConfiguration.options["awslogs-group"],
              log_prefix = container_def.logConfiguration and 
                          container_def.logConfiguration.options and 
                          container_def.logConfiguration.options["awslogs-stream-prefix"]
            }
          end
        end
        
        -- Process each container
        for _, container in ipairs(task.containers) do
          local container_name = container.name
          local container_def = container_defs[container_name] or {}
          
          -- Construct log path
          local log_path = ""
          if container_def.log_group and container_def.log_prefix then
            log_path = container_def.log_group .. "/" .. container_def.log_prefix .. "/" .. container_name .. "/" .. task_id
          end
          
          table.insert(containers, {
            id = container.containerArn,
            name = container_name,
            type = 'container',
            image = container_def.image or container.image,
            status = container.lastStatus,
            health = container.healthStatus or "UNKNOWN",
            logs = log_path,
            expanded = false,
            children = {},
            has_children = false,
            runtime_id = container.runtimeId,
            task_id = task_id,
            cluster = cluster_name
          })
        end
        
        callback(nil, containers)
      end)
    else
      callback(nil, containers)
    end
  end)
end

-- Get AWS SSM command for container
function M.get_container_ssh_command(container_id, task_id, cluster_name, region, profile, callback)
  -- First get the container instance ARN
  local cmd = "ecs describe-tasks --cluster " .. cluster_name .. 
              " --tasks " .. task_id
  
  M.run_aws_command(cmd, region, profile, function(err, result)
    if err then
      callback(err, nil)
      return
    end
    
    if result and result.tasks and #result.tasks > 0 then
      local task = result.tasks[1]
      local container_instance_arn = task.containerInstanceArn
      
      if container_instance_arn then
        -- Get the EC2 instance ID
        local instance_cmd = "ecs describe-container-instances --cluster " .. cluster_name .. 
                            " --container-instances " .. container_instance_arn
        
        M.run_aws_command(instance_cmd, region, profile, function(instance_err, instance_result)
          if instance_err then
            callback(instance_err, nil)
            return
          end
          
          if instance_result and instance_result.containerInstances and #instance_result.containerInstances > 0 then
            local ec2_instance_id = instance_result.containerInstances[1].ec2InstanceId
            
            -- Now we can build the SSM command
            local runtime_id = string.match(container_id, "/([^/]*)$")
            local command = "aws ssm start-session --region " .. region
            
            if profile and profile ~= "" then
              command = command .. " --profile " .. profile
            end
            
            command = command .. " --target " .. ec2_instance_id .. 
                     " --document-name AWS-StartInteractiveCommand " ..
                     "--parameters '{\"command\":[\"docker exec -it " .. runtime_id .. " /bin/bash || docker exec -it " .. runtime_id .. " /bin/sh\"]}'"
            
            callback(nil, command)
          else
            callback("Container instance not found", nil)
          end
        end)
      else
        callback("No container instance for task", nil)
      end
    else
      callback("Task not found", nil)
    end
  end)
end

return M 