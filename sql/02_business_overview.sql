-- iТочка: анализ e-commerce
-- Этап 2. Обзор ключевых бизнес-показателей

-- Шаг 1. Разбираемся со статусами заказов

SELECT
    order_status,
    COUNT(*) AS orders_count,
    SUM(final_amount) AS total_amount
FROM
    orders
GROUP BY
    order_status
ORDER BY
    orders_count DESC;

-- completed       4859  154.926.844
-- payment_failed   633   20.226.477
-- returned         174    5.056.650
-- cancelled        137    3.738.713
--
-- Рабочее определение Revenue:
-- сумма final_amount только по заказам со статусом completed.
--
-- payment_failed не включаем: оплата не состоялась.
-- returned и cancelled не включаем: деньги возвращены клиенту.
-- в выручку (revenue) идет сумма 154.926.844

-- Считаем 4 метрики

SELECT
    SUM(final_amount) AS revenue,
    COUNT(*) AS completed_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(AVG(final_amount)) AS avg_order_value
FROM
    orders
WHERE
    order_status = 'completed';

-- Revenue = 154,9 млн ₽ — это фактическая выручка по успешно завершённым заказам за весь период.
-- Completed orders = 4 859 — сколько успешных заказов бизнес реально довёл до покупки.
-- Unique customers = 3 215 — столько уникальных идентифицированных покупателей совершили успешные покупки. Гостевые покупки сюда не входят.
-- Average order value ≈ 31 885 ₽ — средний чек успешного заказа

-- Считаем показатели по месяцам

SELECT
    DATE_TRUNC('month', order_datetime)::date AS MONTH,
    SUM(final_amount) AS revenue,
    COUNT(*) AS completed_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(AVG(final_amount), 2) AS avg_order_value
FROM
    orders
WHERE
    order_status = 'completed'
GROUP BY
    DATE_TRUNC('month', order_datetime)::date
ORDER BY
    MONTH;

-- Вывод:
-- С марта по июнь наблюдался устойчивый рост выручки,
-- пик достигнут в июне: 23,6 млн руб.
--
-- В июле выручка снизилась примерно на 24,8% относительно июня.
-- Одновременно снизились:
-- количество completed-заказов примерно на 13,7%;
-- число идентифицированных покупателей примерно на 12,7%;
-- средний чек примерно на 12,9%.
--
-- В августе наблюдается частичное восстановление,
-- однако показатели остаются существенно ниже июня.
--
-- Падение выручки связано одновременно со снижением
-- количества успешных заказов и среднего чека.
-- Причины этих изменений требуют дальнейшего анализа.

SELECT
    DATE_TRUNC('month', s.session_start)::date AS MONTH,
    COUNT(*) AS sessions,
    SUM(
    CASE
        WHEN o.order_status = 'completed' THEN 1
        ELSE 0
    END
) AS completed_orders,
    ROUND(
        SUM(
            CASE
                WHEN o.order_status = 'completed' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS conversion_rate
FROM
    sessions s
LEFT JOIN orders o ON
    s.order_id = o.order_id
GROUP BY
    DATE_TRUNC('month', s.session_start)::date
ORDER BY
    month;

-- Вывод:
-- В июле и августе количество сессий продолжает расти,
-- однако количество completed-заказов снижается.
--
-- Conversion Rate падает с 6,24% в июне
-- до 5,05% в июле и 4,99% в августе.
--
-- Следовательно, снижение количества заказов связано
-- не с падением трафика, а с ухудшением конверсии.
-- Необходимо определить, на каком сегменте или этапе воронки
-- происходит основная потеря пользователей.

SELECT
    DATE_TRUNC('month', s.session_start)::date AS MONTH,
    s.device_type,
    COUNT(*) AS sessions,
    SUM(
        CASE
            WHEN o.order_status = 'completed' THEN 1
            ELSE 0
        END
    ) AS completed_orders,
    ROUND(
        SUM(
            CASE
                WHEN o.order_status = 'completed' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS conversion_rate
FROM
    sessions s
LEFT JOIN orders o
    ON
    s.order_id = o.order_id
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    s.device_type
ORDER BY
    MONTH,
    s.device_type;

-- Вывод:
-- Основное падение conversion rate локализовано в mobile-сегменте.
-- Mobile CR снизился с 6,07% в июне до 4,56% в июле
-- и до 3,88% в августе.
-- Desktop после июльской просадки восстановился,
-- tablet показывает рост.
-- Mobile формирует около 64% всего трафика,
-- поэтому его просадка существенно влияет на общий CR.

-- Разбираем mobile-воронку

SELECT
    DATE_TRUNC('month', s.session_start)::date AS MONTH,
    COUNT(*) AS sessions,
    SUM(s.add_to_cart) AS add_to_cart,
    SUM(s.checkout_started) AS checkout_started,
    SUM(
        CASE
            WHEN o.order_status = 'completed' THEN 1
            ELSE 0
        END
    ) AS completed_orders
FROM
    sessions s
LEFT JOIN orders o
    ON
    s.order_id = o.order_id
WHERE
    s.device_type = 'mobile'
    AND s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date
ORDER BY
    month;

-- Вывод:
-- В mobile-сегменте ухудшение наблюдается на двух этапах воронки.
--
-- session → add_to_cart:
-- 13,28% в июне → 11,37% в июле → 11,43% в августе.
--
-- cart → checkout остаётся относительно стабильным:
-- около 55–57%.
--
-- Наиболее сильная просадка происходит на этапе checkout → purchase:
-- 80,58% в июне → 70,53% в июле → 61,54% в августе.
--
-- Основная причина падения mobile conversion, вероятно,
-- находится на финальном этапе оформления/оплаты заказа.

-- Проверяем платежи по сегментам

SELECT
    DATE_TRUNC('month', s.session_start)::date AS MONTH,
    s.device_type,
    COUNT(p.payment_id) AS payment_attempts,
    SUM(
        CASE
            WHEN p.payment_status = 'failed' THEN 1
            ELSE 0
        END
    ) AS failed_payments,
    ROUND(
        SUM(
            CASE
                WHEN p.payment_status = 'failed' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(p.payment_id),
        2
    ) AS failure_rate
FROM
    sessions s
INNER JOIN orders o
    ON
    s.session_id = o.session_id
INNER JOIN payments p
    ON
    o.order_id = p.order_id
WHERE
    s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    s.device_type
ORDER BY
    MONTH,
    s.device_type;

-- По mobile-сегменту есть просадки в платежах
-- в июле и августе - 20% и 28% соответственно

-- Проверяем детально mobile-сегмент

SELECT
    DATE_TRUNC('month', s.session_start)::date AS MONTH,
    p.payment_method,
    COUNT(*) AS payment_attempts,
    SUM(CASE WHEN p.payment_status = 'failed' THEN 1 ELSE 0 END) AS failed_payments,
    ROUND(SUM(CASE WHEN p.payment_status = 'failed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS failure_rate
FROM
    sessions s
INNER JOIN orders o ON
    s.session_id = o.session_id
INNER JOIN payments p ON
    o.order_id = p.order_id
WHERE
    s.device_type = 'mobile'
    AND s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    p.payment_method
ORDER BY
    MONTH,
    failure_rate DESC;

-- Банковская карта:
-- июнь    27 / 253 failed → 10,67%
-- июль    71 / 222 failed → 31,98%
-- август 105 / 217 failed → 48,39%

-- Проверяем: проблема с банковскими картами 
-- только на мобильных устройствах или общая

SELECT
    DATE_TRUNC('month', s.session_start)::date AS MONTH,
    s.device_type,
    COUNT(*) AS payment_attempts,
    SUM(CASE WHEN p.payment_status = 'failed' THEN 1 ELSE 0 END) AS failed_payments,
    ROUND(SUM(CASE WHEN p.payment_status = 'failed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS failure_rate
FROM
    sessions s
INNER JOIN orders o ON
    s.session_id = o.session_id
INNER JOIN payments p ON
    o.order_id = p.order_id
WHERE
    p.payment_method = 'Банковская карта'
    AND s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    s.device_type
ORDER BY
    MONTH,
    s.device_type;

--                    Июнь     Июль     Август
-- Desktop            9,02%    5,26%     4,35%
-- Mobile            10,67%   31,98%    48,39%
-- Tablet            20,00%    5,00%     0,00%

-- Почему падают именно mobile-карточные платежи

SELECT
    DATE_TRUNC('month', s.session_start)::date AS MONTH,
    p.failure_reason,
    COUNT(*) AS failures_count
FROM
    sessions s
INNER JOIN orders o ON
    s.session_id = o.session_id
INNER JOIN payments p ON
    o.order_id = p.order_id
WHERE
    s.device_type = 'mobile'
    AND p.payment_method = 'Банковская карта'
    AND p.payment_status = 'failed'
    AND s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    p.failure_reason
ORDER BY
    MONTH,
    failures_count DESC;

-- Анализ локализовал проблему до этапа 3-D Secure в мобильных карточных платежах. 
-- Для определения конкретной технической причины 
-- требуется проверка логов платёжной интеграции и изменений mobile checkout

-- Выявляем когда именно началась данная проблема

SELECT
    s.session_start::date AS date,
    COUNT(*) AS payment_attempts,
    SUM(CASE WHEN p.payment_status = 'failed' AND p.failure_reason = 'Ошибка 3-D Secure / тайм-аут' THEN 1 ELSE 0 END) AS secure_errors,
    ROUND(SUM(CASE WHEN p.payment_status = 'failed' AND p.failure_reason = 'Ошибка 3-D Secure / тайм-аут' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS secure_error_rate
FROM sessions s
INNER JOIN orders o ON s.session_id = o.session_id
INNER JOIN payments p ON o.order_id = p.order_id
WHERE s.device_type = 'mobile'
    AND p.payment_method = 'Банковская карта'
    AND s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY s.session_start::date
ORDER BY date;

-- С 16 июля в данных впервые появляется устойчивый рост ошибок 3-D Secure

-- Сравниваем периоды до  после 16 июля

SELECT
    CASE
        WHEN s.session_start < '2024-07-16' THEN 'before_16_july'
        ELSE 'after_16_july'
    END AS period,
    COUNT(*) AS payment_attempts,
    SUM(CASE WHEN p.payment_status = 'failed' AND p.failure_reason = 'Ошибка 3-D Secure / тайм-аут' THEN 1 ELSE 0 END) AS secure_errors,
    ROUND(SUM(CASE WHEN p.payment_status = 'failed' AND p.failure_reason = 'Ошибка 3-D Secure / тайм-аут' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS secure_error_rate
FROM sessions s
INNER JOIN orders o ON s.session_id = o.session_id
INNER JOIN payments p ON o.order_id = p.order_id
WHERE s.device_type = 'mobile'
    AND p.payment_method = 'Банковская карта'
    AND s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    CASE
        WHEN s.session_start < '2024-07-16' THEN 'before_16_july'
        ELSE 'after_16_july'
    END;

-- Вывод:
-- До 16 июля ошибок 3-D Secure в mobile-карточных платежах не наблюдалось.
-- Начиная с 16 июля доля таких ошибок выросла до 33,33%.
-- Это указывает на резкое изменение в мобильном сценарии карточной оплаты,
-- возникшее примерно с 16 июля.
-- Конкретную техническую причину по текущим данным установить нельзя;
-- требуется проверка релизов, логов checkout/payment-интеграции и 3-D Secure flow.

-- Считаем сколько заказов и денег затронула 3DS-проблема

SELECT
    COUNT(*) AS affected_orders,
    SUM(o.final_amount) AS potential_revenue_loss,
    ROUND(AVG(o.final_amount), 2) AS avg_affected_order_value
FROM sessions s
INNER JOIN orders o ON s.session_id = o.session_id
INNER JOIN payments p ON o.order_id = p.order_id
WHERE s.device_type = 'mobile'
    AND p.payment_method = 'Банковская карта'
    AND p.payment_status = 'failed'
    AND p.failure_reason = 'Ошибка 3-D Secure / тайм-аут'
    AND s.session_start >= '2024-07-16'
    AND s.session_start < '2024-09-01';

-- Вывод:
-- После 16 июля 111 mobile-заказов с оплатой банковской картой
-- завершились ошибкой 3-D Secure / тайм-аут.
-- Суммарная стоимость затронутых заказов составила 3 130 627 руб.
-- Средний чек затронутого заказа — 28 203,85 руб.
-- Эту сумму трактуем как потенциальную выручку под риском,
-- а не как гарантированно потерянную выручку.

-- Разложим ущерб по месяцам

SELECT
    DATE_TRUNC('month', s.session_start)::date AS month,
    COUNT(*) AS affected_orders,
    SUM(o.final_amount) AS potential_revenue_loss,
    ROUND(AVG(o.final_amount), 2) AS avg_affected_order_value
FROM sessions s
INNER JOIN orders o ON s.session_id = o.session_id
INNER JOIN payments p ON o.order_id = p.order_id
WHERE s.device_type = 'mobile'
    AND p.payment_method = 'Банковская карта'
    AND p.payment_status = 'failed'
    AND p.failure_reason = 'Ошибка 3-D Secure / тайм-аут'
    AND s.session_start >= '2024-07-16'
    AND s.session_start < '2024-09-01'
GROUP BY DATE_TRUNC('month', s.session_start)::date
ORDER BY month;

-- 3-D Secure — существенная причина падения, но не единственная.
-- Выручка июня:    23,63 млн.р.
-- Выручка июля:    17,77 млн.р.
-- Выручка августа: 18,72 млн.р.
--
-- Разница относительно июня:
-- Июль:   -5,87 млн.р.
-- Август: -4,91 млн.р.
--
-- Наша оценка 3DS-проблемы:
-- Июль:   1,40 млн.р.
-- Август: 1,73 млн.р.
--
-- Одной из основных причин падения стала проблема mobile-карточных платежей после 16 июля, 
-- однако она объясняет только часть снижения выручки. 
-- Необходимо исследовать оставшуюся часть просадки.

-- Рассчитаем среднее кол-во товаров для каждого заказа,
-- а затем усредняем по месяцам

SELECT
    DATE_TRUNC('month', o.order_datetime)::date AS month,
    COUNT(*) AS completed_orders,
    ROUND(AVG(items_summary.items_count), 2) AS avg_items_per_order,
    ROUND(AVG(o.final_amount), 2) AS avg_order_value
FROM orders o
INNER JOIN (
    SELECT
        order_id,
        SUM(quantity) AS items_count
    FROM order_items
    GROUP BY order_id
) items_summary ON o.order_id = items_summary.order_id
WHERE o.order_status = 'completed'
    AND o.order_datetime >= '2024-06-01'
    AND o.order_datetime < '2024-09-01'
GROUP BY DATE_TRUNC('month', o.order_datetime)::date
ORDER BY month;

-- Вывод:
-- Среднее количество товаров в completed-заказе остаётся стабильным:
-- 1,31 в июне, 1,30 в июле и августе.
-- Следовательно, снижение AOV не связано с уменьшением количества
-- товаров в заказе. Необходимо проверить изменение стоимости
-- приобретаемых товаров и категориального микса.

-- Проверяем среднюю стоимость товарной единицы в завершенных заказах по месяцам

SELECT
    DATE_TRUNC('month', o.order_datetime)::date AS month,
    ROUND(AVG(oi.unit_price), 2) AS avg_unit_price,
    ROUND(AVG(oi.line_amount), 2) AS avg_line_amount
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'completed'
    AND o.order_datetime >= '2024-06-01'
    AND o.order_datetime < '2024-09-01'
GROUP BY DATE_TRUNC('month', o.order_datetime)::date
ORDER BY month;

-- Вывод:
-- Средняя стоимость товарной позиции снизилась примерно на 11% в июле
-- и остаётся ниже июньского уровня в августе.
-- При стабильном количестве товаров в заказе это указывает на изменение
-- продуктового микса в сторону более дешёвых товаров.
-- Необходимо проверить структуру продаж по категориям.

SELECT
    DATE_TRUNC('month', o.order_datetime)::date AS month,
    p.category,
    SUM(oi.quantity) AS items_sold,
    SUM(oi.line_amount) AS product_sales,
    ROUND(AVG(oi.unit_price), 2) AS avg_unit_price
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'completed'
    AND o.order_datetime >= '2024-06-01'
    AND o.order_datetime < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', o.order_datetime)::date,
    p.category
ORDER BY
    month,
    product_sales DESC;

-- Вывод:
-- Снижение AOV связано с изменением продуктового микса.
-- Продажи дорогих категорий заметно сократились:
-- смартфоны и компьютеры/планшеты в июле снизились примерно на 30%.
-- При этом объём продаж аксессуаров остаётся относительно стабильным.
-- Следовательно, средний чек снижается преимущественно из-за
-- уменьшения доли дорогих товаров в продажах, а не из-за роста
-- количества дешёвых товаров.

-- Проверяем конвертацию трафика по дорогим категориям
-- Важное уточнение:
-- в sessions у нас есть landing_category:
-- это категория, с которой началась сессия
-- Поэтому используем ее как показатель входного трафика

SELECT
    DATE_TRUNC('month', s.session_start)::date AS month,
    s.landing_category,
    COUNT(*) AS sessions,
    SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
    ROUND(SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS conversion_rate
FROM sessions s
LEFT JOIN orders o ON s.order_id = o.order_id
WHERE s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    s.landing_category
ORDER BY
    month,
    conversion_rate DESC;

-- Вывод:
-- Снижение продаж дорогих категорий не объясняется падением входного трафика.
-- По смартфонам число сессий растёт, по компьютерам остаётся примерно
-- на прежнем уровне, при этом conversion rate заметно снижается.
-- Снижение CR наблюдается и в других категориях, что указывает
-- на общую проблему процесса покупки, а не только на изменение спроса.

-- Проверяем:
-- не бьёт ли найденная 3DS-проблема особенно сильно именно по дорогим категориям

SELECT
    p.category,
    SUM(oi.quantity) AS affected_items,
    SUM(oi.line_amount) AS affected_product_value,
    ROUND(AVG(oi.unit_price), 2) AS avg_unit_price
FROM sessions s
INNER JOIN orders o ON s.session_id = o.session_id
INNER JOIN payments pay ON o.order_id = pay.order_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
WHERE s.device_type = 'mobile'
    AND pay.payment_method = 'Банковская карта'
    AND pay.payment_status = 'failed'
    AND pay.failure_reason = 'Ошибка 3-D Secure / тайм-аут'
    AND s.session_start >= '2024-07-16'
    AND s.session_start < '2024-09-01'
GROUP BY p.category
ORDER BY affected_product_value DESC;

-- Вывод:
-- Основная стоимость заказов, затронутых mobile 3-D Secure проблемой,
-- приходится на дорогие категории.
-- Смартфоны формируют около половины стоимости затронутых товаров,
-- смартфоны и компьютеры/планшеты вместе — около двух третей.
-- Это связывает платёжную проблему не только с падением conversion rate,
-- но потенциально и со снижением AOV / доли дорогих категорий.

-- Разделяем эти потери на июль и август по категориям

SELECT
    DATE_TRUNC('month', s.session_start)::date AS month,
    p.category,
    COUNT(DISTINCT o.order_id) AS affected_orders,
    SUM(oi.line_amount) AS affected_product_value
FROM sessions s
INNER JOIN orders o ON s.session_id = o.session_id
INNER JOIN payments pay ON o.order_id = pay.order_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
WHERE s.device_type = 'mobile'
    AND pay.payment_method = 'Банковская карта'
    AND pay.payment_status = 'failed'
    AND pay.failure_reason = 'Ошибка 3-D Secure / тайм-аут'
    AND s.session_start >= '2024-07-16'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    p.category
ORDER BY
    month,
    affected_product_value DESC;

-- Вывод:
-- Ошибки mobile 3-D Secure существенно затронули дорогие категории.
-- Для смартфонов стоимость затронутых заказов эквивалентна примерно
-- 21% июльской и 40% августовской просадки относительно июня.
-- Для компьютеров/планшетов — примерно 10% и 24% соответственно.
-- Однако affected_product_value является оценкой потенциальных продаж,
-- а не доказанной потерянной выручкой.
-- Следовательно, 3-D Secure является существенным, но не единственным
-- фактором снижения продаж дорогих категорий.

-- Проверяем качество маркетингового трафика
-- Смотрим трафик и CR по каналам

SELECT
    DATE_TRUNC('month', s.session_start)::date AS month,
    s.channel,
    COUNT(*) AS sessions,
    SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
    ROUND(SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS conversion_rate
FROM sessions s
LEFT JOIN orders o ON s.order_id = o.order_id
WHERE s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    s.channel
ORDER BY
    month,
    sessions DESC;

-- Разбираем следующий вопрос:
-- VK Ads плохо конвертируется ещё до оплаты, 
-- или его пользователи нормально проходят воронку, а потом падают из-за mobile/3DS?

SELECT
    DATE_TRUNC('month', s.session_start)::date AS month,
    s.device_type,
    COUNT(*) AS sessions,
    SUM(s.add_to_cart) AS add_to_cart,
    SUM(s.checkout_started) AS checkout_started,
    SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
    ROUND(SUM(s.add_to_cart) * 100.0 / COUNT(*), 2) AS cart_rate,
    ROUND(SUM(s.checkout_started) * 100.0 / NULLIF(SUM(s.add_to_cart), 0), 2) AS cart_to_checkout_rate,
    ROUND(SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) * 100.0 / NULLIF(SUM(s.checkout_started), 0), 2) AS checkout_to_purchase_rate
FROM sessions s
LEFT JOIN orders o ON s.order_id = o.order_id
WHERE s.channel = 'VK Ads'
    AND s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    s.device_type
ORDER BY
    month,
    s.device_type;

-- Вывод:
-- В июле объём трафика из VK Ads вырос примерно в 2,5 раза,
-- а conversion rate снизился с 6,05% до 2,91%.
-- Доля VK Ads в общем трафике выросла примерно с 10% до 23%.
-- Изменение структуры трафика может быть одним из факторов снижения общего CR.
-- Необходимо отделить качество VK-трафика от влияния mobile 3-D Secure проблемы.
--
-- Низкий CR VK Ads нельзя объяснить только mobile 3-D Secure проблемой.
-- После июня cart_rate снижается примерно с 13% до 8–9%
-- одновременно на desktop, mobile и tablet.
-- Это указывает на ухудшение качества/релевантности входящего VK-трафика.
-- Дополнительно mobile-сегмент теряет пользователей на этапе
-- checkout → purchase, что согласуется с обнаруженной 3-D Secure проблемой.
-- Следовательно, существуют как минимум две независимые причины снижения CR.
--
-- VK Ads с июля
-- │
-- ├── проблема №1: трафик хуже по качеству
-- │   session → cart заметно падает
-- │   причём на всех устройствах
-- │
-- └── проблема №2: mobile payment
--     checkout → purchase дополнительно падает
--     из-за 3-D Secure после 16 июля

-- Смотрим что изменилось внутри VK Ads с июля
-- Считаем по кампаниям

SELECT
    DATE_TRUNC('month', s.session_start)::date AS month,
    s.campaign_id,
    COUNT(*) AS sessions,
    SUM(s.add_to_cart) AS add_to_cart,
    ROUND(SUM(s.add_to_cart) * 100.0 / COUNT(*), 2) AS cart_rate,
    SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
    ROUND(SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS conversion_rate
FROM sessions s
LEFT JOIN orders o ON s.order_id = o.order_id
WHERE s.channel = 'VK Ads'
    AND s.session_start >= '2024-06-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', s.session_start)::date,
    s.campaign_id
ORDER BY
    month,
    sessions DESC;

-- Вывод:
-- Резкий рост VK Ads-трафика в июле связан с запуском кампании VK_SUMMER.
-- Она формирует около 64% VK-трафика в июле и августе.
-- При этом cart_rate VK_SUMMER составляет около 6% против 12–13%
-- у VK_RETARGET, а итоговый CR — около 2%.
-- Следовательно, новый объём трафика значительно хуже по качеству
-- уже на раннем этапе воронки, до checkout и оплаты.
-- VK_SUMMER является отдельным фактором снижения общего conversion rate.

-- Выясняем: компания просто получила много плохого трафика или ещё и увеличила расходы на его привлечение?

SELECT
    DATE_TRUNC('month', spend_date)::date AS month,
    campaign_id,
    SUM(impressions) AS impressions,
    SUM(clicks) AS clicks,
    SUM(spend_rub) AS spend_rub,
    ROUND(SUM(spend_rub) * 1.0 / NULLIF(SUM(clicks), 0), 2) AS cpc
FROM marketing_spend
WHERE channel = 'VK Ads'
    AND spend_date >= '2024-06-01'
    AND spend_date < '2024-09-01'
GROUP BY
    DATE_TRUNC('month', spend_date)::date,
    campaign_id
ORDER BY
    month,
    spend_rub DESC;

-- Вывод:
-- VK_SUMMER обеспечивает более дешёвый клик, чем VK_RETARGET,
-- однако значительно хуже конвертируется в покупку.
-- При этом на VK_SUMMER приходится существенно больший рекламный бюджет.
-- Поэтому CPC недостаточно для оценки эффективности кампании:
-- необходимо сравнить затраты с количеством покупок и выручкой.

SELECT
    m.month,
    m.campaign_id,
    m.spend_rub,
    s.completed_orders,
    s.revenue,
    ROUND(m.spend_rub * 1.0 / NULLIF(s.completed_orders, 0), 2) AS cpa,
    ROUND(s.revenue * 1.0 / NULLIF(m.spend_rub, 0), 2) AS roas
FROM (
    SELECT
        DATE_TRUNC('month', spend_date)::date AS month,
        campaign_id,
        SUM(spend_rub) AS spend_rub
    FROM marketing_spend
    WHERE channel = 'VK Ads'
        AND spend_date >= '2024-06-01'
        AND spend_date < '2024-09-01'
    GROUP BY DATE_TRUNC('month', spend_date)::date, campaign_id
) m
INNER JOIN (
    SELECT
        DATE_TRUNC('month', s.session_start)::date AS month,
        s.campaign_id,
        COUNT(*) FILTER (WHERE o.order_status = 'completed') AS completed_orders,
        SUM(CASE WHEN o.order_status = 'completed' THEN o.final_amount ELSE 0 END) AS revenue
    FROM sessions s
    LEFT JOIN orders o ON s.order_id = o.order_id
    WHERE s.channel = 'VK Ads'
        AND s.session_start >= '2024-06-01'
        AND s.session_start < '2024-09-01'
    GROUP BY DATE_TRUNC('month', s.session_start)::date, s.campaign_id
) s ON m.month = s.month AND m.campaign_id = s.campaign_id
ORDER BY m.month, m.campaign_id;

-- Вывод:
-- Кампания VK_SUMMER получает большую часть бюджета VK Ads,
-- но существенно уступает VK_RETARGET по эффективности.
-- В июле VK_SUMMER потребляет около 72% VK-бюджета,
-- обеспечивая лишь около 47% completed-заказов и 36% выручки.
-- CPA кампании в 2,9 раза выше VK_RETARGET, ROAS — примерно в 4,6 раза ниже.
-- В августе разрыв увеличивается: CPA выше примерно в 4,2 раза,
-- ROAS ниже примерно в 4,9 раза.
-- Следовательно, масштабирование VK_SUMMER увеличило объём трафика,
-- но ухудшило качество трафика и эффективность рекламных расходов.

-- Выявили две крупные независимые причины просажки:
-- 
-- 1. Техническая:
-- mobile + bank card + 3-D Secure после 16 июля
-- 
-- 2. Маркетинговая:
-- запуск и масштабирование VK_SUMMER с низким CR и плохой экономикой

-- Считаем benchmark-gap для VK_SUMMER: 
-- сколько заказов она недобирает относительно VK_RETARGET

WITH campaign_metrics AS (
    SELECT
        DATE_TRUNC('month', s.session_start)::date AS month,
        s.campaign_id,
        COUNT(*) AS sessions,
        SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders
    FROM sessions s
    LEFT JOIN orders o ON s.order_id = o.order_id
    WHERE s.channel = 'VK Ads'
        AND s.session_start >= '2024-07-01'
        AND s.session_start < '2024-09-01'
    GROUP BY DATE_TRUNC('month', s.session_start)::date, s.campaign_id
),
benchmark AS (
    SELECT
        month,
        completed_orders * 1.0 / sessions AS benchmark_cr
    FROM campaign_metrics
    WHERE campaign_id = 'VK_RETARGET'
)
SELECT
    cm.month,
    cm.sessions,
    cm.completed_orders,
    ROUND(b.benchmark_cr * 100, 2) AS benchmark_cr,
    ROUND(cm.sessions * b.benchmark_cr) AS expected_orders,
    ROUND(cm.sessions * b.benchmark_cr) - cm.completed_orders AS order_gap
FROM campaign_metrics cm
INNER JOIN benchmark b ON cm.month = b.month
WHERE cm.campaign_id = 'VK_SUMMER'
ORDER BY cm.month;

-- Июль:   expected 80, факт 39 → gap 41 заказ
-- Август: expected 105, факт 34 → gap 71 заказ

-- Переведем 41 и 71 заказ в "деньги" - потенциально недополученную выручку

WITH campaign_metrics AS (
    SELECT
        DATE_TRUNC('month', s.session_start)::date AS month,
        s.campaign_id,
        COUNT(*) AS sessions,
        SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN o.order_status = 'completed' THEN o.final_amount ELSE 0 END) AS revenue
    FROM sessions s
    LEFT JOIN orders o ON s.order_id = o.order_id
    WHERE s.channel = 'VK Ads'
        AND s.session_start >= '2024-07-01'
        AND s.session_start < '2024-09-01'
    GROUP BY DATE_TRUNC('month', s.session_start)::date, s.campaign_id
),
benchmark AS (
    SELECT
        month,
        completed_orders * 1.0 / sessions AS benchmark_cr
    FROM campaign_metrics
    WHERE campaign_id = 'VK_RETARGET'
)
SELECT
    cm.month,
    cm.sessions,
    cm.completed_orders,
    ROUND(b.benchmark_cr * 100, 2) AS benchmark_cr,
    ROUND(cm.sessions * b.benchmark_cr) AS expected_orders,
    ROUND(cm.sessions * b.benchmark_cr) - cm.completed_orders AS order_gap,
    ROUND(cm.revenue * 1.0 / NULLIF(cm.completed_orders, 0), 2) AS avg_order_value,
    ROUND(
        (ROUND(cm.sessions * b.benchmark_cr) - cm.completed_orders)
        * (cm.revenue * 1.0 / NULLIF(cm.completed_orders, 0)),
        2
    ) AS potential_revenue_gap
FROM campaign_metrics cm
INNER JOIN benchmark b ON cm.month = b.month
WHERE cm.campaign_id = 'VK_SUMMER'
ORDER BY cm.month;

-- Если бы VK_SUMMER конвертировалась на уровне VK_RETARGET в тех же месяцах, 
-- кампания могла бы принести примерно на 112 completed-заказов больше, 
-- что эквивалентно примерно 2,98 млн.р. потенциальной дополнительной выручки.

-- Выясняем есть ли failed-платежи именно внутри VK_SUMMER

SELECT
    p.failure_reason,
    COUNT(*) AS failed_payments
FROM sessions s
INNER JOIN orders o ON s.order_id = o.order_id
INNER JOIN payments p ON o.order_id = p.order_id
WHERE s.channel = 'VK Ads'
    AND s.campaign_id = 'VK_SUMMER'
    AND p.payment_status = 'failed'
    AND s.session_start >= '2024-07-01'
    AND s.session_start < '2024-09-01'
GROUP BY p.failure_reason
ORDER BY failed_payments DESC;

SELECT
    s.device_type,
    p.payment_method,
    p.failure_reason,
    COUNT(*) AS failed_payments
FROM sessions s
INNER JOIN orders o ON s.order_id = o.order_id
INNER JOIN payments p ON o.order_id = p.order_id
WHERE s.channel = 'VK Ads'
    AND s.campaign_id = 'VK_SUMMER'
    AND p.payment_status = 'failed'
    AND s.session_start >= '2024-07-01'
    AND s.session_start < '2024-09-01'
GROUP BY
    s.device_type,
    p.payment_method,
    p.failure_reason
ORDER BY failed_payments DESC;

SELECT
    DATE_TRUNC('month', s.session_start)::date AS month,
    COUNT(DISTINCT o.order_id) AS affected_orders,
    SUM(o.final_amount) AS affected_revenue
FROM sessions s
INNER JOIN orders o ON s.order_id = o.order_id
INNER JOIN payments p ON o.order_id = p.order_id
WHERE s.channel = 'VK Ads'
    AND s.campaign_id = 'VK_SUMMER'
    AND s.device_type = 'mobile'
    AND p.payment_method = 'Банковская карта'
    AND p.payment_status = 'failed'
    AND p.failure_reason = 'Ошибка 3-D Secure / тайм-аут'
    AND s.session_start >= '2024-07-16'
    AND s.session_start < '2024-09-01'
GROUP BY DATE_TRUNC('month', s.session_start)::date
ORDER BY month;

-- Июль:
-- 3DS affected orders = 7
-- affected revenue     = 193 641 ₽
--
-- Август:
-- 3DS affected orders = 3
-- affected revenue     = 98 305 ₽
--
-- Июль:   41 заказ
-- Август: 71 заказ
-- Итого:  112 заказов
-- 
--Сопоставляем масштабы
-- Июль:
-- 7 / 41 ≈ 17,1%
-- Август:
-- 3 / 71 ≈ 4,2%
-- Всего:
-- 10 / 112 ≈ 8,9%

-- Вывод:
-- Пересечение проблем VK_SUMMER и mobile 3-D Secure ограничено.
-- Внутри VK_SUMMER найдено 10 заказов с ошибкой 3-D Secure:
-- 7 в июле и 3 в августе.
-- Это соответствует примерно 9% от benchmark-gap VK_SUMMER
-- в 112 недостающих completed-заказов.
-- Следовательно, низкую эффективность VK_SUMMER нельзя объяснить
-- преимущественно технической проблемой оплаты.
-- Основная просадка кампании проявляется раньше воронки,
-- что указывает на отдельную проблему качества/релевантности трафика.

-- Считаем контрфактический общий CR сайта: 
-- каким бы он был, если бы всё осталось как есть, 
-- но VK_SUMMER конвертировалась хотя бы на уровне VK_RETARGET

WITH campaign_metrics AS (
    SELECT
        DATE_TRUNC('month', s.session_start)::date AS month,
        s.campaign_id,
        COUNT(*) AS sessions,
        SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders
    FROM sessions s
    LEFT JOIN orders o ON s.order_id = o.order_id
    WHERE s.channel = 'VK Ads'
        AND s.session_start >= '2024-07-01'
        AND s.session_start < '2024-09-01'
    GROUP BY DATE_TRUNC('month', s.session_start)::date, s.campaign_id
),
benchmark AS (
    SELECT
        month,
        completed_orders * 1.0 / sessions AS benchmark_cr
    FROM campaign_metrics
    WHERE campaign_id = 'VK_RETARGET'
),
summer_gap AS (
    SELECT
        cm.month,
        ROUND(cm.sessions * b.benchmark_cr) - cm.completed_orders AS order_gap
    FROM campaign_metrics cm
    INNER JOIN benchmark b ON cm.month = b.month
    WHERE cm.campaign_id = 'VK_SUMMER'
),
site_metrics AS (
    SELECT
        DATE_TRUNC('month', s.session_start)::date AS month,
        COUNT(*) AS sessions,
        SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders
    FROM sessions s
    LEFT JOIN orders o ON s.order_id = o.order_id
    WHERE s.session_start >= '2024-07-01'
        AND s.session_start < '2024-09-01'
    GROUP BY DATE_TRUNC('month', s.session_start)::date
)
SELECT
    sm.month,
    sm.sessions,
    sm.completed_orders,
    ROUND(sm.completed_orders * 100.0 / sm.sessions, 2) AS actual_cr,
    sg.order_gap,
    sm.completed_orders + sg.order_gap AS adjusted_orders,
    ROUND((sm.completed_orders + sg.order_gap) * 100.0 / sm.sessions, 2) AS adjusted_cr,
    ROUND(sg.order_gap * 100.0 / sm.sessions, 2) AS cr_uplift_pp
FROM site_metrics sm
INNER JOIN summer_gap sg ON sm.month = sg.month
ORDER BY sm.month;

-- Вывод:
-- Низкая эффективность VK_SUMMER оказывает заметное влияние
-- на общий conversion rate сайта.
-- При benchmark-конверсии на уровне VK_RETARGET общий CR
-- вырос бы с 5,05% до 5,38% в июле
-- и с 4,99% до 5,55% в августе.
-- Это эквивалентно примерно 29% июльской
-- и 45% августовской просадки CR относительно июня.
-- При этом даже скорректированный CR остаётся ниже июньских 6,24%,
-- следовательно, VK_SUMMER является существенным,
-- но не единственным фактором ухудшения конверсии.

-- Считаем вклад mobile + банковская карта + 3DS в общий CR сайта
-- по той же логике, что и для VK_SUMMER

WITH secure_failures AS (
    SELECT
        DATE_TRUNC('month', s.session_start)::date AS month,
        COUNT(DISTINCT o.order_id) AS affected_orders
    FROM sessions s
    INNER JOIN orders o ON s.order_id = o.order_id
    INNER JOIN payments p ON o.order_id = p.order_id
    WHERE s.device_type = 'mobile'
        AND p.payment_method = 'Банковская карта'
        AND p.payment_status = 'failed'
        AND p.failure_reason = 'Ошибка 3-D Secure / тайм-аут'
        AND s.session_start >= '2024-07-16'
        AND s.session_start < '2024-09-01'
    GROUP BY DATE_TRUNC('month', s.session_start)::date
),
site_metrics AS (
    SELECT
        DATE_TRUNC('month', s.session_start)::date AS month,
        COUNT(*) AS sessions,
        SUM(CASE WHEN o.order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders
    FROM sessions s
    LEFT JOIN orders o ON s.order_id = o.order_id
    WHERE s.session_start >= '2024-07-01'
        AND s.session_start < '2024-09-01'
    GROUP BY DATE_TRUNC('month', s.session_start)::date
)
SELECT
    sm.month,
    sm.sessions,
    sm.completed_orders,
    sf.affected_orders,
    ROUND(sm.completed_orders * 100.0 / sm.sessions, 2) AS actual_cr,
    sm.completed_orders + sf.affected_orders AS adjusted_orders,
    ROUND((sm.completed_orders + sf.affected_orders) * 100.0 / sm.sessions, 2) AS adjusted_cr,
    ROUND(sf.affected_orders * 100.0 / sm.sessions, 2) AS cr_uplift_pp
FROM site_metrics sm
INNER JOIN secure_failures sf ON sm.month = sf.month
ORDER BY sm.month;

-- Вывод:
-- При конверсии на уровне VK_RETARGET кампания VK_SUMMER
-- могла бы получить около 80 completed-заказов в июле
-- и 105 в августе вместо фактических 39 и 34.
-- Benchmark-gap составляет 41 заказ в июле и 71 заказ в августе,
-- всего около 112 потенциально недополученных заказов.
-- При фактическом среднем чеке VK_SUMMER это эквивалентно
-- примерно 0,80 млн ₽ потенциальной выручки в июле
-- и 2,18 млн ₽ в августе, или около 2,98 млн ₽ суммарно.
-- Это оценочный сценарий, а не фактически потерянная выручка.