# MuleSoft Customer & Orders

Mule 4.9.x + Anypoint Studio 7.21 + Java 17 starter integration.

## Automatic local file generation through GitHub Actions

The workflow `.github/workflows/generate-customer-order-files.yml` runs on a **Windows self-hosted GitHub Actions runner** and writes the files directly to:

- Input: `C:\\Users\\91938\\Desktop\\mulesoft file processing input data`

It creates genuine files:
- `customers_orders.xlsx` — Customers and Orders worksheets.
- `customers_orders.xml` — a well-formed XML document with Customers and Orders records.

**One-time Windows setup is required.** GitHub-hosted runners cannot access your PC's C: drive. To let a workflow write there, register your Windows PC as a self-hosted runner:

1. On your Windows PC, install Python 3.10+ and ensure `python` works in PowerShell.
2. Open this repository on GitHub, then go to **Settings → Actions → Runners → New self-hosted runner**.
3. Select **Windows** and **x64**. Follow GitHub's displayed instructions to download and extract the runner into a persistent folder, for example `C:\\actions-runner`.
4. In PowerShell opened in that runner folder, run the exact `config.cmd` command GitHub displays. The registration token is temporary; obtain it from GitHub's page and do not save it in this repository or share it.
5. Complete runner configuration. For automatic operation after reboot, install and start the runner as a Windows service using the commands shown by GitHub (typically `.\svc install` and `.\svc start` from an elevated PowerShell window).
6. Keep the computer powered on and connected to the internet. The workflow then runs on the PC and writes both files directly into the input folder.

The workflow schedule is every **5 minutes**, which is GitHub Actions' minimum supported scheduled interval. It also runs on pushes to `main` and can be started manually from the Actions tab. The workflow verifies that the XLSX exists and parses the XML after generation.

Do not put runner registration tokens, passwords, or other credentials in repository files. The runner service runs under its configured Windows account, which must have write access to the input folder.

## Optional: process the files with MuleSoft and MySQL

The Mule application is a separate, optional step. It polls the input folder every five seconds, reads XLSX/XML, transforms records with DataWeave, upserts customers and orders into MySQL, writes JSON receipts under the output folder, and archives picked-up source files under the input folder's `_archive` directory.

1. Install Java 17, Anypoint Studio 7.21, Mule Runtime 4.9.x, and MySQL 8.
2. Execute `database/schema.sql` in MySQL Workbench.
3. Import `mule-app` into Studio as an existing Maven project and resolve connector dependencies.
4. Supply the MySQL connection username and password locally through Studio Run Configurations as JVM system properties named `mysql.username` and `mysql.password`. **Do not commit credentials, passwords, or secret files to this repository.**
5. Run the Mule application. New XLSX/XML files placed in the input folder will be picked up by the poller.

The optional Mule flow writes successful receipts to output `processed\`, failed receipts to output `failed\`, and moves source files to input `_archive\`.

## File structure

- `setup_windows.bat`: creates local folders, generates the first pair, and installs the scheduled task.
- `install_auto_generator.bat` / `install_auto_generator.ps1`: install the two-minute task.
- `uninstall_auto_generator.bat`: remove the task.
- `run_generator_scheduled.ps1`: scheduled generator and log writer.
- `generator/generate_all.py`: creates the XLSX and XML files.
- `database/schema.sql`: MySQL schema for the optional integration.
- `mule-app/pom.xml`: Mule Maven application.
- `mule-app/src/main/mule/customer-order-file-processing.xml`: Mule processing flow.

## Notes

- XLSX is supported; legacy `.xls` is not.
- GitHub-hosted Actions cannot directly write to this local Windows folder. A self-hosted runner is not required for this local scheduled-task approach.
- The File Listener polls; it is not an operating-system filesystem event hook.
- Customer and order bulk upserts are sequential operations, not one cross-table transaction. Add transaction handling and audit/idempotency tables before production use.
- Connector patch versions may need adjustment for your Anypoint Exchange access and Studio compatibility.
- The Mule runtime build and database connectivity still need to be verified on your workstation.
