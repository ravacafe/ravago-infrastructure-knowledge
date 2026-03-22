## Ways to Search/View Engram Memories

There are **4 main ways** to access your stored memories:

---

## 1. CLI Search (Quick Text Search)

bash

```bash
engram search "service bus"
```

**Returns:** Text results directly in terminal

**Examples:**

bash

```bash
engram search "palo alto"
engram search "database migration"
engram search "terraform"
engram search "EKRON-BRILL"
```

---

## 2. TUI - Terminal UI (Visual Browser)

bash

````bash
engram tui
```

**Best way to browse!** Opens an interactive terminal interface with:
- Dashboard view
- Search functionality (press `/` to search)
- Browse all observations
- View sessions
- Timeline view
- Full navigation with vim keys (`j/k` to scroll, `Enter` to drill in)

**Navigation:**
- `j/k` - Move up/down
- `Enter` - Open detail view
- `/` - Search
- `t` - Timeline view
- `Esc` - Go back
- `q` - Quit

---

## 3. Ask Claude in Claude Code (Most Natural)

Just ask me directly:
```
You: "Search memory for Service Bus migration"
You: "What do you remember about the EKRON-BRILL integration?"
You: "Show me memories from last week"
````