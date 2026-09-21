-- iТочка: анализ e-commerce
-- Шаг 1. Проверка качества данных

SELECT 'products' AS table_name, COUNT(*) AS row_count
FROM products

UNION ALL

SELECT 'customers', COUNT(*)
FROM customers

UNION ALL

SELECT 'sessions', COUNT(*)
FROM sessions

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'payments', COUNT(*)
FROM payments

UNION ALL

SELECT 'marketing_spend', COUNT(*)
FROM marketing_spend;

--Результат:
--products: 94
--customer: 10000
--sessions: 84934
--orders: 5803
--order_items: 7419
--payments: 5803
--marketing_spend: 1038
--Вывод: все таблицы загружены, кол-во строк соответствует исходным файлам

--Шаг 2: проверяем дубли по ключам

SELECT
    'products' AS table_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT product_id) AS unique_id,
    COUNT(*) - COUNT(DISTINCT product_id) AS duplicates_count
FROM
    products
    
UNION ALL

SELECT
    'customers',
    COUNT(*) ,
    COUNT(DISTINCT customer_id),
    COUNT(*) - COUNT(DISTINCT customer_id)
FROM
    customers
    
UNION ALL

SELECT
    'sessions',
    COUNT(*) ,
    COUNT(DISTINCT session_id),
    COUNT(*) - COUNT(DISTINCT session_id)
FROM
    sessions
    
UNION ALL

SELECT
    'orders',
    COUNT(*) ,
    COUNT(DISTINCT order_id),
    COUNT(*) - COUNT(DISTINCT order_id)
FROM
    orders
    
UNION ALL

SELECT
    'order_items',
    COUNT(*) ,
    COUNT(DISTINCT order_item_id),
    COUNT(*) - COUNT(DISTINCT order_item_id)
FROM
    order_items
    
UNION ALL

SELECT
    'payments',
    COUNT(*) ,
    COUNT(DISTINCT payment_id),
    COUNT(*) - COUNT(DISTINCT payment_id)
FROM
    payments
    
UNION ALL

SELECT
    'marketing_spend',
    COUNT(*) ,
    COUNT(DISTINCT spend_id),
    COUNT(*) - COUNT(DISTINCT spend_id)
FROM
    marketing_spend;

--Результат: дубли по первичным ключам не обнаружены

--Шаг 3: Проверяем целостность связей между таблицами

SELECT
    COUNT(*) AS missing_customers
FROM
    orders o
LEFT JOIN customers c ON
    o.customer_id = c.customer_id
WHERE
    c.customer_id IS NULL;

--Вывод: найдено 981 заказов без customer_id

--Проверяем гостевые заказы

SELECT
    COUNT(*) AS guest_orders
FROM
    orders
WHERE
    customer_id IS NULL;

--Итог: 981

--Проверяем битые ссылки

SELECT
    COUNT(*) AS orphan_customers
FROM
    orders o
LEFT JOIN customers c ON
    o.customer_id = c.customer_id
WHERE
    o.customer_id IS NOT NULL
    AND c.customer_id IS NULL;
    
--Итог: 0

--Вывод:
--981 заказ оформлен без customer_id (гостевые покупки)
--Битых ссылок на несуществующих клиентов не обнаружено

--Проверяем существуют ли клиенты

SELECT
    COUNT(*) AS orphan_session_customers
FROM
    sessions s
LEFT JOIN customers c ON
    s.customer_id = c.customer_id
WHERE
    s.customer_id IS NOT NULL
    AND c.customer_id IS NULL;
--результат: 0

SELECT
    COUNT(*) AS orphan_order_sessions
FROM
    orders o
LEFT JOIN sessions s
    ON
    o.session_id = s.session_id
WHERE
    s.session_id IS NULL;
--результат: 0

--Вывод:
--Битых ссылок между связанными таблицами не обнаружено
--NULL в customer_id у части orders/sessions является допустимым:
--это гостевые заказы и неавторизованные сессии

--Шаг 4. Проверяем пропуски (NULL)

SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN session_id IS NULL THEN 1 ELSE 0 END) AS null_session_id,
    SUM(CASE WHEN order_datetime IS NULL THEN 1 ELSE 0 END) AS null_order_datetime,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_order_status,
    SUM(CASE WHEN final_amount IS NULL THEN 1 ELSE 0 END) AS null_final_amount
FROM orders;

-- Вывод:
-- В orders найдено 981 NULL в customer_id.
-- Это гостевые заказы, поэтому пропуски допустимы.
-- В session_id, order_datetime, order_status и final_amount пропусков нет.

SELECT
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END) AS null_campaign_id,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN session_start IS NULL THEN 1 ELSE 0 END) AS null_session_start,
    SUM(CASE WHEN device_type IS NULL THEN 1 ELSE 0 END) AS null_device_type,
    SUM(CASE WHEN channel IS NULL THEN 1 ELSE 0 END) AS null_channel
FROM sessions;


--Проверяем платежи

SELECT
    COUNT(*) AS total_payments,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN payment_datetime IS NULL THEN 1 ELSE 0 END) AS null_payment_datetime,
    SUM(CASE WHEN payment_method IS NULL THEN 1 ELSE 0 END) AS null_payment_method,
    SUM(CASE WHEN payment_status IS NULL THEN 1 ELSE 0 END) AS null_payment_status,
    SUM(CASE WHEN failure_reason IS NULL THEN 1 ELSE 0 END) AS null_failure_reason,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS null_amount
FROM payments;

--Обнаружили сбои в кол-ве 5033

--роверяем есть ли неуспешные платежи, для которыхотсутствует причина

SELECT
    COUNT(*) AS failed_without_reason
FROM
    payments
WHERE
    payment_status = 'failed'
    AND failure_reason IS NULL;

--Результат 0.

--Но нужно проверить успешные платежи, для которых возможно записана причина ошибки

SELECT
    COUNT(*) AS success_with_failure_reason
FROM
    payments
WHERE
    payment_status = 'success'
    AND failure_reason IS NOT NULL;

--Результат 0
--Вывод: противоречий между статусом платежей и причинами сбоя нет

--Проверяем сумму платежа против суммы заказа

SELECT
    COUNT(*) AS amount_mismatch
FROM
    payments p
INNER JOIN orders o
    ON
    p.order_id = o.order_id
WHERE
    p.amount != o.final_amount;

--Результат 0. Суммы между таблицами согласованны

-- Шаг 5. Проверяем диапазоны поведенческих метрик sessions

SELECT
    MIN(product_views) AS min_product_views,
    MAX(product_views) AS max_product_views,
    MIN(add_to_cart) AS min_add_to_cart,
    MAX(add_to_cart) AS max_add_to_cart,
    MIN(checkout_started) AS min_checkout_started,
    MAX(checkout_started) AS max_checkout_started,
    MIN(purchase_completed) AS min_purchase_completed,
    MAX(purchase_completed) AS max_purchase_completed
FROM sessions;

--Результат
--min_product_views = 1
--max_product_views = 12
--min_add_to_cart = 0
--max_add_to_cart = 1
--min_checkout_started = 0
--max_checkout_started = 1
--min_purchase_completed = 0
--max_purchase_completed = 1

-- Проверяем какие комбинации состояний реально существуют

SELECT
    DISTINCT
    add_to_cart,
    checkout_started,
    purchase_completed
FROM
    sessions
ORDER BY
    add_to_cart,
    checkout_started,
    purchase_completed;

-- Вывод:
-- Поведенческие флаги sessions принимают ожидаемые значения 0/1.
-- Некорректных последовательностей воронки не обнаружено:
-- checkout не происходит без add_to_cart,
-- purchase не происходит без checkout.

-- Отсекаем два потенциальных противоречия
-- purchase_completed против order_id

SELECT
    SUM(
        CASE
            WHEN purchase_completed = 1
                 AND order_id IS NULL
            THEN 1
            ELSE 0
        END
    ) AS purchase_without_order,
    SUM(
        CASE
            WHEN purchase_completed = 0
                 AND order_id IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS order_without_purchase
FROM
sessions;

--Результат: 944 заказа без покупки

--Раскладываем их по статусам заказа и платежа

SELECT
    o.order_status,
    p.payment_status,
    COUNT(*) AS sessions_count
FROM
    sessions s
INNER JOIN orders o
    ON
    s.order_id = o.order_id
LEFT JOIN payments p
    ON
    o.order_id = p.order_id
WHERE
    s.purchase_completed = 0
    AND s.order_id IS NOT NULL
GROUP BY
    o.order_status,
    p.payment_status
ORDER BY
    sessions_count DESC;

-- Вывод:
-- Обнаружено 944 сессии с order_id, но purchase_completed = 0.
-- 633 из них связаны с заказами payment_failed и платежами failed —
-- это соответствует ожидаемой бизнес-логике.
--
-- Ещё 311 случаев относятся к returned/refunded и cancelled/refunded.
-- Для их интерпретации необходимо уточнить семантику purchase_completed:
-- отражает ли поле факт успешного checkout в момент сессии
-- или итоговое состояние покупки после возвратов/отмен.
--
-- Data assumption:
-- purchase_completed показывает факт успешного завершения покупки в рамках сессии. Последующий возврат/отмена не меняет этот факт.
--
-- Обнаружено 311 потенциально некорректных значений purchase_completed:
-- returned/refunded  = 174
-- cancelled/refunded = 137
--
-- Исходные данные не изменяем.
-- При дальнейшем расчёте воронки потребуется скорректированный purchase-флаг.

-- Проверяем математическую согласованность заказов и товаров

SELECT
    COUNT(*) AS incorrect_order_amounts
FROM
    orders
WHERE
    final_amount
      != gross_amount - discount_amount + delivery_fee;

-- Вывод:
-- Несогласованностей в расчёте итоговой суммы заказа не обнаружено.
-- final_amount корректно рассчитывается как
-- gross_amount - discount_amount + delivery_fee.

-- Проверяем согласованность суммы заказа с деталями из order_items

SELECT
    COUNT(*) AS gross_amount_mismatch
FROM
    orders o
INNER JOIN (
    SELECT
        order_id,
        SUM(quantity * unit_price) AS items_gross
    FROM
        order_items
    GROUP BY
        order_id
) oi
    ON
    o.order_id = oi.order_id
WHERE
    o.gross_amount != oi.items_gross;

-- Вывод:
-- Расхождений между orders.gross_amount и суммой товарных позиций
-- из order_items не обнаружено.

-- Проверяем скидки

SELECT
    COUNT(*) AS discount_mismatch
FROM
    orders o
INNER JOIN (
    SELECT
        order_id,
        SUM(line_amount) AS items_after_discount
    FROM
        order_items
    GROUP BY
        order_id
) items_summary
    ON
    o.order_id = items_summary.order_id
WHERE
    o.discount_amount
      <> o.gross_amount - items_summary.items_after_discount;

-- Со скидками тоже все хорошо. В итоге деньги не "рассыпаются" между таблицами

-- Проверяем последний уровень арифметики внутри order_items:
-- корректно ли рассчитана каждая отдельная строка товара
-- с учетом discount_pct

SELECT
    COUNT(*) AS line_amount_mismatch
FROM
    order_items
WHERE
    line_amount
      <> ROUND(
          quantity * unit_price * (1 - discount_pct / 100.0)
      );

-- Вывод:
-- Обнаружено 298 расхождений line_amount с расчётной формулой PostgreSQL.
-- Все расхождения составляют 1 рубль и возникают при discount_pct = 5%.
-- Причина — различие правил округления значений x.5 между источником
-- и PostgreSQL ROUND().
-- Данные считаем корректными с учётом политики округления источника.

-- Шаг 6. Проверяем период данных

SELECT
    'sessions' AS table_name,
    MIN(session_start::date) AS min_date,
    MAX(session_start::date) AS max_date
FROM sessions

UNION ALL

SELECT
    'orders',
    MIN(order_datetime::date),
    MAX(order_datetime::date)
FROM orders

UNION ALL

SELECT
    'payments',
    MIN(payment_datetime::date),
    MAX(payment_datetime::date)
FROM payments

UNION ALL

SELECT
    'marketing_spend',
    MIN(spend_date),
    MAX(spend_date)
FROM marketing_spend;

-- Во временной период попал сентябрь
-- Проверяем конкретные сентябрьские платежи
-- и связанные с ним заказы

SELECT
    p.payment_id,
    p.order_id,
    o.order_datetime,
    p.payment_datetime,
    p.payment_status,
    p.amount
FROM
    payments p
INNER JOIN orders o
    ON
    p.order_id = o.order_id
WHERE
    p.payment_datetime::date >= '2024-09-01'
ORDER BY
    p.payment_datetime;

-- Вывод:
-- В payments обнаружен 1 платёж от 2024-09-01.
-- Он относится к заказу, созданному 2024-08-31 23:58:17,
-- и был проведён через 5 минут после создания заказа.
-- Выход за границу периода объясняется нормальным жизненным циклом заказа.

-- Проверяем, не бывает ли платежей раньше создания заказа

SELECT
    COUNT(*) AS payment_before_order
FROM
    payments p
INNER JOIN orders o
    ON
    p.order_id = o.order_id
WHERE
    p.payment_datetime < o.order_datetime;

-- Вывод:
-- Платежей, проведённых раньше создания соответствующего заказа, не обнаружено.
-- Хронология order_datetime → payment_datetime соблюдается.

-- Проверяем полную последовательность сессия -> заказ -> платеж

SELECT
    COUNT(*) AS order_before_session
FROM
    orders o
INNER JOIN sessions s
    ON
    o.session_id = s.session_id
WHERE
    o.order_datetime < s.session_start;

----------------------------------------------

SELECT
    COUNT(*) AS invalid_timeline
FROM
    orders o
INNER JOIN sessions s
    ON
    o.session_id = s.session_id
INNER JOIN payments p
    ON
    o.order_id = p.order_id
WHERE
    o.order_datetime < s.session_start
    OR p.payment_datetime < o.order_datetime;

-- Вывод:
-- Нарушений временной последовательности не обнаружено.
-- Заказы не создаются раньше начала сессии,
-- платежи не проводятся раньше создания заказа.

-- Проверка невозможных и подозрительных значений:
-- Отрицательные цены
-- Отрицательные выручки
-- Отрицательные рекламные расходы 
-- и т.д.

SELECT
    SUM(CASE WHEN list_price <= 0 THEN 1 ELSE 0 END) AS bad_product_prices,
    SUM(CASE WHEN cost_price < 0 THEN 1 ELSE 0 END) AS bad_cost_prices
FROM products;

SELECT
    SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END) AS bad_quantity,
    SUM(CASE WHEN unit_price <= 0 THEN 1 ELSE 0 END) AS bad_unit_price,
    SUM(CASE WHEN discount_pct < 0 OR discount_pct > 100 THEN 1 ELSE 0 END) AS bad_discount
FROM order_items;

SELECT
    SUM(CASE WHEN impressions < 0 THEN 1 ELSE 0 END) AS bad_impressions,
    SUM(CASE WHEN clicks < 0 THEN 1 ELSE 0 END) AS bad_clicks,
    SUM(CASE WHEN spend_rub < 0 THEN 1 ELSE 0 END) AS bad_spend,
    SUM(CASE WHEN clicks > impressions THEN 1 ELSE 0 END) AS clicks_over_impressions
FROM marketing_spend;

-- Все показатели в норме

-- Итоговый вывод по качеству данных:
-- Критических ошибок, нарушений связей, хронологии и финансовой логики не обнаружено.
-- Найдены только объяснимые особенности:
-- гостевые/анонимные сессии и заказы,
-- один платёж, перешедший через границу месяца,
-- различие правил округления line_amount на 1 рубль в части строк,
-- а также неоднозначность purchase_completed для возвращённых/отменённых заказов.