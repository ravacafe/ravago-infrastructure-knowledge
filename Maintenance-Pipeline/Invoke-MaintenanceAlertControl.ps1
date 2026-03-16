#Requires -Modules Az.Accounts

<#
.SYNOPSIS
    Automatically controls AMBA Alert Processing Rules based on the maintenance schedule.

.DESCRIPTION
    Designed to run every 30 minutes via Azure DevOps scheduled pipeline.
    Disables all AMBA alert processing rules 30 minutes before a maintenance window starts.
    Re-enables them 30 minutes after a maintenance window ends.

    Times in the schedule are local time for the specified region:
        EUS  = Eastern US   (Eastern Standard Time,  UTC-5 / UTC-4 DST)
        WEU  = West Europe  (W. Europe Standard Time, UTC+1 / UTC+2 DST)
        NZL  = New Zealand  (New Zealand Standard Time, UTC+12 / UTC+13 DST)

.PARAMETER LeadMinutes
    How many minutes before the window start to disable alerts. Default: 30.

.PARAMETER TrailMinutes
    How many minutes after the window end to re-enable alerts. Default: 30.

.PARAMETER ToleranceWindow
    How far back (in minutes) to look for a missed trigger. Default: 35.
    Covers slight pipeline delays without double-firing between 30-min runs.

.NOTES
    Schedule entry '03-WED-0000-3000-EUS' had an invalid end time '3000'.
    It has been interpreted as 06:00. Please verify this is correct.

.EXAMPLE
    .\Invoke-MaintenanceAlertControl.ps1
    .\Invoke-MaintenanceAlertControl.ps1 -LeadMinutes 30 -TrailMinutes 30
#>

[CmdletBinding()]
param(
    [int]$LeadMinutes     = 30,
    [int]$TrailMinutes    = 30,
    [int]$ToleranceWindow = 35
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# ─────────────────────────────────────────────────────────────────────────────
# TIMEZONE MAP
# ─────────────────────────────────────────────────────────────────────────────
$TzMap = @{
    EUS = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
    WEU = [System.TimeZoneInfo]::FindSystemTimeZoneById("W. Europe Standard Time")
    NZL = [System.TimeZoneInfo]::FindSystemTimeZoneById("New Zealand Standard Time")
}

# ─────────────────────────────────────────────────────────────────────────────
# MAINTENANCE SCHEDULE
# ─────────────────────────────────────────────────────────────────────────────
# Week       : Nth occurrence of the weekday in the month (1 = first, 4 = fourth)
# Day        : Day of week (Monday … Sunday)
# StartH/M   : Window start in local time of Region
# EndH/M     : Window end in local time of Region
#              End < Start means the window crosses midnight into the next day.
# Warn       : Optional runtime warning for entries that required manual interpretation.
$Schedule = @(
    # ── Week 1 ────────────────────────────────────────────────────────────────
    @{ Name="01-SAT-0000-0600-EUS";     Week=1; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="01-SAT-0000-0600-WEU";     Week=1; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="01-SUN-2100-0000-WEU";     Week=1; Day="Sunday";    StartH=21; StartM=0; EndH=0;  EndM=0; Region="WEU" }
    @{ Name="01-TUE-0000-0600-WEU";     Week=1; Day="Tuesday";   StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="01-TUE-2200-0400-EUS";     Week=1; Day="Tuesday";   StartH=22; StartM=0; EndH=4;  EndM=0; Region="EUS" }
    @{ Name="01-TUE-2200-0400-WEU";     Week=1; Day="Tuesday";   StartH=22; StartM=0; EndH=4;  EndM=0; Region="WEU" }
    @{ Name="01-TUE-2200-0600-SQL-EUS"; Week=1; Day="Tuesday";   StartH=22; StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="01-WED-0000-0600-EUS";     Week=1; Day="Wednesday"; StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }

    # ── Week 2 ────────────────────────────────────────────────────────────────
    @{ Name="02-SAT-0000-0600-EUS";     Week=2; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="02-SAT-0000-0600-WEU";     Week=2; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="02-TUE-0000-0300-EUS";     Week=2; Day="Tuesday";   StartH=0;  StartM=0; EndH=3;  EndM=0; Region="EUS" }
    @{ Name="02-TUE-0000-0600-EUS";     Week=2; Day="Tuesday";   StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="02-TUE-0000-0600-WEU";     Week=2; Day="Tuesday";   StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="02-TUE-2200-0400-WEU";     Week=2; Day="Tuesday";   StartH=22; StartM=0; EndH=4;  EndM=0; Region="WEU" }
    @{ Name="02-TUE-NR-0000-0600-WEU";  Week=2; Day="Tuesday";   StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="02-WED-1900-2200-WEU";     Week=2; Day="Wednesday"; StartH=19; StartM=0; EndH=22; EndM=0; Region="WEU" }

    # ── Week 3 ────────────────────────────────────────────────────────────────
    @{ Name="03-SAT-0000-0300-EUS";     Week=3; Day="Saturday";  StartH=0;  StartM=0; EndH=3;  EndM=0; Region="EUS" }
    @{ Name="03-SAT-0000-0600-EUS";     Week=3; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="03-SAT-0000-0600-WEU";     Week=3; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="03-SAT-0200-0600-WEU";     Week=3; Day="Saturday";  StartH=2;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="03-TUE-0000-0300-EUS";     Week=3; Day="Tuesday";   StartH=0;  StartM=0; EndH=3;  EndM=0; Region="EUS" }
    @{ Name="03-TUE-0000-0600-EUS";     Week=3; Day="Tuesday";   StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="03-TUE-0000-0600-SQL-EUS"; Week=3; Day="Tuesday";   StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="03-TUE-0000-0600-WEU";     Week=3; Day="Tuesday";   StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="03-WED-0000-0600-EUS";     Week=3; Day="Wednesday"; StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS"; Warn="Original end time was '3000' (invalid) — interpreted as 06:00. Please verify." }

    # ── Week 4 ────────────────────────────────────────────────────────────────
    @{ Name="04-SAT-0000-0600-EUS";     Week=4; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="04-SAT-0000-0600-SQL-EUS"; Week=4; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="EUS" }
    @{ Name="04-SAT-0000-0600-WEU";     Week=4; Day="Saturday";  StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="04-SAT-0500-0700-EUS";     Week=4; Day="Saturday";  StartH=5;  StartM=0; EndH=7;  EndM=0; Region="EUS" }
    @{ Name="04-SAT-0500-0700-WEU";     Week=4; Day="Saturday";  StartH=5;  StartM=0; EndH=7;  EndM=0; Region="WEU" }
    @{ Name="04-SAT-2100-0000-NZL";     Week=4; Day="Saturday";  StartH=21; StartM=0; EndH=0;  EndM=0; Region="NZL" }
    @{ Name="04-SAT-2100-0000-WEU";     Week=4; Day="Saturday";  StartH=21; StartM=0; EndH=0;  EndM=0; Region="WEU" }
    @{ Name="04-SAT-2200-0100-EUS";     Week=4; Day="Saturday";  StartH=22; StartM=0; EndH=1;  EndM=0; Region="EUS" }
    @{ Name="04-SAT-2200-0400-EUS";     Week=4; Day="Saturday";  StartH=22; StartM=0; EndH=4;  EndM=0; Region="EUS" }
    @{ Name="04-SAT-2200-0400-WEU";     Week=4; Day="Saturday";  StartH=22; StartM=0; EndH=4;  EndM=0; Region="WEU" }
    @{ Name="04-SUN-0000-0300-WEU";     Week=4; Day="Sunday";    StartH=0;  StartM=0; EndH=3;  EndM=0; Region="WEU" }
    @{ Name="04-SUN-0300-0600-WEU";     Week=4; Day="Sunday";    StartH=3;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
    @{ Name="04-SUN-NR-0000-0600-WEU";  Week=4; Day="Sunday";    StartH=0;  StartM=0; EndH=6;  EndM=0; Region="WEU" }
)

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

function Get-NthWeekdayOfMonth {
    <#
    .SYNOPSIS Returns the date of the Nth occurrence of a weekday in a given month.
    Returns $null if N exceeds the number of that weekday in the month.
    #>
    param([int]$Year, [int]$Month, [string]$Weekday, [int]$N)

    $target = [System.DayOfWeek]$Weekday
    $first  = [DateTime]::new($Year, $Month, 1)
    $offset = (([int]$target - [int]$first.DayOfWeek) + 7) % 7
    $date   = $first.AddDays($offset + ($N - 1) * 7)

    if ($date.Month -ne $Month) { return $null }
    return $date
}

function Get-WindowUtcRange {
    <#
    .SYNOPSIS Converts a schedule entry into UTC disable/enable trigger times.
    Returns $null if the Nth weekday does not exist in the given month.
    #>
    param([hashtable]$Win, [int]$Year, [int]$Month, [int]$LeadMins, [int]$TrailMins)

    $tz   = $TzMap[$Win.Region]
    $date = Get-NthWeekdayOfMonth -Year $Year -Month $Month -Weekday $Win.Day -N $Win.Week
    if ($null -eq $date) { return $null }

    $localStart = [DateTime]::new($date.Year, $date.Month, $date.Day, $Win.StartH, $Win.StartM, 0)

    # Determine if the window crosses midnight into the next calendar day.
    # It does when the end time (in minutes) is less than the start time,
    # or when the end is exactly 00:00 and the start is not.
    $startMins       = $Win.StartH * 60 + $Win.StartM
    $endMins         = $Win.EndH   * 60 + $Win.EndM
    $crossesMidnight = ($endMins -lt $startMins) -or
                       ($Win.EndH -eq 0 -and $Win.EndM -eq 0 -and $Win.StartH -ne 0)

    $endDate  = if ($crossesMidnight) { $date.AddDays(1) } else { $date }
    $localEnd = [DateTime]::new($endDate.Year, $endDate.Month, $endDate.Day, $Win.EndH, $Win.EndM, 0)

    $utcStart = [System.TimeZoneInfo]::ConvertTimeToUtc($localStart, $tz)
    $utcEnd   = [System.TimeZoneInfo]::ConvertTimeToUtc($localEnd,   $tz)

    return @{
        Name      = $Win.Name
        UtcStart  = $utcStart
        UtcEnd    = $utcEnd
        DisableAt = $utcStart.AddMinutes(-$LeadMins)
        EnableAt  = $utcEnd.AddMinutes($TrailMins)
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
$now         = [DateTime]::UtcNow
$lookBackEnd = $now.AddMinutes($ToleranceWindow * -1)   # how far back to catch a trigger
$lookAhead   = $now.AddMinutes(5)                       # small forward buffer for early runs

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  MAINTENANCE ALERT CONTROL  —  $($now.ToString('yyyy-MM-dd HH:mm:ss')) UTC" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Trigger window : $($lookBackEnd.ToString('HH:mm')) – $($lookAhead.ToString('HH:mm')) UTC" -ForegroundColor DarkGray
Write-Host ""

$disableTriggers = [System.Collections.Generic.List[string]]::new()
$enableTriggers  = [System.Collections.Generic.List[string]]::new()

# Check current month and adjacent months to catch windows near month boundaries.
foreach ($monthOffset in @(-1, 0, 1)) {
    $ref = $now.AddMonths($monthOffset)

    foreach ($win in $Schedule) {
        if ($win.ContainsKey("Warn")) {
            Write-Warning "[$($win.Name)] $($win.Warn)"
        }

        $range = Get-WindowUtcRange -Win $win -Year $ref.Year -Month $ref.Month `
                                    -LeadMins $LeadMinutes -TrailMins $TrailMinutes
        if ($null -eq $range) { continue }

        if ($range.DisableAt -ge $lookBackEnd -and $range.DisableAt -le $lookAhead) {
            Write-Host "  DISABLE  [$($range.Name)]" -ForegroundColor Yellow -NoNewline
            Write-Host "  — trigger $($range.DisableAt.ToString('yyyy-MM-dd HH:mm')) UTC  |  window $($range.UtcStart.ToString('HH:mm'))–$($range.UtcEnd.ToString('HH:mm')) UTC"
            $disableTriggers.Add($range.Name)
        }

        if ($range.EnableAt -ge $lookBackEnd -and $range.EnableAt -le $lookAhead) {
            Write-Host "  ENABLE   [$($range.Name)]" -ForegroundColor Green -NoNewline
            Write-Host "  — trigger $($range.EnableAt.ToString('yyyy-MM-dd HH:mm')) UTC  |  window $($range.UtcStart.ToString('HH:mm'))–$($range.UtcEnd.ToString('HH:mm')) UTC"
            $enableTriggers.Add($range.Name)
        }
    }
}

Write-Host ""

if ($disableTriggers.Count -eq 0 -and $enableTriggers.Count -eq 0) {
    Write-Host "  No maintenance triggers in the current window. No action needed." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# Disable takes priority over enable — when both fire simultaneously a maintenance
# window is starting, so alerts must remain suppressed.
if ($disableTriggers.Count -gt 0) {
    Write-Host "  ACTION: DISABLING alerts — $($disableTriggers.Count) window trigger(s) matched." -ForegroundColor Yellow
    Write-Host ""
    & "$ScriptDir\Disable-AMBAAlertProcessingRules.ps1"

    if ($enableTriggers.Count -gt 0) {
        Write-Host ""
        Write-Host "  NOTE: $($enableTriggers.Count) ENABLE trigger(s) were suppressed because a DISABLE trigger took priority." -ForegroundColor DarkYellow
    }
}
elseif ($enableTriggers.Count -gt 0) {
    Write-Host "  ACTION: ENABLING alerts — $($enableTriggers.Count) window trigger(s) matched." -ForegroundColor Green
    Write-Host ""
    & "$ScriptDir\Enable-AMBAAlertProcessingRules.ps1"
}

Write-Host ""
