#Requires -Modules Az.Accounts

<#
.SYNOPSIS
    Re-enables all AMBA suppression alert processing rules across all Ravago subscriptions.

.DESCRIPTION
    Iterates through all defined subscriptions, constructs the expected alert processing
    rule name following the pattern: apr-AMBA-<subscriptionName>-S001
    and enables it via the Azure REST API.
    If the rule does not exist, it logs a warning and continues.

.NOTES
    Resource Group : rg-amba-monitoring-001
    Rule pattern   : apr-AMBA-<subscriptionName>-S001
    API Version    : 2021-08-08

.EXAMPLE
    .\Enable-AMBAAlertProcessingRules.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-HttpStatusCodeFromError {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $exception = $ErrorRecord.Exception
    if ($null -eq $exception) {
        return $null
    }

    if ($exception.PSObject.Properties.Name -contains "Response" -and $null -ne $exception.Response) {
        $response = $exception.Response
        if ($response.PSObject.Properties.Name -contains "StatusCode" -and $null -ne $response.StatusCode) {
            try { return [int]$response.StatusCode } catch {}
        }
    }

    if ($exception.PSObject.Properties.Name -contains "StatusCode" -and $null -ne $exception.StatusCode) {
        try { return [int]$exception.StatusCode } catch {}
    }

    return $null
}

# ─────────────────────────────────────────────────────────────────────────────
# SUBSCRIPTION LIST  (Name → ID)
# ─────────────────────────────────────────────────────────────────────────────
$subscriptions = [ordered]@{
    # ── Platform ──────────────────────────────────────────────────────────────
    "sub-rav-hub-amer"              = "8cb1079f-1d18-43ed-8828-e6bd2742207f"
    "sub-rav-hub-emea"              = "81ddf31e-f784-4413-8548-4f72da738c75"
    "sub-rav-hub-neur"              = "003bddfb-5da1-4120-ac08-4e750a0cbbc2"
    "sub-rav-prd-amer-identity"     = "6798a165-adcf-49f9-922e-d33c12e8406b"
    "sub-rav-prd-emea-identity"     = "3d5f11bf-6efa-4175-9ea5-53235bda8b17"
    "sub-rav-prd-neur-identity"     = "b55109c3-3387-4902-a4a7-a67689c5cd85"
    "sub-rav-prd-amer-management"   = "3ac4b569-e6c4-487e-977d-9fce4d7c8af2"
    "sub-rav-prd-emea-management"   = "4d0fe1ba-ebd7-4da3-93b2-7302d48ce299"
    "sub-rav-prd-neur-management"   = "4fbab1be-5cfe-4beb-80e3-daf7cdc271c6"
    "sub-rav-prd-emea-security"     = "f35a7274-f9ac-41bc-9b1b-4bb44da5a3c5"
    # ── Landing Zones ─────────────────────────────────────────────────────────
    "sub-rav-prd-amer-skytap"           = "094d691a-f888-4ca0-a2bd-f671b13c0bfe"
    "sub-rav-dev-emea-ai-training"      = "0e5e2e0d-08af-44ec-85de-de14944bb7d6"
    "sub-rav-emea-vidara"               = "164e5fc4-d472-452f-8144-07bc10831e01"
    "sub-rav-amer-vidara-brasil"        = "20d0afa6-ba20-4cbf-8c0d-30dab35b3d2d"
    "sub-rav-amer-mholland-migration"   = "26f8444d-d7d8-421c-a2f3-b201e7afe663"
    "sub-rav-dev-emea-erponboarding"    = "2b265e7a-0129-4e41-a760-1d8138c93062"
    "sub-rav-prd-emea"                  = "36c3a717-e6b5-4dfb-881e-c03791f0c0cd"
    "sub-rav-sbx-emea-sdc"             = "3b54bdd3-71a2-4eb6-a1d6-867ed056d6e5"
    "sub-rav-acc-emea"                  = "4af5cbf1-6340-40b9-a721-1eba5d501088"
    "sub-rav-prd-emea-devops"           = "4bbe8957-4279-4295-9ad7-fd56fb45dcfa"
    "sub-rav-prd-amer-avd"              = "51dfcf4f-11a8-4690-951e-df8681b34472"
    "sub-rav-acc-emea-digitalplatform"  = "51ff89ed-91c3-4727-8fa0-5884f8378b85"
    "sub-rav-prd-emea-digitalplatform"  = "533071ca-097b-4b11-a8ce-d202e2d124d9"
    "sub-rav-prd-emea-kimteks"          = "5d6f9f03-2f4c-4159-bae3-091ff4108ba8"
    "sub-rav-prd-emea-fabric"           = "5ebdcb85-54e5-4227-abd0-f5596baad1e7"
    "sub-rav-prd-emea-sapehs"           = "64fe1d1f-6ecf-415c-b0fa-54ad8c7192f5"
    "sub-rav-dev-emea"                  = "6a54f491-9bf7-4182-8eb4-bd417ab237a3"
    "sub-rav-acc-emea-powerautomate"    = "6ade164e-832f-4692-99f6-956d29825ce4"
    "sub-rav-acc-amer"                  = "6dfd7db9-5fe6-4396-b092-121889134694"
    "sub-rav-prd-emea-dwh"             = "6f2db8a1-067a-412f-8717-328521798bb9"
    "sub-rav-prd-emea-sdc"             = "6fcb7488-ceef-471c-ad6c-c12dabebb216"
    "sub-rav-dev-amer"                  = "754b668a-4977-4901-81fd-b2d9997834a5"
    "sub-rav-dev-neur-acr"             = "873ea2ab-bbae-44e5-80af-04cb24da96a4"
    "sub-rav-ssc-emea"                  = "88b5da24-f013-4e08-8c93-80abc72c807d"
    "sub-rav-dre-emea-confluent"        = "88faf024-2735-4357-9f7d-9aa27754a684"
    "sub-rav-dev-neur-sdc"             = "8d241adc-feff-4207-affc-3992176b353c"
    "sub-rav-dev-emea-sdc"             = "8e299c88-fef2-4853-9d1c-6183a693faf5"
    "sub-rav-dev-emea-powerplatform"    = "92729e7a-be84-4802-8d81-167043b905c9"
    "sub-rav-acc-emea-sdc"             = "96cdc87b-dfc8-4641-9f86-366838bc5c21"
    "sub-rav-amer-mholland"            = "9e41d69a-0748-4067-ae4f-1057eb40b8d5"
    "sub-rav-tst-emea-digitalplatform"  = "a10c2174-2abd-4c85-a3d1-c44ab123f149"
    "sub-rav-prd-emea-avd"             = "ac5532df-7d45-4e8f-871b-c69372459d8c"
    "sub-rav-acc-emea-confluent"        = "ac75c0e0-ee3e-435c-8de3-230b07aa4bb5"
    "sub-rav-prd-amer"                  = "c5f183c9-ef69-4f62-ab3b-e0ca2b92eba1"
    "sub-rav-prd-emea-ambra"            = "c76af829-5a61-42cb-8d01-3755239e2600"
    "sub-rav-ssc-amer"                  = "cbb63d88-2a8c-4e8e-99cb-11478806f5b9"
    "sub-rav-prd-emea-proxium"          = "cdc710e3-9ec5-4d2c-b2e4-9773f9676b76"
    "sub-rav-prd-emea-saas"            = "d3feafd8-2ebf-4517-ad34-1322db5042bc"
    "sub-rav-dev-emea-digitalplatform"  = "e9e62342-f8a0-430e-9713-65b69ec501ce"
    "sub-rav-prd-emea-confluent"        = "eb322d82-59f8-49b1-8138-4b426a7d890d"
    "sub-rav-prd-emea-powerautomate"    = "ec562337-e444-44a7-bf1a-e825678b454b"
    "sub-rav-acc-emea-sapehs"           = "ed2f47f3-ddd7-4244-82a7-5bde291fbc4d"
    "sub-rav-dev-emea-sapehs"           = "f3d1ebe1-a75a-4946-913a-db52a55898c6"
    "sub-rav-acc-emea-kimteks"          = "fe63f7cc-7025-45a1-bc7d-fb79e4ad6e6e"
}

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
$resourceGroup = "rg-amba-monitoring-001"
$apiVersion    = "2021-08-08"
$targetState   = $true   # true = Enabled

# ─────────────────────────────────────────────────────────────────────────────
# CONNECT (skip if already authenticated in the session)
# ─────────────────────────────────────────────────────────────────────────────
$context = Get-AzContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Host "No active Azure session found. Connecting..." -ForegroundColor Yellow
    Connect-AzAccount
}

# ─────────────────────────────────────────────────────────────────────────────
# COUNTERS
# ─────────────────────────────────────────────────────────────────────────────
$enabled  = 0
$notFound = 0
$failed   = 0
$total    = $subscriptions.Count

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ENABLING AMBA Alert Processing Rules — $total subscriptions" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

foreach ($subName in $subscriptions.Keys) {
    $subId    = $subscriptions[$subName]
    $ruleName = "apr-AMBA-$subName-S001"
    $uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$resourceGroup" +
           "/providers/Microsoft.AlertsManagement/actionRules/$ruleName" +
           "?api-version=$apiVersion"

    Write-Host "[$subName]" -ForegroundColor White -NoNewline
    Write-Host " → $ruleName" -ForegroundColor Gray

    try {
        # ── 1. Check if the rule exists (GET) ────────────────────────────────
        try {
            $getResponse = Invoke-AzRestMethod -Method GET -Uri $uri -ErrorAction Stop
        }
        catch {
            $statusCode = Get-HttpStatusCodeFromError -ErrorRecord $_

            if ($statusCode -eq 404) {
                Write-Host "     ⚠  Rule not found — skipping." -ForegroundColor Yellow
                $notFound++
                continue
            }

            throw
        }

        if ($getResponse.StatusCode -notin 200..299) {
            Write-Warning "     ✗  Unexpected GET status $($getResponse.StatusCode) — skipping."
            $failed++
            continue
        }

        # ── 2. Parse current state ────────────────────────────────────────────
        $ruleObj = $getResponse.Content | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $ruleObj.properties -or $ruleObj.properties.PSObject.Properties.Name -notcontains "enabled") {
            Write-Warning "     ✗  Rule payload does not contain properties.enabled — skipping."
            $failed++
            continue
        }

        $currentState = [bool]$ruleObj.properties.enabled

        if ($currentState -eq $targetState) {
            Write-Host "     ℹ  Already enabled — no action needed." -ForegroundColor DarkGray
            $enabled++
            continue
        }

        # ── 3. PATCH to enable ────────────────────────────────────────────────
        $body = @{ properties = @{ enabled = $targetState } } | ConvertTo-Json -Depth 3

        $patchResponse = Invoke-AzRestMethod -Method PATCH -Uri $uri `
                            -Payload $body -ErrorAction Stop

        if ($patchResponse.StatusCode -in 200..299) {
            Write-Host "     ✔  Successfully ENABLED." -ForegroundColor Green
            $enabled++
        } else {
            Write-Warning "     ✗  PATCH failed with status $($patchResponse.StatusCode)."
            Write-Warning "        Response: $($patchResponse.Content)"
            $failed++
        }
    }
    catch {
        Write-Warning "     ✗  Exception: $_"
        $failed++
    }

    Write-Host ""
}

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Total subscriptions : $total"
Write-Host "  Enabled (or already enabled) : $enabled" -ForegroundColor Green
Write-Host "  Not found (skipped)          : $notFound"  -ForegroundColor Yellow
Write-Host "  Errors                       : $failed"    -ForegroundColor Red
Write-Host ""
