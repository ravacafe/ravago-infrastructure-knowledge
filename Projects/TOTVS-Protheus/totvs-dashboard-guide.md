# TOTVS Protheus Service Monitoring — Dashboard Guide

**Version:** 8 | **Grafana:** 11.6.9 | **Region:** AMER · Brazil

---

## What is this dashboard?

This dashboard monitors the health of **TOTVS Protheus** Windows services running on production virtual machines in the AMER region. It connects to **Azure Log Analytics** and tracks whether each service is running or stopped — in real time and historically.

> **In plain terms:** Every time a TOTVS service starts or stops on a server, Windows logs an event. This dashboard reads those events and turns them into visual indicators so you can instantly know if something is wrong.

---

## Monitored Infrastructure

| Component | Details |
|---|---|
| **ERP System** | TOTVS Protheus |
| **Servers** | 7 production VMs: `vmamervtot002p` through `vmamervtot008p` |
| **Log Source** | Windows Event ID **7036** (Service Control Manager — service state changes) |
| **Service Filter** | Any Windows service whose display name contains **`.TOTVS`** |
| **Data Store** | Azure Log Analytics workspace `law-rav-prd-emea-mgmt` |

---

## Dashboard Controls (Variables)

At the top of the dashboard you will find three dropdown filters:

| Filter | Purpose |
|---|---|
| **Datasource** | Selects the Azure Monitor data source |
| **Log Analytics Workspace** | The workspace where all logs are stored |
| **Virtual Machines** | Multi-select: filter to one or more specific VMs (defaults to ALL) |

> Use the **Virtual Machines** filter to focus on a single server when troubleshooting. The time range picker (top-right) controls what time window the event-based panels display.

---

## Dashboard Layout

The dashboard is divided into **two main sections**:

```
┌─────────────────────────────────────────────────────────┐
│                    HEADER BANNER                        │
├──────────┬──────────┬──────────┬──────────┤
│ Total    │ Running  │ Stopped  │  Active  │  ← KPI STATS
│ Services │ Services │ Services │  Servers │
├─────────────────────────────────────────────────────────┤
│              Service Status by Server (table)           │
├─────────────────────────────────────────────────────────┤
│                  Service State Timeline                  │
├─────────────────────────────────────────────────────────┤
│            Service State Change Events Over Time        │
├─────────────────────────────────────────────────────────┤
│                   Recent Service Events                 │
├─────────────────────────────────────────────────────────┤
│         ── Heartbeat-Confirmed Service Status ──        │
├──────────┬──────────┬──────────┬──────────┤
│  Stable  │   VMs    │  VM HB   │ Critical │  ← HB STATS
│ Running  │  Online  │  Status  │   Down   │
├─────────────────────────────────────────────────────────┤
│    Heartbeat-Confirmed Running Services (table)         │
└─────────────────────────────────────────────────────────┘
```

---

## Section 1 — Event-Based Monitoring

> These panels read Windows event logs. They reflect **what happened** during the selected time range (and in some cases the last 90 days).

---

### KPI Stats Row

Four summary numbers shown at a glance:

#### Total Services Monitored
- Shows how many **distinct TOTVS services** have ever been seen across all monitored VMs in the last 90 days.
- Always reflects the full service inventory, regardless of the selected time window.

#### Running Services
- How many services have **"running" as their last known state** (90-day lookback).
- Uses the most recent state change event per service/server pair.

#### Stopped Services
- How many services have **"stopped" as their last known state** (90-day lookback).
- Displayed in **red** when greater than zero — this deserves attention.

#### Active Servers
- How many of the monitored VMs sent a **heartbeat in the last hour**.
- Powered by the Azure Monitor Heartbeat table, not event logs.

> **Note:** Running + Stopped should roughly equal Total Services. If Stopped > 0, cross-check with the **Critical: Services Down on Online VMs** stat in Section 2 to determine if it's a real incident.

---

### Service Status by Server (Table)

A detailed table showing the **current status of every TOTVS service** on every server.

| Column | Description |
|---|---|
| **Service** | Display name of the Windows service |
| **Server** | VM where the service runs (short name) |
| **Status** | `✓ RUNNING` (green) or `✗ STOPPED` (red) |
| **Last Update** | Timestamp of the last state change event |

**How it works:** For each service+server combination, it takes the most recent event within the selected time window and shows its state.

> **Important:** If a service has been running without interruption and no events occurred in the selected window, it will not appear here. This is normal — it means the service is stable. Use the **Heartbeat-Confirmed** section below for a complete inventory.

---

### Service State Timeline

A visual timeline where each **row = one service on one server** and each **color block = its state** at that point in time.

- **Green block** = Service was running
- **Red block** = Service was stopped
- Consecutive identical states are merged into a single block for clarity

**Best used for: Incident investigation — instantly see *when* a service went down and *when* it recovered.**

The query outputs exactly **3 columns** and each plays a different role in the visualization:

```kql
| extend ServiceServer = strcat(ServiceDisplayName, " @ ", ComputerShort)
| project TimeGenerated, ServiceServer, Status
```

---

### ServiceServer — the row identity (WHO)

`ServiceServer` is a **combined label** built by concatenating the service name and the server:

```
.TOTVS PRD | DBAccess Primary | 9202 @ vmamervtot005p
```

In the state-timeline panel, **each unique `ServiceServer` value becomes one horizontal row**. It answers: _which service on which machine are we looking at?_

---

### How they work together

Grafana's state-timeline takes the three columns and builds the visual like this:

```
TimeGenerated  →  X axis (time)
ServiceServer  →  Y axis (one row per unique value)
Status         →  color of each block on that row
```

Concrete example — given these 3 events:

|TimeGenerated|ServiceServer|Status|
|---|---|---|
|08:00|DBAccess @ vmamervtot005p|running|
|10:00|DBAccess @ vmamervtot005p|stopped|
|10:30|DBAccess @ vmamervtot005p|running|

Grafana renders the row for `DBAccess @ vmamervtot005p` like this:

```
08:00     10:00  10:30
  |          |      |
  [  GREEN   ][ RED ][  GREEN ...
```

Each block **stretches from one event's timestamp until the next event** for that same `ServiceServer`. The color is set by `Status` at the start of that block.

---

### Why combine service + server into one field?

Because the same service can run on multiple VMs (e.g., `DBAccess Secundario` runs on 5 different servers). Without `@ vmamervtot005p` in the label, all 5 would merge into a single row and the timeline would be meaningless. The `strcat` ensures each service-server pair gets its **own independent row**.

### Service State Change Events Over Time (Time Series)

A line chart showing **how many start and stop events occurred** per time interval across all monitored services.

| Line | Meaning |
|---|---|
| **StartEvents** | Number of services that started in that interval |
| **StopEvents** | Number of services that stopped in that interval |

The time interval adapts automatically to your selected time range (e.g., 5-minute buckets for a 1-hour window, 1-hour buckets for a 24-hour window).

> **Important:** This chart counts *transitions*, not the total number of running services. A quiet period with flat lines at zero simply means no services changed state — that is a healthy sign.

**Best used for:** Spotting mass restart events, scheduled maintenance windows, or cascading failures.

---

### Recent Service Events (Table)

A raw event log showing the **last 50 service state changes** in the selected time window, sorted newest first.

| Column | Description |
|---|---|
| **Time** | When the event occurred |
| **Server** | Which VM |
| **Service** | Which service |
| **Status** | `RUNNING` (green) or `STOPPED` (red) |

**Best used for:** Real-time operations — seeing exactly what just happened and in what order.

---

## Section 2 — Heartbeat-Confirmed Monitoring

> These panels combine **service event history (90 days)** with **live VM heartbeats (last hour)**. They give you the most reliable picture of current infrastructure health, independent of the time range picker.

---

### Why this section exists

The event-based panels only show services that *changed state* recently. A service running perfectly for weeks generates no events. This section solves that by asking: *"What was the last known state of every service, and is that VM actually online right now?"*

---

### Heartbeat KPI Stats Row

Four summary stats working together:

#### Stable Running Services
- Services confirmed **running** (last known state in 90 days) **AND** whose VM sent a heartbeat in the last hour.
- The most trustworthy "everything is OK" count.

#### VMs Online Now
- VMs that sent a heartbeat in the last hour.
- Color coded: **green** = all 7 online, **yellow** = partial, **red** = none.

#### VM Heartbeat Status (Table)
- Per-VM breakdown of last heartbeat timestamp.
- `✓ Online` = heartbeat received in last hour.
- `⚠ Stale` = heartbeat not received in last hour (VM may be down or unreachable).

#### Critical: Services Down on Online VMs
- The most important alert stat on the dashboard.
- Counts services whose last known state is **"stopped"** AND whose VM is **actively heartbeating**.
- This means: *the VM is up but the service is not running* — a genuine incident.
- **Green = 0** (all good), **Red ≥ 1** (action required).

---

### Heartbeat-Confirmed Running Services (Table)

The most complete and reliable service inventory on the dashboard.

| Column | Description |
|---|---|
| **Service** | TOTVS service display name |
| **Server** | VM short name |
| **Running Since** | Timestamp of the last "running" event (within 90 days) |
| **Last Heartbeat** | When the VM last reported its heartbeat |
| **VM Online** | `✓ Online` or `✗ Offline` |

**How it works:**
1. Finds every service whose last known state is "running" (90-day lookback)
2. Joins with the heartbeat table to check if the VM is alive
3. Shows `✗ Offline` if the VM hasn't heartbeated in the last hour — meaning we can't confirm the service is actually up

> This table will always show `licenseVirtual` and all other stable services, even if they haven't restarted in months. It is the ground truth for service inventory.

---

## How the Two Sections Work Together

| Scenario | Event Section | Heartbeat Section |
|---|---|---|
| Service running stably for weeks | May not appear (no recent events) | ✓ Shows as running + online |
| Service just restarted | ✓ Appears in timeline and events table | ✓ Shows as running + online |
| Service stopped, VM online | ✓ Shows as STOPPED | **Critical stat turns red** |
| VM is offline | Events stop appearing | VM Heartbeat shows Stale/Offline |
| Mass restart event | Spike visible in time series chart | Stable Running count temporarily drops |

---

## How to Use This Dashboard — Quick Reference

| I want to... | Look at... |
|---|---|
| See the overall health at a glance | KPI stats row (top) |
| Check if a specific service is running | Service Status by Server table |
| Find out when a service went down | Service State Timeline |
| Investigate a past incident | Set time range to incident window → Timeline + Recent Events |
| Get a complete list of all services | Heartbeat-Confirmed Running Services table |
| Know if a VM is reachable | VM Heartbeat Status table |
| Know if there's a real incident right now | **Critical: Services Down on Online VMs** stat |
| Check if `licenseVirtual` is running | Heartbeat-Confirmed Running Services table |

---

## Refresh & Retention

| Setting | Value |
|---|---|
| Auto-refresh | Every **5 minutes** |
| Default time window | Last **3 hours** |
| KPI stats lookback | **90 days** |
| Heartbeat check window | Last **1 hour** |
| VM staleness threshold | Heartbeat older than **1 hour** = Stale |

---

## Glossary

| Term | Meaning |
|---|---|
| **EventID 7036** | Windows system event fired every time a service starts or stops |
| **Service Control Manager** | The Windows component that manages services and generates 7036 events |
| **Heartbeat** | A periodic signal sent by the Azure Monitor agent on each VM to confirm it is alive |
| **arg_max** | KQL function that picks the most recent record — used to find the *last known state* of each service |
| **90d lookback** | The dashboard looks back 90 days to find the last known state, so stable services are never missed |
| **`$vm` variable** | The multi-select VM filter — all queries are scoped to only the selected VMs |
