/*
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Камнева Ирина Юрьевна
 * Дата: 30.07.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
SELECT
    COUNT(id) total_igrokov,
    SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) total_payers,
    ROUND(SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(id),2) dolya_payers
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race,
       COUNT(id) total_igrokov,
       SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) platyat,
       ROUND(SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(id),2) dolya_payers
FROM fantasy.race r
JOIN fantasy.users u USING(race_id)
GROUP BY r.race
ORDER BY dolya_payers DESC;
       

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount) total_pokupok,
       SUM(amount) summa_pokupok,
       MIN(amount) min_summa,
       MAX(amount) max_summa,
       ROUND(AVG(amount)::numeric,2) sr_summa,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) mediana,
       ROUND(STDDEV(amount)::numeric,2) st_otklonenie
FROM  fantasy.events;     

-- 2.2: Аномальные нулевые покупки:
SELECT SUM(CASE WHEN amount=0 THEN 1 ELSE 0 END) free,
       ROUND(SUM(CASE WHEN amount=0 THEN 1 ELSE 0 END)*100.0/COUNT(amount),2) dolya_free
FROM  fantasy.events;   

-- 2.3: Популярные эпические предметы:
WITH filter AS (
    SELECT *
    FROM fantasy.events
    WHERE amount > 0
),
total_buyer_count AS (
    SELECT COUNT(DISTINCT id) total_count
    FROM filter
)
SELECT
    i.item_code,
    i.game_items,
    COUNT(*) total_sales_count, 
    ROUND(COUNT(*) * 100.0::numeric
        / SUM(COUNT(*)) OVER (),2) dolya_of_total_sales, 
    COUNT(DISTINCT f.id) total_unique_buyers,
    ROUND(COUNT(DISTINCT f.id) * 100.0::numeric
        / (SELECT total_count FROM total_buyer_count), 2) dolya_of_all_buyers    
FROM filter f
JOIN fantasy.items i USING (item_code)
GROUP BY i.item_code,i.game_items
ORDER BY total_unique_buyers DESC,total_sales_count DESC;
-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH filter AS (
    SELECT *
    FROM fantasy.events e
    WHERE amount > 0
),
race_users as (
SELECT r.race,
       COUNT(u.id) total_users,
       SUM(CASE WHEN u.payer = 1 THEN 1 ELSE 0 END) total_payers,
       ROUND(SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) * 100.0 
       / COUNT(u.id),2) dolya_payers
FROM fantasy.users u
JOIN fantasy.race r using (race_id)
group by r.race
),
race_buyers as (
select r.race,
        COUNT(DISTINCT u.id) users_with_purchases,
       ROUND(COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) * 100.0::numeric 
       / COUNT(DISTINCT u.id),2) share_payers_among_buyer
FROM filter f 
JOIN fantasy.users u ON f.id = u.id
JOIN fantasy.race r ON u.race_id = r.race_id
GROUP BY r.race
),
race_activity  as (
select r.race,
       count(f.transaction_id) total_transactions,
       sum(f.amount) total_amount,
       ROUND(SUM(f.amount)::numeric/(COUNT(f.transaction_id)),2) avg_amount_per_purchase,
       ROUND(SUM(f.amount)::numeric/(COUNT(DISTINCT f.id)),2) avg_total_spend_per_buyer
    FROM filter f
    JOIN fantasy.users u ON f.id = u.id
    JOIN fantasy.race r ON u.race_id = r.race_id
    GROUP BY r.race
)
  SELECT
    ru.race,
    ru.total_users,
    rb.users_with_purchases,
    ROUND(rb.users_with_purchases * 100.0 /ru.total_users, 2) share_buyers_from_all, 
    rb.share_payers_among_buyer,
    ra.total_transactions, 
    ROUND((ra.total_transactions/rb.users_with_purchases), 2) avg_purchases_per_buyer,
    ra.avg_amount_per_purchase,
    ra.avg_total_spend_per_buyer
FROM race_users ru
LEFT JOIN race_buyers rb ON ru.race = rb.race
LEFT JOIN race_activity ra ON ru.race = ra.race
ORDER BY ru.race;     