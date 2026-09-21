# iТочка — e-commerce portfolio dataset

Портфельный аналитический кейс на основе публично доступной бизнес-модели магазина iТочка (Челябинск).

**Важно:** транзакции, клиенты, сессии, платежи, маркетинговые показатели и цены за 2024 год являются синтетическими. Они не являются внутренними данными iТочки и не отражают фактические показатели компании. Публичная информация использована только как основа для структуры бизнеса, категорий, брендов, географии и сценария интернет-магазина.

Период данных: **2024-01-01 — 2024-08-31**.

## Таблицы
- `customers.csv` — клиенты и первичный канал привлечения.
- `sessions.csv` — сессии интернет-магазина и шаги воронки.
- `orders.csv` — заказы и их итоговые статусы.
- `order_items.csv` — товарные позиции внутри заказов.
- `products.csv` — каталог товаров.
- `payments.csv` — платежи и причины неуспеха.
- `marketing_spend.csv` — рекламные расходы и медиапоказатели.

## Связи
- `customers.customer_id` → `sessions.customer_id`, `orders.customer_id`
- `sessions.session_id` → `orders.session_id`
- `orders.order_id` → `order_items.order_id`, `payments.order_id`
- `products.product_id` → `order_items.product_id`
- `marketing_spend.campaign_id` ↔ `sessions.campaign_id` (для платных каналов)

## Публичная основа
- https://i-tochka.su/
- https://i-tochka.su/company/
