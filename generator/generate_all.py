from pathlib import Path
import os
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
    create_excel(INPUT_DIR / "customers_orders.xlsx")
    create_xml(INPUT_DIR / "customers_orders.xml")
    print(f"Created customers_orders.xlsx and customers_orders.xml directly in {INPUT_DIR}")

if __name__ == "__main__":
    main()
