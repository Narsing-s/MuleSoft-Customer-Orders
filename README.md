# MuleSoft Customer & Orders

Mule 4.9.x + Anypoint Studio 7.21 + Java 17 starter integration.

## Flow
Python generates an XLSX workbook and XML file containing matching Customer and Order sample records. Mule's File Listener polls the configured Windows input folder every 5 seconds, normalizes either format with DataWeave, upserts customers and orders into MySQL, writes a JSON receipt to the output folder, and moves the source file into `_archive`.

## Exact folders
- Input: `C:/Users/91938/Desktop/mulesoft file processing input data`
- Output: `C:/Users/91938/Desktop/mulesoft file processing output`
- Archive: `C:/Users/91938/Desktop/mulesoft file processing input data/_archive`

## Setup
1. Install Python 3.10+, Java 17, Anypoint Studio 7.21, Mule Runtime 4.9.x, and MySQL 8.
2. Run `setup_windows.bat` from the repository root. It creates the folders, installs openpyxl, and generates `customers_orders.xlsx` and `customers_orders.xml`.
3. Execute `database/schema.sql` in MySQL Workbench.
4. Edit `mule-app/src/main/resources/application.properties` with your MySQL username/password.
5. Import the `mule-app` directory into Studio as an existing Maven project; resolve connector dependencies through Anypoint Exchange/Maven.
6. Select Java 17 and Mule 4.9.x, then run the application.
7. Run `generator/run_generator.bat` to create another pair of files. Mule polls every five seconds.

## Expected data
- `customers`: 5 customer rows
- `orders`: 5 order rows
- Successful JSON receipts: output `processed/`
- Failed JSON receipts: output `failed/`
- Picked-up source files: input `_archive/`

## File structure
- `generator/generate_all.py`: XLSX + XML generator
- `database/schema.sql`: MySQL schema
- `mule-app/pom.xml`: Maven Mule application
- `mule-app/src/main/mule/customer-order-file-processing.xml`: Mule flow
- `mule-app/src/main/resources/application.properties`: local paths and DB config

## Notes
- XLSX is supported; legacy .xls is not.
- The File Listener polls (it is not an OS filesystem event hook).
- Do not write a file into the input folder while it is still being generated. The Python script writes to a temporary file and renames it after completion.
- Customer and order bulk upserts are sequential operations, not one cross-table transaction. Add transaction handling and audit/idempotency tables before production use.
- Connector patch versions may need adjustment to match your Anypoint Exchange access and Studio's compatibility suggestions.
- This repo is a starter source implementation; runtime build and database connectivity must be verified on your workstation.
