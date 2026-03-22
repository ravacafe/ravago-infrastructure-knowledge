## The Core Difference: Where Does the App Logic Run?

```mermaid
flowchart LR
    subgraph AGW_MODEL["Application Gateway Model"]
        direction TB
        U1["👤 User\n(browser)"]
        AGW["Application Gateway\nSSL termination · WAF"]
        WEB["Web Server\n(App Service / VM)"]
        DB1[("Azure SQL\nPrivate Endpoint")]
        U1 -->|"HTTPS"| AGW
        AGW -->|"HTTP"| WEB
        WEB -->|"TCP 1433\nfrom inside VNet"| DB1
    end

    subgraph AVD_MODEL["AVD RemoteApp Model"]
        direction TB
        U2["👤 User\n(AVD client)"]
        AVD["AVD Broker\nRDP over HTTPS"]
        HOST["Session Host VM\nApp installed here"]
        DB2[("Azure SQL\nPrivate Endpoint")]
        U2 -->|"RDP/HTTPS"| AVD
        AVD -->|"RDP session"| HOST
        HOST -->|"TCP 1433\nfrom inside VNet"| DB2
    end
    '''
    