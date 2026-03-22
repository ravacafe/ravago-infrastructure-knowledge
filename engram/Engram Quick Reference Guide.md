## Essential Commands

### **Search Memories**

bash

```bash
engram search "service bus"
```

**What it does:** Full-text search across all saved memories  
**When to use:** Looking for past decisions, configurations, or work

---

### **Browse Everything (Interactive)**

bash

```bash
engram tui
```

**What it does:** Opens visual terminal interface to browse all memories, sessions, timeline  
**Navigation:** `j/k` = scroll, `/` = search, `Enter` = details, `q` = quit  
**When to use:** Exploring what's stored, not sure what you're looking for

---

### **View Statistics**

bash

```bash
engram stats
```

**What it does:** Shows total observations, sessions, database size  
**When to use:** Check if memories are being saved

---

### **Export Project Memories**

bash

```bash
engram sync --project project-name
```

**What it does:** Creates `.engram/` folder with compressed memory chunks for THIS project only  
**When to use:** End of work session, before committing to git

---

### **Check Project Sync Status**

bash

```bash
engram sync --status
```

**What it does:** Shows what's new since last sync  
**When to use:** See if there are unsaved memories to export

---

## Workflow: Starting a NEW Project

bash

```bash
# 1. Create your project folder
cd C:\Projects\new-project

# 2. Open in VS Code
code .

# 3. Start working with Claude Code
# (Claude Code will use Engram automatically via MCP)

# 4. At end of session, ask Claude:
"Save a session summary to memory"

# 5. Export project-specific memories:
engram sync --project new-project

# 6. Commit to git (optional, for team sharing):
git add .engram/
git commit -m "engram: initial session"
```

**Key point:** Just work normally. Save memories when you finish significant work.

---

## Workflow: RESUMING an Existing Project

bash

```bash
# 1. Open the project
cd C:\Projects\service-bus-migration
code .

# 2. Claude Code auto-loads memories if .engram/ exists
# (No manual action needed!)

# 3. Ask Claude to recall context:
"What did we do in the last session?"
# OR
"Continue the Service Bus migration"

# Claude will automatically search memory and resume
```

**Key point:** If `.engram/` folder exists in the project, Claude Code loads it automatically when you open the project.

---

## Workflow: DONE with a Project (Archive/Cleanup)

### Option 1: Keep Memories, Remove from Active Work

bash

```bash
# Export final state
cd C:\Projects\completed-project
engram sync --project completed-project

# Commit one last time
git add .engram/
git commit -m "engram: project complete"

# Archive the repo
# (Memories stay in git history, can be restored anytime)
```

### Option 2: Clean Up Local Database (Keep Git Export)

bash

```bash
# The .engram/ folder in git has your memories
# The global ~/.engram/engram.db can be cleaned

# View what's in global DB:
engram tui

# No built-in delete command yet, but memories in .engram/ 
# folder are safe and can be re-imported anytime
```