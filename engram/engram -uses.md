## Recommended Workflow for You

Given your work style (multiple Azure infrastructure projects), use **git-synced project-specific memories**:

### Day 1: Service Bus Project

bash

```bash
cd C:\Projects\service-bus-migration
code .  # Opens VS Code

# Work with Claude Code...
# At end of day:
engram sync --project service-bus-migration
git add .engram/ && git commit -m "engram: phase 1 complete"
```

### Day 2: PostgreSQL Project

bash

```bash
cd C:\Projects\postgresql-setup
code .  # Opens VS Code

# Work with Claude Code...
# Engram loads ONLY PostgreSQL memories (if .engram/ exists)
# OR starts fresh if no .engram/ folder yet

# At end of day:
engram sync --project postgresql-setup
git add .engram/ && git commit -m "engram: initial setup"
```

### Day 3: Back to Service Bus

bash

```bash
cd C:\Projects\service-bus-migration
code .  # Opens VS Code

# Claude Code auto-imports .engram/ memories
# Full context of Service Bus work restored
# PostgreSQL memories NOT loaded
```