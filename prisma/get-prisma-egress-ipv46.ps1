<#
.title           : get-prisma-egress-ipv46.ps1
.description     : Fetches Prisma Access infrastructure IPs via API and exports address details (IPv4 and optional IPv6) to CSV
.author          : bala-murugan-s
.github_user_id  : bala-murugan-s
.date            : 7-oct-2025
.pwsh_version    : Compatible with PowerShell Core / Windows PowerShell
.usage           : pwsh ./get-prisma-egress-ipv46.ps1 -ApiKey "<your_api_key>"
.privilege       :No elevated permissions required
.output          :output.json (raw response), csvoutput.csv (extracted IP data)
.notes           : 
    - The payload can be customized inside the script (see section below).
    - By default, pulls all IPv4 addresses. IPv6 addresses also exported if found.
    - Refer to the official documentation for allowed values:
      https://docs.paloaltonetworks.com/prisma-access/administration/prisma-access-setup/retrieve-ip-addresses-for-prisma-access

.payload_customization :

You can edit the `$payload` inside `Get-RequestPayload` to filter results.
Valid values from documentation:

  serviceType (6 options):
    - all, remote_network, gp_gateway, gp_portal, swg_proxy, rbi

  addrType (5 options):
    - all, active, service_ip, auth_cache_service, network_load_balancer

  location (2 options):
    - all, deployed

  actionType (2 options):
    - pre_allocate, (null / not set)

Example: To fetch only GP Gateway pre-allocated IPs, modify payload:
$payload = @{
    serviceType = "gp_gateway"
    addrType    = "all"
    location    = "all"
    actionType  = "pre_allocate"
}

.output_files    :
  - raw_output.json       (raw API response)
  - prisma_egress_ipv4_list.csv    (IPv4 address details)
  - prisma_egress_ipv6_list.csv    (IPv6 subnet details — if present)

.sample_output    :

IPv4 CSV:
address        | serviceType | addressType            | allow_listed
---------------|-------------|------------------------|--------------
169.2.3.4      | gp_gateway  | active                 | TRUE
134.10.11.12   | gp_gateway  | network_load_balancer | 

IPv6 CSV:
address                            | addressType            | allow_listed
-----------------------------------|------------------------|---------------
2606:f4c0:1111:13d4::/64           | active                 | FALSE
2606:f4c0:2222:13d3::/64           | network_load_balancer  | FALSE
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ApiKey
)

# === Global Constants ===
$ApiUrl        = "https://api.prod6.datapath.prismaaccess.com/getPrismaAccessIP/v2"
$JsonOutput    = "raw_output.json"
$CsvOutputIPv4 = "prisma_egress_ipv4_list.csv"
$CsvOutputIPv6 = "prisma_egress_ipv6_list.csv"

# ===========================
# Function: Get-RequestPayload
# Purpose : Returns the default payload
# ===========================
function Get-RequestPayload {
    $payload = @{
        serviceType = "all"
        addrType    = "all"
        location    = "all"
        # actionType = "pre_allocate"  # Uncomment if needed
    }
    return $payload | ConvertTo-Json -Compress
}

# ===========================
# Function: Call-PrismaAccessApi
# Purpose : Calls the Prisma Access IP API and stores response
# ===========================
function Call-PrismaAccessApi {
    param (
        [string]$ApiKey,
        [string]$PayloadJson,
        [string]$OutputPath
    )

    $headers = @{ "header-api-key" = $ApiKey }

    Write-Host "`n📡 Calling Prisma Access API..." -ForegroundColor Cyan

    try {
        Invoke-RestMethod -Method Post -Uri $ApiUrl -Headers $headers -Body $PayloadJson -ContentType "application/json" -OutFile $OutputPath
        Write-Host "✔ JSON response saved: $OutputPath" -ForegroundColor Green
    } catch {
        Write-Error "❌ API call failed: $($_.Exception.Message)"
        exit 1
    }
}

# ===========================
# Function: Convert-JsonToCsv
# Purpose : Parses API response and exports IPv4 and IPv6 address details
# ===========================
function Convert-JsonToCsv {
    param (
        [string]$JsonPath,
        [string]$CsvPathIPv4,
        [string]$CsvPathIPv6
    )

    try {
        $json = Get-Content -Raw $JsonPath | ConvertFrom-Json

        if ($null -eq $json.result) {
            Write-Error "❌ JSON does not contain 'result'"
            exit 1
        }

        $allIPv4 = @()
        $allIPv6 = @()

        foreach ($zone in $json.result) {
            # IPv4 address_details
            foreach ($entry in $zone.address_details) {
                $ipv4 = [PSCustomObject]@{
                    address      = $entry.address
                    serviceType  = $entry.serviceType
                    addressType  = $entry.addressType
                    allow_listed = if ($entry.PSObject.Properties.Name -contains "allow_listed") { $entry.allow_listed } else { "" }
                }
                $allIPv4 += $ipv4
            }

            # IPv6 address_details
            foreach ($entry in $zone.zone_subnet_v6_details) {
                $ipv6 = [PSCustomObject]@{
                    address      = $entry.address
                    addressType  = $entry.addressType
                    allow_listed = $entry.allow_listed
                }
                $allIPv6 += $ipv6
            }
        }

        if ($allIPv4.Count -gt 0) {
            $allIPv4 | Export-Csv -Path $CsvPathIPv4 -NoTypeInformation
            Write-Host "✔ IPv4 CSV file created: $CsvPathIPv4" -ForegroundColor Green
        } else {
            Write-Host "⚠ No IPv4 address details found." -ForegroundColor Yellow
        }

        if ($allIPv6.Count -gt 0) {
            $allIPv6 | Export-Csv -Path $CsvPathIPv6 -NoTypeInformation
            Write-Host "✔ IPv6 CSV file created: $CsvPathIPv6" -ForegroundColor Green
        } else {
            Write-Host "⚠ No IPv6 subnet details found." -ForegroundColor Yellow
        }

    } catch {
        Write-Error "❌ Failed to convert JSON to CSV: $($_.Exception.Message)"
        exit 1
    }
}

# ==== MAIN EXECUTION ====
$payloadJson = Get-RequestPayload
Call-PrismaAccessApi -ApiKey $ApiKey -PayloadJson $payloadJson -OutputPath $JsonOutput
Convert-JsonToCsv -JsonPath $JsonOutput -CsvPathIPv4 $CsvOutputIPv4 -CsvPathIPv6 $CsvOutputIPv6
