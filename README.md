# MuleSoft Customer & Orders

Mule 4.9.x + Anypoint Studio 7.21 + Java 17 starter integration.

## Automatic Excel and XML generation

The GitHub Actions workflow `.github/workflows/generate-customer-order-files.yml` runs automatically every **5 minutes** on a GitHub-hosted runner. No Windows runner, local installation, repository secret, or password is required.

Each successful run creates:
- `customers_orders.xlsx` — a real Excel workbook with Customers and Orders worksheets.
- `customers_orders.xml` — a well-formed XML document with Customers and Orders records.

Both files are published together as the GitHub Actions artifact **customer-order-files**, retained for 7 days.

To get the latest generated files:
1. Open the repository's **Actions** tab.
2. Select **Generate Customer and Order Files**.
3. Open the latest successful run.
4. In **Artifacts**, select **customer-order-files**. GitHub provides the ZIP containing the XLSX and XML files.

You can also start a run immediately using **Actions → Generate Customer and Order Files → Run workflow**. Scheduled runs use GitHub's 5-minute minimum interval and may be delayed during periods of high GitHub Actions load.

**Important:** A GitHub-hosted workflow runs in GitHub's cloud and cannot write directly to your Windows `C:\` drive. Therefore, the generated files are stored in the GitHub Actions artifact, not automatically in your local Desktop folders. Direct local writing requires a local runner or a separate local sync process.

Do not put passwords, tokens, or other credentials in this repository.

## Optional: process the files with MuleSoft and MySQL

The Mule application is a separate, optional step. It polls the input folder every five seconds, reads XLSX/XML, transforms records with DataWeave, upserts customers and orders into MySQL, writes JSON receipts under the output folder, and archives picked-up source files under the input folder's `_archive` directory.

1. Install Java 17, Anypoint Studio 7.21, Mule Runtime 4.9.x, and MySQL 8.
2. Execute `database/schema.sql` in MySQL Workbench.
3. Import `mule-app` into Studio as an existing Maven project and resolve connector dependencies.
4. Supply the MySQL connection username and password locally through Studio Run Configurations as JVM system properties named `mysql.username` and `mysql.password`. **Do not commit credentials, passwords, or secret files to this repository.**
5. Run the Mule application. Place the generated XLSX/XML files into the configured input folder for the Mule poller.

The optional Mule flow writes successful receipts to output `processed\\`, failed receipts to output `failed\\`, and moves source files to input `_archive\\`.

## File structure

- `setup_windows.bat`: creates local folders, generates the first pair, and installs the scheduled task.
- `install_auto_generator.bat` / `install_auto_generator.ps1`: install the local two-minute task.
- `uninstall_auto_generator.bat`: remove the task.
- `run_generator_scheduled.ps1`: scheduled generator and log writer.
- `generator/generate_all.py`: creates the XLSX and XML files.
- `database/schema.sql`: MySQL schema for the optional integration.
- `mule-app/pom.xml`: Mule Maven application.
- `mule-app/src/main/mule/customer-order-file-processing.xml`: Mule processing flow.

## Notes

- XLSX is supported; legacy `.xls` is not.
- The File Listener polls; it is not an operating-system filesystem event hook.
- Customer and order bulk upserts are sequential operations, not one cross-table transaction. Add transaction handling and audit/idempotency tables before production use.
- Connector patch versions may need adjustment for your Anypoint Exchange access and Studio compatibility.
- The Mule runtime build and database connectivity still need to be verified on your workstation.
