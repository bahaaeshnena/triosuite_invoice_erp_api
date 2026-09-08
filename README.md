# Triosuite Invoice ERP API

Triosuite Invoice ERP API is an ASP.NET Core 8 REST API for a bilingual (Arabic/English) sales-invoice workflow. It provides JWT authentication, refresh-token rotation, invoice creation and editing, approval and cancellation, lookup data, company settings, tax calculations, and multi-currency totals.

## Technology stack

- ASP.NET Core Web API on .NET 8
- Microsoft SQL Server
- ADO.NET with `Microsoft.Data.SqlClient`
- Stored procedures for all database operations
- JWT bearer authentication with rotating refresh tokens
- Swagger / OpenAPI for interactive API documentation

## Project structure

```text
triosuite_invoice_erp_api/
├── Controllers/                 HTTP endpoints
├── Data/                        SQL Server data-access service
├── Database/
│   ├── 01_CreateDatabaseAndTables.sql
│   ├── 02_CreateStoredProcedures.sql
│   └── 03_SeedData.sql
├── Middleware/                  Central API exception handling
├── Models/                      Request and response models
├── Properties/                  Local launch profile
├── Services/                    JWT and password services
├── appsettings.json             Default application configuration
└── triosuite_invoice_erp_api.http  Ready-to-run HTTP examples
```

## Features

- Login, logout, access tokens, and secure refresh-token rotation
- Arabic and English customer, item, company, and lookup names
- Currencies and configurable exchange rates
- Inclusive and exclusive tax calculation
- Draft, approved, and cancelled invoice states
- Invoice search and status filtering
- Barcode item lookup
- Swagger UI and reusable `.http` request examples
- Idempotent database scripts that can be safely executed more than once

## Prerequisites

Install the following software before starting:

1. [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
2. Microsoft SQL Server 2016 SP1 or newer (SQL Server 2019/2022 is recommended)
3. One SQL client:
   - SQL Server Management Studio (SSMS), or
   - Azure Data Studio, or
   - the `sqlcmd` command-line utility
4. Git, if you are cloning the repository

The invoice save procedure uses `OPENJSON`, so the database compatibility level must be 130 or higher. A newly created database on a supported SQL Server version normally meets this requirement.

## Installation

### 1. Clone the repository

```powershell
git clone https://github.com/bahaaeshnena/triosuite_invoice_erp_api.git
cd triosuite_invoice_erp_api
```

### 2. Create and initialize the database

Run the scripts in the following exact order:

| Order | Script | Purpose |
|---:|---|---|
| 1 | `Database/01_CreateDatabaseAndTables.sql` | Creates `SalesInvoiceDB`, tables, constraints, and indexes |
| 2 | `Database/02_CreateStoredProcedures.sql` | Creates or updates every stored procedure used by the API |
| 3 | `Database/03_SeedData.sql` | Inserts required system codes and the initial demo data |

#### Option A: SQL Server Management Studio

1. Connect to the SQL Server instance.
2. Open `Database/01_CreateDatabaseAndTables.sql` and select **Execute**.
3. Repeat for scripts 2 and 3, in order.
4. Confirm that the `SalesInvoiceDB` database appears in Object Explorer.

#### Option B: sqlcmd with Windows authentication

```powershell
sqlcmd -S localhost -E -b -i ".\Database\01_CreateDatabaseAndTables.sql"
sqlcmd -S localhost -E -b -i ".\Database\02_CreateStoredProcedures.sql"
sqlcmd -S localhost -E -b -i ".\Database\03_SeedData.sql"
```

Replace `localhost` with your SQL Server instance name when needed, for example `localhost\SQLEXPRESS`. The `-b` flag makes `sqlcmd` return an error if a script fails.

### 3. Configure the connection string

The default configuration uses SQL Server on `localhost` with Windows authentication:

```json
"ConnectionStrings": {
  "SalesInvoiceDB": "Server=localhost;Database=SalesInvoiceDB;Trusted_Connection=True;TrustServerCertificate=True;"
}
```

Common alternatives are:

```text
# SQL Express
Server=localhost\SQLEXPRESS;Database=SalesInvoiceDB;Trusted_Connection=True;TrustServerCertificate=True;

# SQL authentication
Server=localhost;Database=SalesInvoiceDB;User Id=YOUR_USER;Password=YOUR_PASSWORD;TrustServerCertificate=True;
```

For local development, use .NET user secrets so credentials and the JWT signing key are not committed to Git:

```powershell
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:SalesInvoiceDB" "Server=localhost;Database=SalesInvoiceDB;Trusted_Connection=True;TrustServerCertificate=True;"
dotnet user-secrets set "Jwt:Key" "replace-with-a-long-random-secret-at-least-32-characters"
```

You can also use environment variables:

```powershell
$env:ConnectionStrings__SalesInvoiceDB = "Server=localhost;Database=SalesInvoiceDB;Trusted_Connection=True;TrustServerCertificate=True;"
$env:Jwt__Key = "replace-with-a-long-random-secret-at-least-32-characters"
```

> The JWT key in `appsettings.json` is a development placeholder. Replace it before deploying the API. Never commit production database passwords or signing keys.

### 4. Restore, build, and run

For API testing on the same computer only:

```powershell
dotnet restore
dotnet build
dotnet run
```

The development profile starts the API at:

- API base URL: `http://localhost:5112`
- Swagger UI: `http://localhost:5112/swagger`

If the terminal displays another URL, use the URL shown by `dotnet run`.

## Connect a physical Android device over the local network

`localhost` always means the device on which the URL is opened. Therefore, `http://localhost:5112` works from the API computer, but it does not work from a physical Android phone. The phone must use the API computer's LAN IPv4 address.

### 1. Connect both devices to the same network

Connect the Windows computer that runs SQL Server and the API, and the Android phone that runs Flutter, to the same Wi-Fi/router. Guest Wi-Fi networks may block communication between connected devices and should be avoided.

### 2. Find the API computer's IPv4 address

Run this on the API computer:

```powershell
ipconfig
```

Find **IPv4 Address** under the active Wi-Fi or Ethernet adapter. It will normally look similar to:

```text
192.168.1.17
```

`192.168.1.100` and `192.168.1.17` are examples only. Always use the address reported on the computer that will run the API.

### 3. Start the API on all network interfaces

From the API project directory, run:

```powershell
dotnet restore
dotnet run --urls "http://0.0.0.0:5112"
```

When running from the parent directory, use:

```powershell
dotnet run --project .\triosuite_invoice_erp_api\triosuite_invoice_erp_api.csproj --urls "http://0.0.0.0:5112"
```

`0.0.0.0` is a server listening address. Do not put `0.0.0.0` in Flutter. Flutter must use the computer's actual IPv4 address.

The API route prefix `/api/` is also not part of the Kestrel listening address. The server listens on port `5112`, while controllers expose routes such as `/api/auth/login`.

### 4. Allow TCP port 5112 through Windows Firewall

When Windows displays a firewall prompt, allow access on **Private networks**. If no prompt appears, open PowerShell as Administrator and run:

```powershell
New-NetFirewallRule -DisplayName "Triosuite Invoice API 5112" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5112 -Profile Private
```

Only create this rule on the computer that runs the API. Keep the network profile set to **Private**, not Public.

### 5. Test the API before building Flutter

First test Swagger on the API computer:

```text
http://localhost:5112/swagger/index.html
```

Then open the following URL in the Android phone's browser, replacing the example IP:

```text
http://192.168.1.17:5112/swagger/index.html
```

Do not continue to the Flutter build until the Swagger page opens from the phone. If it does not open, the issue is the IP address, API listener, firewall, or Wi-Fi network—not Flutter.

### 6. Use the same address in Flutter

If the computer IP is `192.168.1.17`, the Flutter base URL is:

```text
http://192.168.1.17:5112/api/
```

Build the Android release from the Flutter project:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.17:5112/api/
```

The `API_BASE_URL` value is compiled into the APK. If the computer's IP address changes, the existing APK will still call the old address. Either reserve that IPv4 address in the router/DHCP settings, assign a suitable static address to the computer, or rebuild the APK with the new address.

For an APK sent to another person, that person's API computer must use the exact IP address embedded in the APK. Otherwise, the recipient must build a new APK using their own computer's IPv4 address.

### URL reference

| Flutter target | API address used by Flutter | API command |
|---|---|---|
| Windows/Web on API computer | `http://localhost:5112/api/` | `dotnet run` |
| Android Emulator on API computer | `http://10.0.2.2:5112/api/` | `dotnet run --urls "http://0.0.0.0:5112"` |
| Physical Android phone | `http://<API-PC-IP>:5112/api/` | `dotnet run --urls "http://0.0.0.0:5112"` |

Example: if `<API-PC-IP>` is `192.168.1.17`, use `http://192.168.1.17:5112/api/`.

## Run a published API package

To prepare a Release package:

```powershell
dotnet publish -c Release -o .\publish
```

Copy the `publish` directory to the target computer. After installing the .NET 8 ASP.NET Core Runtime and configuring `appsettings.json`, start it from that directory:

```powershell
dotnet .\triosuite_invoice_erp_api.dll --urls "http://0.0.0.0:5112"
```

Keep this terminal/process running while the Android application is in use. SQL Server must also be running on the same computer, unless the connection string points to another reachable SQL Server.

## Demo data

The seed script creates the following initial data:

- Invoice statuses: `DRAFT`, `APPROVED`, `CANCELLED`
- Tax modes: `INCLUSIVE`, `EXCLUSIVE`
- Currencies: `JOD`, `USD`, `EUR`, `GBP`, `SAR`, `AED`
- Units: `PCS`, `BOX`, `KG`, `LTR`, `HOUR`
- Three demo customers
- Four inventory items and one service item
- Initial company settings with `JOD` as the base currency
- Demo administrator account

Demo login credentials:

```text
Username: admin
Password: Admin@123
```

Change or remove the demo account before using this project in a production environment.

## Using the API

### Authentication flow

1. Call `POST /api/auth/login` with the demo credentials.
2. Copy the `token` value from the response.
3. Send it with protected requests as `Authorization: Bearer YOUR_TOKEN`.
4. When the access token expires, call `POST /api/auth/refresh` with the refresh token.
5. Call `POST /api/auth/logout` to revoke the refresh-token family.

Example login request:

```bash
curl -X POST http://localhost:5112/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}'
```

### Swagger UI

Open `http://localhost:5112/swagger`, execute the login endpoint, then:

1. Copy the returned access token.
2. Select **Authorize**.
3. Enter the token in the bearer-authentication field.
4. Execute any protected endpoint directly from Swagger.

### Main endpoints

| Method | Endpoint | Authentication | Description |
|---|---|---:|---|
| `POST` | `/api/auth/login` | No | Login and issue access/refresh tokens |
| `POST` | `/api/auth/refresh` | No | Rotate a valid refresh token |
| `POST` | `/api/auth/logout` | No | Revoke the refresh-token family |
| `GET` | `/api/lookups` | Yes | Load customers, items, currencies, units, and tax modes |
| `GET` | `/api/lookups/items/barcode/{barcode}` | Yes | Find an active item by barcode |
| `GET` | `/api/invoices` | Yes | List invoices; supports `status` and `search` query parameters |
| `GET` | `/api/invoices/{id}` | Yes | Get an invoice and its lines |
| `POST` | `/api/invoices` | Yes | Create a draft invoice |
| `PUT` | `/api/invoices/{id}` | Yes | Update a draft invoice |
| `POST` | `/api/invoices/{id}/approve` | Yes | Approve a draft invoice |
| `POST` | `/api/invoices/{id}/cancel` | Yes | Cancel an invoice with a reason |
| `GET` | `/api/settings` | Yes | Read company settings |
| `PUT` | `/api/settings` | Yes | Update company settings |

### Create an invoice

First call `GET /api/lookups` and use the returned IDs for the customer, currency, item, and unit. Then send a request such as:

```json
{
  "invoiceDate": "2026-09-08T10:00:00Z",
  "customerId": 1,
  "currencyId": 1,
  "exchangeRate": 1,
  "taxMode": "EXCLUSIVE",
  "notesAr": "فاتورة تجريبية",
  "notesEn": "Demo invoice",
  "items": [
    {
      "itemId": 1,
      "unitId": 1,
      "quantity": 2,
      "unitPrice": 18,
      "taxRate": 16
    }
  ]
}
```

`INCLUSIVE` means the entered unit price already includes tax. `EXCLUSIVE` means tax is added to the entered unit price.

The included `triosuite_invoice_erp_api.http` file contains examples for login, lookups, invoice operations, and settings. It can be run from Visual Studio, JetBrains Rider, or VS Code with a compatible REST client extension.

## Database design

| Table | Responsibility |
|---|---|
| `Users` | API users and password hashes |
| `RefreshTokens` | Refresh-token rotation and revocation history |
| `Currencies` | Supported currencies and the base currency |
| `Units` | Units of measure |
| `SystemCodes` / `SystemCodeValues` | Invoice statuses and tax modes |
| `Customers` | Bilingual customer master data |
| `Items` | Bilingual item/service master data, barcode, price, and tax rate |
| `Settings` | Company name, default currency, and invoice prefix |
| `SalesInvoices` | Invoice header, totals, status, and audit fields |
| `SalesInvoiceItems` | Invoice lines and calculated tax totals |

All API database calls go through stored procedures. The database scripts use `CREATE OR ALTER` and existence checks, so they can be rerun during local setup without dropping existing tables or business data.

## Troubleshooting

### `A network-related or instance-specific error occurred`

- Verify that the SQL Server service is running.
- Confirm the server/instance name in the connection string.
- For SQL Express, try `localhost\SQLEXPRESS`.
- Confirm that the configured login has access to `SalesInvoiceDB`.

### `Login failed for user`

- Use `Trusted_Connection=True` only when the current Windows account has SQL Server access.
- Otherwise use a SQL login with `User Id` and `Password`.

### `Invalid object name` or `Could not find stored procedure`

Run all three database scripts again in the documented order and confirm that each script completes successfully.

### Swagger is not available

Swagger is enabled only in the `Development` environment. Run with the included launch profile or set:

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
dotnet run
```

### Port 5112 is already in use

Run on another port:

```powershell
dotnet run --urls http://localhost:5200
```

Then open `http://localhost:5200/swagger`.

### The API works on the computer but not on the Android phone

Check the following in order:

1. Confirm that the phone and computer are connected to the same non-guest network.
2. Run `ipconfig` again and confirm that Flutter uses the current IPv4 address.
3. Start the API with `--urls "http://0.0.0.0:5112"`; `dotnet run` using only `localhost` is not sufficient for a physical phone.
4. Confirm that the console says the API is listening on port `5112`.
5. Open `http://<API-PC-IP>:5112/swagger/index.html` from the phone's browser.
6. Check the Windows Firewall inbound rule for TCP port `5112` on Private networks.
7. Temporarily disconnect VPN software that may block local-network traffic.
8. Check whether the router has AP/client isolation enabled.

If Swagger opens on the phone but Flutter still fails, rebuild or reinstall the APK with exactly the same reachable address, including `/api/`:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://<API-PC-IP>:5112/api/
```

## Production checklist

- Replace the JWT signing key with a long random secret stored outside source control.
- Replace or disable the demo administrator account.
- Store database credentials in a secret manager or environment variables.
- Restrict the CORS policy to trusted front-end origins.
- Use HTTPS and a valid certificate.
- Apply least-privilege permissions to the API database login.
- Add centralized logging, monitoring, backups, and an appropriate deployment pipeline.

## License

No license has been specified for this repository. Add a license file before redistributing the project.
