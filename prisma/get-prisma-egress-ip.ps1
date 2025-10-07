<#
.title           :get-prisma-egress-ip.ps1
.description     :Fetches Prisma Access IP addresses from Palo Alto's API and exports them to CSV
.author          :bala-murugan-s
.github_user_id  :bala-murugan-s
.date            :7-oct-2025
.pwsh_version    :Compatible with PowerShell Core 7.x / Windows PowerShell 5.1+
.usage           :pwsh ./get-prisma-egress-ip.ps1 -ApiKey "<your_api_key_here>"
.privilege       :No elevated permissions required
.output          :output.json (raw response), csvoutput.csv (extracted IP data)
.notes           : 
    - You can manually modify the payload in the script to filter results.
    - Refer to the official documentation for valid payload values:
      https://docs.paloaltonetworks.com/prisma-access/administration/prisma-access-setup/retrieve-ip-addresses-for-prisma-access

.payload_customization :

You can edit the `$payload` inside the `Get-RequestPayload` function to filter API results.
Valid values per field (from official documentation):

  serviceType (6 options):
    - all
    - remote_network
    - gp_gateway
    - gp_portal
    - swg_proxy
    - rbi

  addrType (5 options):
    - all
    - active
    - service_ip
    - auth_cache_service
    - network_load_balancer

  location (2 options):
    - all
    - deployed

  actionType (2 options):
    - pre_allocate
    - (null / not set) → omit key entirely

Example: To fetch only GP Gateway pre-allocated IPs, change the payload like this:

$payload = @{
    serviceType = "gp_gateway"
    addrType    = "all"
    location    = "all"
    actionType  = "pre_allocate"
}

.output          : output.json (raw JSON), csvoutput.csv (flattened address details)
.sample_output   :

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
# These are used throughout the script for API calls and file paths
$ApiUrl     = "https://api.prod6.datapath.prismaaccess.com/getPrismaAccessIP/v2"
$JsonOutput = "raw_output.json"
$CsvOutput  = "prisma_egress_ip_list.csv"

# ===========================
# Function: Get-RequestPayload
# Purpose : Returns the static payload required for the Prisma API request.
# ===========================
function Get-RequestPayload {
    return @{
        serviceType = "all"
        addrType    = "all"
        location    = "all"
    } | ConvertTo-Json -Compress
}

# ===========================
# Function: Call-PrismaAccessApi
# Purpose : Makes the API call to Prisma Access and saves the JSON output.
# Params  : ApiKey (string), PayloadJson (string), OutputPath (string)
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
# Purpose : Parses the API response and extracts address details into a CSV file.
# Params  : JsonPath (string), CsvPath (string)
# Notes   : Flattens all address_details across zones; handles missing fields.
# ===========================
function Convert-JsonToCsv {
    param (
        [string]$JsonPath,
        [string]$CsvPath
    )

    try {
        $json = Get-Content -Raw $JsonPath | ConvertFrom-Json

        if ($null -eq $json.result) {
            Write-Error "❌ JSON does not contain 'result'"
            exit 1
        }

        $allAddresses = @()

        # Loop through each zone and collect all address_details
        foreach ($zone in $json.result) {
            foreach ($entry in $zone.address_details) {
                $allAddresses += [PSCustomObject]@{
                    address      = $entry.address
                    serviceType  = $entry.serviceType
                    addressType  = $entry.addressType
                    allow_listed = if ($entry.PSObject.Properties.Name -contains "allow_listed") { $entry.allow_listed } else { "" }
                }
            }
        }

        # Export to CSV
        $allAddresses | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Host "✔ CSV file created: $CsvPath" -ForegroundColor Green
    } catch {
        Write-Error "❌ Failed to convert JSON to CSV: $($_.Exception.Message)"
        exit 1
    }
}

# ========== MAIN EXECUTION BLOCK ==========

# 1. Build the request body
$payload = Get-RequestPayload

# 2. Make the API request and store raw JSON
Call-PrismaAccessApi -ApiKey $ApiKey -PayloadJson $payload -OutputPath $JsonOutput

# 3. Convert the response to CSV
Convert-JsonToCsv -JsonPath $JsonOutput -CsvPath $CsvOutput
