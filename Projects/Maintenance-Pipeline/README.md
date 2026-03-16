# Maintenance Pipeline Project

**Status:** Active
**Tags:** #project/maintenance-pipeline #azure #devops

## Scripts

### Alert Processing Rules Management

**File:** `Disable-AMBAAlertProcessingRules.ps1`
**Purpose:** Disable Azure Monitor Baseline Alerts during maintenance window
**Usage:**
```powershell
.\Disable-AMBAAlertProcessingRules.ps1 -ResourceGroup "rg-rav-prd-emea"
```

**File:** `Enable-AMBAAlertProcessingRules.ps1`
**Purpose:** Re-enable alerts after maintenance
**Usage:**
```powershell
.\Enable-AMBAAlertProcessingRules.ps1 -ResourceGroup "rg-rav-prd-emea"
```

**File:** `Invoke-MaintenanceAlertControl.ps1`
**Purpose:** Master script to orchestrate maintenance window
**Usage:**
```powershell
.\Invoke-MaintenanceAlertControl.ps1 -Action Start
```

## Pipeline Configuration

**File:** `maintenance-pipeline.yaml`
**Purpose:** Azure DevOps pipeline definition
**Triggers:** Manual, scheduled (weekly)

## Related Knowledge

- [[azure/devops/pipelines]]
- [[azure/monitor/alert-processing-rules]]
- [[decisions/2026-03-15-maintenance-schedule-controller-design-decisions]]

## Sessions

- [[sessions/2026-03-15-maintenance-pipeline-project-structure-and-purpose]]
```

---

## Estructura Ideal: Código + Documentación
```
Projects/Maintenance-Pipeline/
├── README.md                                    ← Nota en Obsidian
├── architecture.md                              ← Nota en Obsidian
├── implementation-notes.md                      ← Nota en Obsidian
├── Disable-AMBAAlertProcessingRules.ps1         ← Código (editas en VS Code)
├── Enable-AMBAAlertProcessingRules.ps1          ← Código (editas en VS Code)
├── Invoke-MaintenanceAlertControl.ps1           ← Código (editas en VS Code)
├── maintenance-pipeline.yaml                    ← Config (editas en VS Code)
├── .claude/                                     ← Config (oculta)
└── .engram/                                     ← Memories (oculta)