# MuleSoft Customer & Orders

Mule 4.9.x + Anypoint Studio 7.21 + Java 17 starter integration.

## Automatic Excel and XML generation

The GitHub Actions workflow `.github/workflows/generate-customer-order-files.yml` generates these files every **5 minutes**:
- `customers_orders.xlsx` — Customers and Orders worksheets.
- `customers_orders.xml` — well-formed CustomerOrders XML.

The workflow generates and validates only the latest Excel and XML files, publishes them under `generated-files/`, and uploads the `customer-order-files` artifact (retained for 7 days). No timestamped archive copies are created. Generated-file commits are ignored by the workflow's push trigger, so they do not create a workflow loop.

## Automatically save generated files to your Windows PC

GitHub-hosted runners cannot write directly to your PC's `C:\` drive. To copy the cloud-generated files to your PC automatically, install the small Windows sync task once:

1. Open [install_local_sync.bat](https://raw.githubusercontent.com/Narsing-s/MuleSoft-Customer-Orders/main/install_local_sync.bat) and save it to your PC.
2. Double-click `install_local_sync.bat`. Approve the normal Windows script prompt if shown.
3. The installer creates a Windows Task Scheduler task named `MuleSoftCustomerOrdersCloudSync`, performs an initial sync, and checks GitHub every 2 minutes.

Only these two latest files are saved directly in the input folder:

`C:\Users\91938\Desktop\mulesoft file processing input data\customers_orders.xlsx`

`C:\Users\91938\Desktop\mulesoft file processing input data\customers_orders.xml`

No GitHub token, Anypoint password, repository secret, paid service, or Python installation is needed for the sync task. The repository must be publicly readable for this credential-free raw-file sync method. The sync log is at `%LOCALAPPDATA%\MuleSoftCustomerOrders\cloud-sync.log`.

To remove the task, run:
```powershell
schtasks.exe /Delete /TN MuleSoftCustomerOrdersCloudSync /F
```

**Timing:** cloud generation runs every 5 minutes (GitHub's minimum scheduled interval); the Windows task checks for the latest files every 2 minutes. If the PC is offline, GitHub continues generating files. When the PC reconnects and the user is logged in, the next successful sync downloads the latest Excel and XML pair. Intermediate versions generated while offline are not retained.

## Optional: process the files with MuleSoft and MySQL

The Mule application is a separate, optional step. It polls the input folder every five seconds, reads XLSX/XML, transforms records with DataWeave, upserts customers and orders into MySQL, writes JSON receipts under the output folder, and archives picked-up source files under the input folder's `_archive` directory.

1. Install Java 17, Anypoint Studio 7.21, Mule Runtime 4.9.x, and MySQL 8.
2. Execute `database/schema.sql` in MySQL Workbench.
3. Import `mule-app` into Studio as an existing Maven project and resolve connector dependencies.
4. Supply the MySQL connection username and password locally through Studio Run Configurations as JVM system properties named `mysql.username` and `mysql.password`. **Do not commit credentials, passwords, or secret files to this repository.**
5. Run the Mule application. The sync task places generated XLSX/XML files in the configured input folder.

The optional Mule flow writes successful receipts to output `processed\`, failed receipts to output `failed\`, and moves source files to input `_archive\`.

## File structure

- `.github/workflows/generate-customer-order-files.yml`: cloud generation and publishing.
- `install_local_sync.bat`: one-time Windows sync installer.
- `scripts/sync_generated_files.ps1`: two-minute cloud-to-PC sync task.
- `generator/generate_all.py`: creates the XLSX and XML files.
- `database/schema.sql`: MySQL schema.
- `mule-app/pom.xml`: Mule Maven application.

## Notes

- XLSX is supported; legacy `.xls` is not.
- The File Listener polls; it is not an operating-system filesystem event hook.
- Customer and order bulk upserts are sequential operations, not one cross-table transaction. Add transaction handling and audit/idempotency tables before production use.
- Connector patch versions may need adjustment for your Anypoint Exchange access and Studio compatibility.
- The Mule runtime build and database connectivity still need to be verified on your workstation.
