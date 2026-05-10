# project1

## Quick Start

1. **Read CLAUDE.md first** - Contains essential rules for Claude Code
2. Follow the pre-task compliance checklist before starting any work
3. Use proper module structure under `src/main/python/`
4. Commit after every completed task

## Project Structure

```
project1/
├── CLAUDE.md              # Essential rules for Claude Code
├── README.md              # This file
├── .gitignore
├── src/
│   ├── main/
│   │   ├── python/        # Main Python source code
│   │   │   ├── core/      # Core business logic
│   │   │   ├── utils/     # Utility functions
│   │   │   ├── models/    # Data models
│   │   │   ├── services/  # Service layer
│   │   │   └── api/       # API endpoints
│   │   └── resources/
│   │       ├── config/    # Configuration files
│   │       └── assets/    # Static assets
│   └── test/
│       ├── unit/          # Unit tests
│       └── integration/   # Integration tests
├── docs/                  # Documentation
├── tools/                 # Dev tools and scripts
├── examples/              # Usage examples
└── output/                # Generated output files
```

## Development Guidelines

- **Always search first** before creating new files
- **Extend existing** functionality rather than duplicating
- **Use Task agents** for operations >30 seconds
- **Single source of truth** for all functionality
