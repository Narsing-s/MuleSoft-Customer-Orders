@echo off
python generate_all.py
if errorlevel 1 exit /b 1
echo Generated customers_orders.xlsx and customers_orders.xml.
