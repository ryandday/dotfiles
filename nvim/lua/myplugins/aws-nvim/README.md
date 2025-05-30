# AWS-Nvim

AWS resource visualization and management for Neovim.

## Overview

AWS-Nvim is a Neovim plugin that provides an interactive tree view of your AWS resources. It focuses on CloudFormation stacks and their associated ECS resources, allowing you to navigate from stacks to services, tasks, and containers with an expandable tree interface.

Key features:
- Expandable tree view for AWS resources (Stack → Service → Task → Container)
- Lazy loading of resources only when expanded
- Caching to minimize AWS API calls
- Quick access to logs, console URLs, and SSH commands
- Resource management actions

## Requirements

- Neovim 0.5.0+
- AWS CLI v2 installed and configured
- Appropriate AWS permissions for resource access

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'ryday/aws-nvim',
  requires = {'nvim-lua/plenary.nvim'},
  config = function()
    require('aws-nvim').setup({
      -- Optional configuration
      region = 'us-east-1',
      profile = 'default'
    })
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'ryday/aws-nvim',
  dependencies = {'nvim-lua/plenary.nvim'},
  config = function()
    require('aws-nvim').setup({
      -- Optional configuration
      region = 'us-east-1',
      profile = 'default'
    })
  end
}
```

## Usage

### Commands

- `:AWSNvimOpen` - Open the AWS resource explorer
- `:AWSNvimStack <stack-name>` - Open and expand a specific stack
- `:AWSNvimRefresh` - Refresh the current view
- `:AWSNvimFilter <pattern>` - Apply a filter to the resource tree
- `:AWSNvimProfile <profile>` - Switch AWS profile
- `:AWSNvimRegion <region>` - Switch AWS region

### Key Bindings

When in the AWS-Nvim buffer:

- `<CR>` - Expand/collapse node
- `o` - Open details in split window
- `r` - Refresh node and children
- `f` - Filter tree
- `a` - Show actions menu
- `l` - View logs (for container resources)
- `c` - Copy resource identifier or console URL
- `q` - Close the AWS-Nvim window

## Configuration

Configure AWS-Nvim with the `setup` function:

```lua
require('aws-nvim').setup({
  -- AWS settings
  region = 'us-east-1',     -- Default AWS region
  profile = 'default',      -- AWS profile to use
  
  -- Cache settings
  cache_ttl = {
    stack = 600,            -- 10 minutes
    service = 300,          -- 5 minutes
    task = 120,             -- 2 minutes
    container = 60          -- 1 minute
  },
  
  -- UI settings
  split_direction = 'right' -- Where to open the tree window ('left', 'right')
})
```

## Resource Actions

Different resource types support different actions:

### Stack
- View stack events
- View resources
- Update stack
- Delete stack

### Service
- Update service
- Scale service
- Restart service

### Task
- Stop task
- View task definition

### Container
- View logs
- SSH into container
- Restart container

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
