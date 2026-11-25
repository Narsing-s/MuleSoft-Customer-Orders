from pathlib import Path
from datetime import datetime, timezone
import json
import os
import shutil
import xml.etree.ElementTree as ET
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill
from openpyxl.utils import get_column_letter

INPUT_DIR = Path(os.getenv("MULE_INPUT_DIR", r"C:\Users\91938\Desktop\mulesoft file processing input data"))

CUSTOMERS = [
    {"customerId":"CUST1001","firstName":"Aarav","lastName":"Sharma","email":"aarav.sharma@example.com","phone":"9000001001","city":"Hyderabad"},
    {"customerId":"CUST1002","firstName":"Diya","lastName":"Reddy","email":"diya.reddy@example.com","phone":"9000001002","city":"Visakhapatnam"},
    {"customerId":"CUST1003","firstName":"Kabir","lastName":"Patel","email":"kabir.patel@example.com","phone":"9000001003","city":"Bengaluru"},
    {"customerId":"CUST1004","firstName":"Anaya","lastName":"Iyer","email":"anaya.iyer@example.com","phone":"9000001004","city":"Chennai"},
    {"customerId":"CUST1005","firstName":"Vihaan","lastName":"Kumar","email":"vihaan.kumar@example.com","phone":"9000001005","city":"Pune"},
]
ORDERS = [
    {"orderId":"ORD2001","customerId":"CUST1001","orderDate":"2026-11-20","status":"PLACED","totalAmount":2499.00},
    {"orderId":"ORD2002","customerId":"CUST1002","orderDate":"2026-11-21","status":"SHIPPED","totalAmount":1599.50},
    {"orderId":"ORD2003","customerId":"CUST1003","orderDate":"2026-11-22","status":"DELIVERED","totalAmount":899.00},
    {"orderId":"ORD2004","customerId":"CUST1004","orderDate":"2026-11-23","status":"PROCESSING","totalAmount":3299.99},
    {"orderId":"ORD2005","customerId":"CUST1005","orderDate":"2026-11-24","status":"PLACED","totalAmount":499.00},
]

def atomic_replace(temp: Path, destination: Path):
    os.replace(temp, destination)

def create_excel(destination: Path):
    wb = Workbook()
    ws = wb.active
    ws.title = "Customers"
    headers = list(CUSTOMERS[0])
    ws.append(headers)
    for row in CUSTOMERS:
        ws.append([row[h] for h in headers])
    orders = wb.create_sheet("Orders")
    headers = list(ORDERS[0])
    orders.append(headers)
    for row in ORDERS:
        orders.append([row[h] for h in headers])
    for sheet in wb.worksheets:
        sheet.freeze_panes = "A2"
        sheet.auto_filter.ref = sheet.dimensions
        for cell in sheet[1]:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill("solid", fgColor="1F4E78")
        for col in sheet.columns:
            sheet.column_dimensions[get_column_letter(col[0].column)].width = min(max(len(str(c.value or "")) for c in col) + 3, 32)
    temp = destination.with_name(destination.stem + ".writing" + destination.suffix)
    wb.save(temp)
    atomic_replace(temp, destination)

def create_xml(destination: Path):
    root = ET.Element("CustomerOrders")
    customer_root = ET.SubElement(root, "Customers")
    for row in CUSTOMERS:
        node = ET.SubElement(customer_root, "Customer")
        for key, value in row.items():
            ET.SubElement(node, key).text = str(value)
    order_root = ET.SubElement(root, "Orders")
    for row in ORDERS:
        node = ET.SubElement(order_root, "Order")
        for key, value in row.items():
            ET.SubElement(node, key).text = str(value)
    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    temp = destination.with_name(destination.stem + ".writing" + destination.suffix)
    tree.write(temp, encoding="utf-8", xml_declaration=True)
    atomic_replace(temp, destination)

def main():
    INPUT_DIR.mkdir(parents=True, exist_ok=True)
    archive_dir = INPUT_DIR / "archive"
    archive_dir.mkdir(exist_ok=True)

    # One UTC identifier groups the Excel/XML pair from this generation.
    generated_at = datetime.now(timezone.utc)
    version_id = generated_at.strftime("%Y%m%dT%H%M%S%fZ")
    latest_xlsx = INPUT_DIR / "customers_orders.xlsx"
    latest_xml = INPUT_DIR / "customers_orders.xml"
    archive_xlsx_name = f"customers_orders_{version_id}.xlsx"
    archive_xml_name = f"customers_orders_{version_id}.xml"
    archive_xlsx = archive_dir / archive_xlsx_name
    archive_xml = archive_dir / archive_xml_name

    create_excel(latest_xlsx)
    create_xml(latest_xml)
    shutil.copy2(latest_xlsx, archive_xlsx)
    shutil.copy2(latest_xml, archive_xml)

    manifest_path = archive_dir / "manifest.json"
    entries = []
    if manifest_path.exists():
        try:
            entries = json.loads(manifest_path.read_text(encoding="utf-8")).get("versions", [])
        except (json.JSONDecodeError, AttributeError, TypeError):
            entries = []
    entries.append({
        "id": version_id,
        "generatedAtUtc": generated_at.isoformat(),
        "xlsx": f"archive/{archive_xlsx_name}",
        "xml": f"archive/{archive_xml_name}",
    })
    manifest = {"schemaVersion": 1, "versions": entries}
    temp_manifest = archive_dir / "manifest.writing.json"
    temp_manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    atomic_replace(temp_manifest, manifest_path)

    print(f"Created latest files in {INPUT_DIR}")
    print(f"Archived generation {version_id} in {archive_dir}")
    print(f"Manifest contains {len(entries)} generation(s)")

if __name__ == "__main__":
    main()
