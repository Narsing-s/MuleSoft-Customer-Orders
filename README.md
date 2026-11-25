# MuleSoft Customer & Orders

Mule 4.9.x + Anypoint Studio 7.21 + Java 17 starter integration.

## Generate the input files on your Windows computer

You can use this repository just to generate the sample files. **Python creates the Excel and XML files directly on your computer; MuleSoft, MySQL, and database credentials are not required for this generation step.**

The default folders are:

- Input: `C:\Users\91938\Desktop\mulesoft file processing input data`
- Output: `C:\Users\91938\Desktop\mulesoft file processing output`

Steps:

1. Download or clone this repository to your Windows 11 computer.
2. Make sure Python 3.10 or newer is installed and available as `python` in Command Prompt.
3. Double-click `setup_windows.bat` in the repository folder.
4. The script creates the input/output folders, installs the Python dependency, and generates:
   - `customers_orders.xlsx` — Customers and Orders worksheets.
   - `customers_orders.xml` — matching Customers and Orders XML records.
5. Find both generated files in `C:\Users\91938\Desktop\mulesoft file processing input data`.

To generate a fresh pair later, double-click `generator\run_generator.bat` or run `python generator\generate_all.py` from the repository root. Existing files with the same names are replaced after each new file is fully written.

You can change the input location without editing the script by setting the `MULE_INPUT_DIR` environment variable before running the generator. The default remains the exact folder above.

## Optional: process the files with MuleSoft and MySQL

The Mule application is a separate, optional step. It polls the input folder every five seconds, reads XLSX/XML, transforms the records with DataWeave, upserts customers and orders into MySQL, writes JSON receipts under the output folder, and archives picked-up source files under the input folder's `_archive` directory.

1. Install Java 17, Anypoint Studio 7.21, Mule Runtime 4.9.x, and MySQL 8.
2. Execute `database/schema.sql` in MySQL Workbench.
3. Import `mule-app` into Studio as an existing Maven project and resolve connector dependencies.
4. Supply the MySQL connection username and password locally through Studio Run Configurations as JVM system properties named `mysql.username` and `mysql.password`. **Do not commit credentials, passwords, or secret files to this repository.**
5. Run the Mule application. New XLSX/XML files placed in the input folder will be picked up by the poller.

The optional Mule flow writes successful receipts to output `processed\`, failed receipts to output `failed\`, and moves source files to input `_archive\`.

## File structure

- `setup_windows.bat`: creates the local folders and runs the generator.
- `generator/generate_all.py`: creates the XLSX and XML files.
- `generator/requirements.txt`: Python dependency list.
- `database/schema.sql`: MySQL schema for the optional integration.
- `mule-app/pom.xml`: Mule Maven application.
- `mule-app/src/main/mule/customer-order-file-processing.xml`: Mule processing flow.
- `mule-app/src/main/resources/application.properties`: local folder paths and non-secret database settings.

## Notes

- XLSX is supported; legacy `.xls` is not.
- The File Listener polls; it is not an operating-system filesystem event hook.
- The generator writes temporary files and renames them after completion to avoid Mule reading partially written files.
- Customer and order bulk upserts are sequential operations, not one cross-table transaction. Add transaction handling and audit/idempotency tables before production use.
- Connector patch versions may need adjustment for your Anypoint Exchange access and Studio compatibility.
- The Mule runtime build and database connectivity still need to be verified on your workstation.
