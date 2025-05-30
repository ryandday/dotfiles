# AWS-Nvim: AWS Stack Resource Visualization

## Overview
AWS-Nvim is a Neovim plugin for visualizing and interacting with AWS resources, starting with CloudFormation stack resources. The plugin will provide an expandable tree view of AWS resources, lazy-loading each level only when expanded by the user, and caching results to minimize API calls.

## Core Features

### 1. Tree Visualization
- Display AWS resources in an expandable tree structure
- Hierarchy: Stack -> Service -> Task -> Container
- Tree nodes should be expandable/collapsible with keyboard shortcuts
- Visual indicators for expandable nodes and status (running, stopped, etc.)
- Support for filtering resources at each level

### 2. Lazy Loading & Caching
- Only load child resources when a node is expanded
- Cache results to minimize AWS API calls
- Configurable cache duration for different resource types
- Manual refresh option to force reload data
- Background loading with status indicators

### 3. Resource Details
- Show detailed information for selected resources
- Quick access to CloudWatch logs for containers
- Links to AWS console (can be copied to clipboard)
- Show health status, deployment status, and other metrics

### 4. Actions
- Execute commands on resources (e.g., SSM session to container)
- View logs in a split window
- Restart services/tasks
- Update task definitions
- Scale services

### 5. Navigation
- Keyboard shortcuts for tree navigation
- Search/filter functionality
- Jump to related resources
- Bookmarking frequently accessed resources

## Implementation Plan

### Phase 1: Core Framework & Basic Visualization
1. Create plugin structure and initialization in Lua
2. Implement AWS authentication and profile selection
3. Develop tree view UI component using Neovim's UI capabilities
4. Implement basic stack listing functionality
5. Add stack expansion to show services

### Phase 2: Complete Resource Hierarchy & Lazy Loading
1. Implement service expansion to show tasks
2. Implement task expansion to show containers
3. Add lazy loading mechanism using Lua coroutines
4. Implement caching system with JSON storage
5. Add status indicators and basic filtering

### Phase 3: Advanced Features
1. Add detailed views for each resource type
2. Implement log viewing capabilities using built-in terminal
3. Add command execution features (SSM, etc.)
4. Implement resource management actions
5. Add search and advanced filtering

### Phase 4: Polish & Extensions
1. Add configuration options with setup function
2. Optimize performance for large resource sets
3. Add additional AWS resource types
4. Improve documentation and help system
5. Create color schemes and visual enhancements

## Technical Design

### Directory Structure
```
aws-nvim/
├── lua/
│   └── aws-nvim/
│       ├── init.lua          # Main module
│       ├── config.lua        # Configuration
│       ├── aws.lua           # AWS API interaction
│       ├── cache.lua         # Caching system
│       ├── ui.lua            # UI components
│       ├── tree.lua          # Tree management
│       └── actions.lua       # Resource actions
├── plugin/
│   └── aws-nvim.lua          # Plugin registration
├── doc/
│   └── aws-nvim.txt          # Documentation
└── README.md
```

### Data Model
- Tree nodes will contain:
  - Resource identifier (ARN or ID)
  - Resource type
  - Display name
  - Status
  - Metadata (region, timestamps, etc.)
  - Children (lazy-loaded)
  - Actions available

### Caching Strategy
- In-memory cache during Neovim session
- Optional persistent cache in JSON files
- Hierarchical caching (can refresh subtrees)
- TTL-based expiration per resource type
- Resource-specific invalidation rules

### AWS Interaction
- Leverage AWS CLI credentials via Lua's process spawning
- Support for multiple profiles and regions
- Rate limiting to avoid API throttling
- Error handling and retry logic
- Background loading with Neovim's job API

## User Experience

### Key Bindings
- `<CR>`: Expand/collapse node
- `o`: Open details in split window
- `r`: Refresh node and children
- `f`: Filter tree
- `a`: Show actions menu
- `l`: View logs (for container resources)
- `c`: Copy resource identifier or console URL
- `q`: Close the AWS explorer

### Commands
- `:AWSNvimOpen`: Open the main AWS-Nvim window
- `:AWSNvimStack <stack-name>`: Open directly to a specific stack
- `:AWSNvimRefresh`: Refresh the current view
- `:AWSNvimFilter <pattern>`: Apply filter to the tree
- `:AWSNvimProfile <profile>`: Switch AWS profile
- `:AWSNvimRegion <region>`: Switch AWS region

## Next Steps
1. Create minimal viable implementation of the tree UI in Lua
2. Implement AWS CLI interaction via Lua's process API
3. Convert existing bash function logic to Lua
4. Test with small AWS environments
5. Implement caching and lazy loading
6. Add detailed resource views
7. Implement actions 