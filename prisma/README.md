# 🔐 get-prisma-egress-ip.ps1
# 🔐 get-prisma-egress-ipv46.ps1

Fetches [Prisma Access](https://www.paloaltonetworks.com/prisma/access) egress IP addresses from Palo Alto Networks’ public API and exports them to CSV format for both **IPv4** and **IPv6** address types.

---

## 📌 Script Details

| Field            | Value                              |
|------------------|-------------------------------------|
| **Script Name**  | `get-prisma-ip.ps1`                |
| **Author**       | Bala Murugan S                     |
| **GitHub**       | [bala-murugan-s](https://github.com/bala-murugan-s) |
| **Created**      | October 7, 2025                    |
| **PowerShell**   | Compatible with PowerShell Core 7.x / Windows PowerShell 5.1+ |
| **API Docs**     | [Prisma Access IP Retrieval Guide](https://docs.paloaltonetworks.com/prisma-access/administration/prisma-access-setup/retrieve-ip-addresses-for-prisma-access) |

---

## 🚀 Usage

```powershell
# Run the script by passing your Prisma Access API key
pwsh ./get-prisma-egress-ip.ps1 -ApiKey "<your_api_key_here>"

