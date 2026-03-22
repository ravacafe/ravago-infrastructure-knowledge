---

## name: ravago-azure-infrastructure description: "Comprehensive knowledge base for Ravago's Azure infrastructure. Use when working on Azure tasks, infrastructure questions, networking troubleshooting, or cloud architecture for Ravago. Contains detailed information about hub-and-spoke topology, IP addressing, naming standards, governance model, security architecture, and operational patterns."

# Ravago Azure Infrastructure Knowledge Base

## Executive Overview

Ravago operates a hub-and-spoke landing zone in Azure with regional hubs (EMEA in West Europe, AMER in East US 2) providing shared networking and security services to multiple spoke VNets segregated by environment (Production, Acceptance, Development, Shared Services). Traffic routing is centralized through Palo Alto NVA appliances with Cato SD-WAN integration. Active Directory domain controllers run in Azure providing DNS services, with Azure Private DNS for internal resolution and private endpoint connectivity.

**Delivery Model**: Infrastructure deployments executed by Arxus using Terraform, with IT Infrastructure team owning RBAC and governance.

---

## 1. REGIONS & LANDING ZONE ARCHITECTURE

### Active Regions

- **West Europe (EMEA)**: Primary region, 10.8.0.0/16 and 10.9.0.0/16 address space
- **East US 2 (AMER)**: Secondary region, 10.19.0.0/16 address space
- **Overall IP Plan**: Corporate RFC1918 on 10.0.0.0/8, segmented by region, tracked in IPAM

### Landing Zone Pattern

Standard hub-and-spoke architecture:

- **Hub VNet**: Centralized connectivity and security services
- **Spoke VNets**: Per-environment segregation (PRD/ACC/DEV/SSC)
- **Peering**: Spokes peered to hub with "Allow forwarded traffic" and "Use remote gateways" enabled
- **Inspection**: All east-west and north-south traffic routed through Palo Alto NVA

---

## 2. GOVERNANCE MODEL

### Management Groups Hierarchy

```
mg-it (root)
├── mg-ssc-amer
│   ├── mg-amer-prd
│   └── mg-amer-non-prd
├── mg-ssc-apac
│   ├── mg-apac-prd
│   └── mg-apac-non-prd
└── mg-ssc-emea
    ├── mg-emea-prd
    └── mg-emea-non-prd
```

### Azure Subscriptions (EMEA)

|Subscription|Management Group|Purpose|
|---|---|---|
|sub-rav-hub-emea|mg-emea-prd|Hub connectivity and shared services|
|sub-rav-prd-emea|mg-emea-prd|Production workloads|
|sub-rav-acc-emea|mg-emea-prd|Acceptance/UAT environment|
|sub-rav-dev-emea|mg-emea-non-prd|Development environment|
|sub-rav-ssc-emea|mg-emea-prd|Shared services and platform tooling|

### Azure Tenant

- **Tenant Name**: Ravago.onmicrosoft.com
- **Custom Domains**: Ravago.com

---

## 3. NETWORK TOPOLOGY (EMEA)

### Core VNets & Address Ranges

|VNet Name|Address Space|Purpose|Resource Group|Subscription|
|---|---|---|---|---|
|vnet-rav-hub-emea|10.8.0.0/19|Regional hub with shared connectivity & security|rg-rav-hub-emea-network|sub-rav-hub-emea|
|vnet-rav-prd-emea|10.8.32.0/19|Production spoke|rg-rav-prd-emea-network|sub-rav-prd-emea|
|vnet-rav-ssc-emea|10.8.64.0/19|Shared Services spoke|rg-rav-ssc-emea-network|sub-rav-ssc-emea|
|vnet-rav-acc-emea|10.8.96.0/19|Acceptance spoke|rg-rav-acc-emea-network|sub-rav-acc-emea|
|vnet-rav-dev-emea|10.8.128.0/19|Development spoke|rg-rav-dev-emea-network|sub-rav-dev-emea|

### Key Hub Subnets

|Subnet Name|Address Range|Purpose|
|---|---|---|
|GatewaySubnet|10.8.31.0/24|VPN/ExpressRoute gateway|
|AzureBastionSubnet|10.8.30.0/27|Azure Bastion service|
|vnet-rav-hub-emea-snet-mgmt-01|10.8.0.0/27|Management subnet|
|vnet-rav-hub-emea-snet-arx-01|10.8.29.0/27|Arxus management subnet|

### SSC Subnets

|Subnet Name|Address Range|Purpose|
|---|---|---|
|AzureBastionSubnet|10.8.95.0/27|SSC Bastion service|
|vnet-rav-ssc-emea-snet-mgmt-01|10.8.64.0/24|SSC management subnet|

### VNet Peering Configuration

All spoke VNets peer to hub with:

- **Allow forwarded traffic**: Enabled
- **Use remote gateways**: Enabled (where applicable)
- **Allow gateway transit**: Configured on hub VNet

---

## 4. ROUTING & SECURITY ARCHITECTURE

### Palo Alto NVA Integration

- **Function**: Central firewall appliance for traffic inspection
- **Deployment**: Hosted in hub VNet
- **Management**: Panorama-managed
- **Traffic Flow**: Route tables steer spoke-to-spoke, spoke-to-internet, and spoke-to-on-premises through Palo Alto

### Route Tables (Examples)

- **rt-vnet-rav-hub-emea-snet-priv-01**: Routes traffic to Palo Alto NVA
- **rt-vnet-rav-hub-emea-snet-priv-02**: Routes to Cato for specific partner/customer subnets

### Cato SD-WAN/SASE Integration

- **Purpose**: SD-WAN connectivity and security
- **User Access**: Cato SDP is target for business users
- **Legacy**: GlobalProtect retained for specific OT/legacy scenarios
- **Integration Point**: Connected via hub routing configuration

### Hairpinning Considerations

Spoke-to-spoke flows are addressed per landing-zone firewall design with forced tunneling where required.

---

## 5. CONNECTIVITY

### ExpressRoute

- **Circuit**: CON-EMEA-EXR
- **Gateway**: gw-rav-hub-expressroute (Standard SKU)
- **Connection**: con-rav-hub-emea-expressroute
- **Bandwidth**: 50Mbps
- **BGP**: Enabled
- **Resource Group**: rg-emea-con

### Public Endpoints

|Resource|Type|Purpose|Restriction|
|---|---|---|---|
|pip-gw-rav-hub-expressroute|Public IP|ExpressRoute gateway|N/A|
|pip-rav-hub-emea-bastion-host|Public IP|Hub Bastion|Microsoft managed|
|pip-rav-ssc-emea-bastion-host|Public IP|SSC Bastion|Microsoft managed|

---

## 6. IDENTITY & DOMAIN SERVICES

### Domain Controllers in Azure

- **Location**: Hosted in hub subscription (rg-rav-hub-emea-dc)
- **VMs**:
    - vmemeahubdc001 (10.9.210.4 for EMEA AVD)
    - vmemeahubdc002 (10.9.210.5 for EMEA AVD)
- **Availability Set**: as-rav-hub-emea-dc
- **Function**: Provide DNS to Azure VNets, service IaaS workloads
- **Pattern**: Read-Write DCs in each regional hub to service directly peered spokes

### DNS Configuration

- **Azure VNets**: Use Azure-hosted DC IPs as DNS servers
- **EMEA AVD**: Uses 10.9.210.4 and 10.9.210.5
- **AMER AVD**: Uses dedicated DC IPs in East US 2
- **Azure Private DNS**: Supports internal name resolution within VNets and across linked networks

### Azure Active Directory

- **Primary Identity Provider**: Azure AD (Entra ID)
- **Integration**: Synchronized with on-premises Active Directory
- **Domain**: ravago.com

---

## 7. PRIVATE DNS & PRIVATE ENDPOINTS

### Azure Private DNS Zones

- **Purpose**: Internal name resolution for PaaS services and Private Link
- **Scope**: VNet-linked for resolution across hub and spoke topology
- **Use Cases**:
    - Private endpoint DNS resolution
    - Internal service discovery
    - AVD infrastructure name resolution

### Private Endpoints Pattern

- **Deployment**: Per PaaS service requiring private connectivity
- **Traffic Pattern**: Stays private via hub-routed patterns
- **Integration**: Reflected in hub route tables and firewall rules
- **Example**: Azure Monitor Private Link Scope (AMPLS) for Log Analytics

---

## 8. PLATFORM SERVICES

### Key Vaults

|Key Vault|Resource Group|Subscription|Purpose|
|---|---|---|---|
|kv-rav-hub-emea|rg-rav-hub-emea-mgmt|sub-rav-hub-emea|Hub secrets, keys, certificates|
|kv-rav-ssc-emea|rg-rav-ssc-emea-mgmt|sub-rav-ssc-emea|SSC secrets, keys, certificates|

### Bastion Hosts

|Bastion|Resource Group|Subscription|VNet|
|---|---|---|---|
|abravhubemea|rg-rav-hub-emea-mgmt|sub-rav-hub-emea|vnet-rav-hub-emea|
|abravsscemea|rg-rav-ssc-emea-mgmt|sub-rav-ssc-emea|vnet-rav-ssc-emea|

### Backup

- **Recovery Services Vaults**:
    - rsv-rav-hub-emea-backup-01 (rg-rav-hub-emea-network)
    - rsv-rav-ssc-emea-backup-01 (rg-rav-ssc-emea-network)
- **Backup Policies**: Centralized management for all backup use cases
- **Policy Naming**: rsv-rav-hub-emea-backup-01-policy-01

### Update Management

- **Automation Account**: aa-rav-hub-emea (rg-rav-hub-emea-mgmt)
- **Update Schedule**: 04-SAT-2200-0600
- **Scope**: Centralized management for all update cases

### Monitoring

- **Log Analytics Workspace**: law-rav-hub-emea (rg-rav-hub-emea-mgmt)
- **Purpose**: Centralized logging for Azure Monitor and Sentinel
- **Solutions**: Updates solution enabled
- **Integration**: AMPLS for private connectivity

### Storage

- **Terraform State**: staccravprdemeaterraform (rg-rav-prd-emea-terraform)
- **Diagnostic Storage**:
    - stacchubemeadcdiag (Domain Controllers)
    - stacchubemeascomdiag (SCOM servers)

---

## 9. AZURE VIRTUAL DESKTOP (AVD)

### Configuration

- **Per-region VNets**: Dedicated VNets for AVD in each region
- **DNS**: Backed by Azure-hosted domain controllers
- **Resolution**: Azure Private DNS for VNet-local resolution
- **HA/DR**: Design includes high availability and disaster recovery considerations

### Network Integration

- **Hub Connectivity**: AVD VNets peer to regional hub
- **Name Resolution**: Uses DC IPs (e.g., 10.9.210.4/10.9.210.5 for EMEA)
- **Traffic Flow**: Routes through hub for security inspection

---

## 10. WINDOWS 365 (CLOUD PC)

### Configuration

- **Region Placement**: Typically automatic
- **ANC VNets**: Created only for scenarios requiring direct RavNet access
- **Integration**: Follows same hub-spoke connectivity pattern when ANC VNets deployed

---

## 11. AZURE SFTP SOLUTION

### Standardized Pattern

- **Platform**: Azure Storage SFTP
- **Permissions**: Container-scoped per external party
- **Security Defaults**:
    - TLS 1.2 minimum
    - No anonymous blob access
    - Soft delete enabled
- **Governance**: Standardized naming and onboarding process

---

## 12. SECURITY & COMPLIANCE

### Network Security Groups (NSGs)

|NSG Name|Attached Subnet|VNet|Resource Group|
|---|---|---|---|
|nsg-vnet-rav-hub-emea-snet-arx-01|vnet-rav-hub-emea-snet-arx-01|vnet-rav-hub-emea|rg-rav-hub-emea-network|
|nsg-vnet-rav-hub-emea-snet-mgmt-01|vnet-rav-hub-emea-snet-mgmt-01|vnet-rav-hub-emea|rg-rav-hub-emea-network|
|nsg-vnet-rav-ssc-emea-snet-mgmt-01|vnet-rav-ssc-emea-snet-mgmt-01|vnet-rav-ssc-emea|rg-rav-ssc-emea-network|

### Azure Policy (Applied at mg-it level)

|Policy Name|Effect|Description|
|---|---|---|
|Allowed_locations|Deny|List of allowed Azure regions|
|deny_non_https_traffic_api_and_webapp|Deny|Deny non-HTTPS traffic on web apps and APIs|
|append_tags_from_resourcegroup|Append|Inherit tags from resource group|
|deny_non_SSL_function_app|Deny|Deny non-SSL traffic on function apps|
|deny_storageaccounthttp|Deny|Deny HTTP traffic on storage accounts|
|denySubnetWithoutNsg|Deny|Deny subnets without NSG attached|

### Microsoft Defender for Cloud

- **Tier**: Free tier enabled across all subscriptions
- **Scope**: sub-rav-hub-emea, sub-rav-prd-emea, sub-rav-acc-emea, sub-rav-dev-emea, sub-rav-ssc-emea

### Azure Lighthouse

- **Arxus Managed Services (Premium)**: Enabled on specific resource groups (emea-con, mgmt, network, dc, terraform)
- **Arxus Managed Services (Basic)**: Enabled at subscription level

---

## 13. RBAC & ACCESS MANAGEMENT

### Service Principals (Examples)

- **devops-rav-azure-network_management**: Owner at mg-rav-it
- **devops-rav-azure-subscription_management**: Owner at mg-rav-it
- **RavagoDevOps-ravago_network-mg-rav-it**: Owner at mg-rav-it

### Privileged Identity Management (PIM)

- **Status**: Not currently implemented
- **Access Model**: Roles directly assigned on scopes

### Conditional Access

- **Status**: No additional security configured beyond Role Assignments

---

## 14. INFRASTRUCTURE AS CODE (IaC)

### Terraform Deployments

- **Execution**: Delivered by Arxus
- **State Storage**: Azure Storage Account (staccravprdemeaterraform)
- **Pipeline Tool**: Azure DevOps
- **Agent Pool**: pool-ravago (self-hosted)
- **Pipeline Library**: ravago_iac_library (shared templates)

### Azure DevOps Projects & Pipelines

|Pipeline|DevOps Project|Repository|Purpose|
|---|---|---|---|
|Subscription_management|RavagoDevOps|ravago_subscription_management|Subscription lifecycle|
|Network_deploy|RavagoDevOps|ravago_network|Network infrastructure|
|ipam|RavagoDevOps|ravago_applications|IP Address Management|
|admanager|RavagoDevOps|ravago_applications|AD management automation|

### EPAC (Enterprise Policy as Code)

- **Purpose**: Azure Policy management via IaC
- **Deployment**: Across EMEA/AMER/NEUR landing zones
- **Scope**: Management group level policy assignments

---

## 15. NAMING STANDARDS

### Subscription Naming

Pattern: `sub-rav-{environment}-{region}`

- Example: sub-rav-prd-emea, sub-rav-dev-emea

### Resource Group Naming

Pattern: `rg-rav-{environment}-{region}-{purpose}`

- Example: rg-rav-hub-emea-network, rg-rav-prd-emea-mgmt

### VNet Naming

Pattern: `vnet-rav-{environment}-{region}`

- Example: vnet-rav-hub-emea, vnet-rav-prd-emea

### Subnet Naming

Pattern: `vnet-{vnet-name}-snet-{purpose}-{instance}`

- Example: vnet-rav-hub-emea-snet-mgmt-01

### VM Naming

Pattern: `vm{region}{function}{instance}{environment}`

- Example: vmemeahubdc001 (EMEA Hub Domain Controller 001)
- Region codes: emea, amer, apac
- Environment suffix: p (production), d (development), a (acceptance)

### Storage Account Naming

Pattern: `st{purpose}{region}{environment}{function}`

- Example: staccravprdemeaterraform
- Note: Lowercase, no hyphens, max 24 characters

### Network Security Group Naming

Pattern: `nsg-{vnet-name}-{subnet-name}`

- Example: nsg-vnet-rav-hub-emea-snet-mgmt-01

### Key Vault Naming

Pattern: `kv-rav-{environment}-{region}`

- Example: kv-rav-hub-emea, kv-rav-ssc-emea

### Route Table Naming

Pattern: `rt-{vnet-name}-{subnet-name}`

- Example: rt-vnet-rav-hub-emea-snet-priv-01

---

## 16. COMMON TROUBLESHOOTING PATTERNS

### Palo Alto Firewall Issues

- **SSL Inspection Blocking**: AVD control plane (*.wvd.microsoft.com) requires SSL inspection bypass
- **Private Endpoint Connectivity**: VPN-to-private-endpoint traffic may require explicit app-id rules (e.g., azure-storage-accounts-base)
- **Service Bus**: Standard tier requires public endpoint; Premium tier supports private endpoints with VNet integration

### Private Endpoint Resolution

- **DNS Forwarders**: Required in hub for proper private endpoint name resolution
- **Private DNS Zones**: Must be VNet-linked to all spokes requiring resolution
- **DC Configuration**: Validate conditional forwarders point to Azure DNS (168.63.129.16)

### VNet Integration Issues

- **Azure Functions**: VNet integration requires Premium plan or dedicated App Service Plan
- **Service Bus**: VNet integration available only on Premium tier
- **Routing**: Verify route tables don't block Azure platform traffic (AzureCloud service tag)

### Certificate Management

- **DigiCert Wildcard**: *.ravago.com certificate used across multiple Application Gateway listeners
- **Renewal Workflow**: DigiCert → DNSMadeEasy → Key Vault → Application Gateway
- **Entra Domain Services**: Requires separate Secure LDAP certificate

---

## 17. KEY OPERATIONAL CONTACTS

### Infrastructure Delivery

- **Primary**: Arxus (managed service provider)
- **Role**: Terraform deployments, monitoring, backup, automation

### IT Infrastructure Team

- **Owner**: RBAC, governance, architecture
- **Role**: Policy definition, security standards, operational oversight

### Network Team

- **Function**: Palo Alto firewall management, routing policies
- **Tool**: Panorama for centralized firewall management

---

## 18. REFERENCE ARCHITECTURE DIAGRAM (TEXT)

```
                     [Internet/Partners]
                            |
                     (Akamai/WAF as needed)    (Cato PoPs)
                            |                        |
        +---------[EMEA HUB VNet 10.8.0.0/19]-------+
                   |         |            |
              [Gateway]  [Palo Alto]  [Bastion]  [Mgmt]
                   |         |            |
        +----------+------+  |  +---------+---------+
        |                 |  |  |                   |
   [PRD Spoke        [SSC Spoke           [ACC Spoke    [DEV Spoke
   10.8.32/19]       10.8.64/19]          10.8.96/19]   10.8.128/19]
        |                 |                     |              |
   App tiers, PEs    Shared services      Test/UAT       Dev/Build
        
   (Hub route tables → Palo Alto/Cato for inspection/egress/SD-WAN)
```

---

## 19. CRITICAL SERVICES & DEPENDENCIES

### Domain Controller Dependencies

- **AVD**: Requires DC DNS for session host domain join and user authentication
- **IaaS VMs**: Domain-joined workloads rely on DC availability
- **Azure AD Connect**: Synchronization depends on DC reachability
- **DNS Resolution**: All private endpoint resolution chains through DC forwarders

### Palo Alto NVA Dependencies

- **Spoke-to-Spoke**: All inter-spoke traffic inspected by Palo Alto
- **Internet Egress**: Routes through Palo Alto for security policies
- **On-Premises**: Hub-to-ExpressRoute traffic may route through firewall
- **Critical**: Single point of failure for hub-spoke traffic flow

### ExpressRoute Circuit

- **On-Premises Connectivity**: Primary path for datacenter integration
- **BGP**: Dynamic routing between Azure and on-premises
- **Bandwidth**: 50Mbps shared across all traffic
- **Redundancy**: Circuit resilience per Microsoft SLA

---

## 20. AZURE REGIONS & PAIRED REGIONS

### Primary Pairing

- **West Europe (EMEA)**: Paired with North Europe
- **East US 2 (AMER)**: Paired with Central US

### Disaster Recovery Considerations

- **AVD**: Multi-region design with DR considerations
- **Data Replication**: Leverage paired region benefits for geo-redundant storage
- **Backup**: Cross-region backup vault replication available

---

## 21. SPECIAL NOTES FOR LLM USAGE

### When Troubleshooting

1. Check Palo Alto firewall rules first for connectivity issues
2. Verify private DNS zone links for private endpoint resolution
3. Confirm route tables are directing traffic through hub
4. Validate NSG rules at subnet level before debugging application layer

### When Designing Solutions

1. All new workloads should deploy to appropriate spoke (PRD/ACC/DEV based on lifecycle)
2. Private endpoints are preferred for PaaS service connectivity
3. Route traffic through Palo Alto for security inspection
4. Follow established naming standards for all resources
5. Use Terraform for infrastructure deployment (Arxus execution)

### Common IP Address Ranges to Remember

- **Hub**: 10.8.0.0/19
- **PRD**: 10.8.32.0/19
- **SSC**: 10.8.64.0/19
- **ACC**: 10.8.96.0/19
- **DEV**: 10.8.128.0/19
- **AMER**: 10.19.0.0/16 (reserved)
- **AVD EMEA DCs**: 10.9.210.4, 10.9.210.5

### Integration Points with External Systems

- **SAP**: SAP PI/PO integration, SAP HANA databases
- **webMethods**: AS2/EDI integration platform
- **Logic Apps**: Azure Logic Apps for workflow automation
- **Power Platform**: Dataverse integration, Power Apps
- **Azure Functions**: Serverless compute with VNet integration

---

## 22. RESOURCE GROUP CONVENTIONS

### Management Resource Groups

- **Purpose**: Infrastructure management tooling
- **Naming**: rg-rav-{env}-{region}-mgmt
- **Contents**: Automation accounts, backup vaults, monitoring

### Network Resource Groups

- **Purpose**: Networking infrastructure
- **Naming**: rg-rav-{env}-{region}-network
- **Contents**: VNets, NSGs, route tables, gateways, public IPs

### Domain Controller Resource Group

- **Unique**: rg-rav-hub-emea-dc
- **Purpose**: Dedicated RG for DC VMs in hub
- **Isolation**: Separates critical identity infrastructure

### Terraform Resource Groups

- **Purpose**: Terraform state and configuration
- **Example**: rg-rav-prd-emea-terraform
- **Contents**: State storage accounts

---

## 23. VERSION HISTORY & DOCUMENTATION

### Document Versioning

- **Template**: Ravago corporate Word template
    - Blue header bar (#0245AE)
    - Calibri font, 14pt bold headings
    - Footer with dept/version/page numbers
    - "Internal use only" classification

### Key Documentation References

- Landing Zone As-Built v2 (comprehensive network topology)
- Network Standard (RavNet design, IP plan, site types)
- VM Deployment Standard (naming, provisioning)
- Azure SFTP Standard (SFTP service onboarding)
- AVD Documentation (virtual desktop configuration)

---

## 24. AMER (AMERICAS) REGION SPECIFICS

### Region Details

- **Location**: East US 2
- **Address Space**: 10.19.0.0/16 reserved for AMER Azure
- **Architecture**: Same hub-and-spoke pattern as EMEA
    - Hub + PRD/ACC/DEV/SSC spokes
    - Palo Alto integration
    - ExpressRoute connectivity
    - Dedicated domain controllers

### Deployment Status

- **Strategy**: Cloud-First program
- **Pattern**: Mirrors EMEA implementation
- **Governance**: Same management group structure (mg-amer-prd, mg-amer-non-prd)

---

## 25. GRAFANA MONITORING

### Azure Managed Grafana

- **Instance**: amg-rav-prd-001
- **Access**: Via Application Gateway with custom domain
- **Data Sources**:
    - Azure Monitor
    - Log Analytics
    - Infinity datasource for Azure Management APIs

### Dashboard Types

- **Billing/Cost Management**: Using Infinity datasource + Azure Management API
- **Reservation Data**: Cost optimization tracking
- **VM Insights**: Performance monitoring
- **Update Manager Compliance**: Patch status across estate
- **Disk Space Monitoring**: KQL-based alerting

### Authentication

- **Method**: Azure AD (Entra ID) SSO
- **DNS**: Private DNS zone for SSO endpoint required
- **SNI Validation**: Application Gateway configuration

---

## 26. APPLICATION GATEWAY

### Configuration Pattern

- **SSL Certificates**: Stored in Key Vault, referenced by Application Gateway
- **Wildcard Cert**: *.ravago.com used across multiple listeners
- **URL Rewriting**: Regex-based for complex routing (e.g., ARO DEV cluster)
- **Naming Convention**: Standardized via Terraform
- **Management**: IaC via Terraform, drift resolution between Portal and code

### Common Use Cases

- Azure Managed Grafana frontend (custom domain)
- Web application publishing
- SSL offload for backend services
- Path-based routing for multi-tenant apps

---

## 27. TERRAFORM PATTERNS

### State Management

- **Backend**: Azure Storage Account
- **Location**: rg-rav-prd-emea-terraform/staccravprdemeaterraform
- **Locking**: Blob lease for state lock

### Module Structure

- **Shared Libraries**: ravago_iac_library in Azure DevOps
- **Environment Templates**: Multi-environment Terraform deployments
- **AMBA UMI**: Drift fixes for Azure Monitor Baseline Alerts identity

### Deployment Flow

1. Code commit to Azure DevOps repository
2. Pipeline triggers from pool-ravago (self-hosted agent)
3. Terraform plan generated
4. Manual approval (environment gates)
5. Terraform apply executed
6. State stored in Azure Storage

---

## 28. AZURE SERVICE BUS MIGRATION PATTERN

### Standard to Premium Upgrade

- **Driver**: VNet integration requirement for Azure Functions
- **Blocker**: Palo Alto firewall blocking Standard tier Service Bus from VNet-integrated functions
- **Solution**: Migrate to Premium tier with private endpoints
- **Phases**:
    1. Provision Premium namespace
    2. Configure private endpoint in spoke VNet
    3. Update DNS (private DNS zone)
    4. Migrate queues/topics
    5. Update application connection strings
    6. Decommission Standard namespace

### Private Endpoint Requirements

- **VNet Integration**: Functions Premium plan or dedicated App Service Plan
- **DNS**: Private DNS zone (privatelink.servicebus.windows.net)
- **Routing**: Traffic stays within VNet, no public internet traversal

---

## 29. DATABASE MIGRATION PATTERNS

### SQL Server to Azure SQL

- **Method**: BACPAC export/import via jumpserver
- **Example**: Cegid/Ekon ERP migration to sql-rav-prd-emea-promic
- **Challenges**:
    - TLS interception by Palo Alto
    - Private endpoint import restrictions
    - Orphaned user resolution
    - Sysadmin recovery (single-user mode)

### Vendor Handoff Pattern

- **Database Provisioning**: Azure SQL with user/role setup
- **Access**: SQL authentication + Azure AD authentication
- **Example**: EKRON-BRILL Promic Formula Integration (FI-EKRON-BRILL)
- **Permissions**: Container-scoped, least privilege

---

## 30. CRITICAL REMINDER FOR LLM

This knowledge base represents Ravago's current state Azure infrastructure. When working with this information:

1. **No External Links**: All information self-contained, no dependency on external URLs
2. **Current as of**: March 2026 (based on documentation date)
3. **Primary Contact**: Carlos (adm_CarlosFe@ravago.com) - Senior Cloud System Engineer
4. **Execution Partner**: Arxus for Terraform/IaC deployments
5. **Regions**: Focus on EMEA (West Europe) and AMER (East US 2)

### Critical Services Never to Disrupt

- Domain Controllers (identity backbone)
- Palo Alto NVA (traffic inspection)
- ExpressRoute circuit (on-premises connectivity)
- Hub VNet routing (all spoke connectivity depends on it)

### Always Validate Before Making Changes

- Route table modifications (can break connectivity)
- NSG rule changes (can block critical traffic)
- Private DNS zone links (affects name resolution)
- Firewall policy updates (coordinate with network team)