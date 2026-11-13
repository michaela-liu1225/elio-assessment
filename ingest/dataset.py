"""Explicit source contract: no inferred types or silently added columns."""
from pathlib import Path
import csv
import hashlib

TABLES = {
    'orders': ('olist_orders_dataset.csv', [
        'order_id', 'customer_id', 'order_status', 'order_purchase_timestamp',
        'order_approved_at', 'order_delivered_carrier_date',
        'order_delivered_customer_date', 'order_estimated_delivery_date']),
    'order_items': ('olist_order_items_dataset.csv', [
        'order_id', 'order_item_id', 'product_id', 'seller_id',
        'shipping_limit_date', 'price', 'freight_value']),
    'customers': ('olist_customers_dataset.csv', [
        'customer_id', 'customer_unique_id', 'customer_zip_code_prefix',
        'customer_city', 'customer_state']),
    'products': ('olist_products_dataset.csv', [
        'product_id', 'product_category_name', 'product_name_lenght',
        'product_description_lenght', 'product_photos_qty', 'product_weight_g',
        'product_length_cm', 'product_height_cm', 'product_width_cm']),
    'payments': ('olist_order_payments_dataset.csv', [
        'order_id', 'payment_sequential', 'payment_type',
        'payment_installments', 'payment_value']),
    'reviews': ('olist_order_reviews_dataset.csv', [
        'review_id', 'order_id', 'review_score', 'review_comment_title',
        'review_comment_message', 'review_creation_date', 'review_answer_timestamp']),
    'category_translation': ('product_category_name_translation.csv', [
        'product_category_name', 'product_category_name_english']),
}


def preflight(path: Path, expected_columns: list[str]) -> dict:
    """Fail on malformed CSV/UTF-8; allow a UTF-8 BOM in the header only."""
    count = 0
    with path.open(encoding='utf-8-sig', newline='') as file:
        reader = csv.reader(file, strict=True)
        header = next(reader)
        if header != expected_columns:
            raise ValueError(f'{path.name}: unexpected header {header!r}')
        for row in reader:
            count += 1
            if len(row) != len(header):
                raise ValueError(f'{path.name}: record {count} has {len(row)} columns; expected {len(header)}')
    if not count:
        raise ValueError(f'{path.name}: empty source file')
    return {'file': path.name, 'rows': count, 'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
