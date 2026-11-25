# MuleSoft Customer & Orders

Mule 4.9.x + Anypoint Studio 7.21 + Java 17 starter integration.

## Automatic local file generation every 2 minutes

The repository can generate a fresh Excel workbook and XML file directly on your Windows computer every 2 minutes. This uses Windows Task Scheduler, not a GitHub-hosted runner, because a hosted workflow cannot write directly to your computer's C: drive.

Default folders:

- Input: `C:\Users\91938\Desktop\mulesoft file processing input data`
- Output: `C:\Users\91938\Desktop\mulesoft file processing output`

One-time setup:

1. Download or clone this repository to your Windows 11 computer.
2. Install Python 3.10+ and ensure `python` is available in Command Prompt.
3. Double-click `setup_windows.bat`. It creates the folders, installs openpyxl, generates the first file pair, and registers a Windows scheduled task named `MuleSoftCustomerOrdersFileGenerator`.
4. Leave the repository folder in place. Windows Task Scheduler runs the generator every 2 minutes and recreates:
   - `customers_orders.xlsx` — Customers and Orders worksheets.
   - `customers_orders.xml` — matching Customers and Orders records.
5. MuleSoft's File Listener can pick up each newly generated pair when the Mule application is running.

You can install or reinstall only the scheduled task by double-clicking `install_auto_generator.bat`. To stop automatic generation, double-click `uninstall_auto_generator.bat`. Generation logs are written to `generator\generator.log`.

The task runs under the Windows account that installs it. Keep the repository folder available and ensure that account can write to the input folder. The computer must be powered on and Windows Task Scheduler must be running; the task does not run while the computer is shut down.

To generate a pair manually, run `generator\run_generator.bat`. The Python script writes temporary files and renames them after completion.

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
