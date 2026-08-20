--  Анализ данных для агентства недвижимости 
--  Автор: Камнева Ирина
--  Дата: 20.08.2026


-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- разбивка по категориям региона и длительности продажи
segment as ( 
       SELECT case when f.city_id ='6X8I' then 'spb' else 'ne spb' end region,
       case when a.days_exposition between 1 and 30 then '1 month' 
       when a.days_exposition between 31 and 90 then '1-3 month'
       when a.days_exposition between 91 and 180 then '3-6 month'
       when a.days_exposition >=181 then '6+month'
       when a.days_exposition is null then 'ne prodali or smth'
       end segment,
       *,
       last_price/total_area metrprice
FROM real_estate.flats f
left join real_estate.advertisement a using (id)
WHERE id IN (SELECT * FROM filtered_id) 
and type_id='F8EM'
and a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
)
select region,
       segment,
       count(id) total_advertisements,
       round(count(id)/sum(count(id)) over (partition by region)::numeric,2) dolya_from_total,
       round(avg(metrprice)::numeric,2) avg_metr_price,
       round(avg(total_area)::numeric,2) avg_area,
       count(case when is_apartment=1 then 1 end) apartaments,
       count(case when is_apartment=0 then 1 end) ne_apartaments,
       round(avg(airports_nearest)::numeric/1000.00,2) aerodistance_km,
       percentile_disc(0.5) within group(order by rooms) mediana_rooms,
       percentile_disc(0.5) within group(order by balcony) mediana_balcony,
       percentile_disc(0.5) within group(order by floor) mediana_floor,
       percentile_disc(0.5) within group(order by ceiling_height) mediana_ceiling_height,
       percentile_disc(0.5) within group(order by parks_around3000) mediana_parks,
       percentile_disc(0.5) within group(order by ponds_around3000) mediana_ponds
from segment 
group by region,segment
order by total_advertisements desc;
       


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
--определение месяца публикации и снятия 
 year as (
 select 
    f.*,
    extract(month from a.first_day_exposition) AS date_public,
    extract(month from (a.first_day_exposition + a.days_exposition::integer)) AS date_sale,
    a.last_price
from real_estate.flats f
left join real_estate.advertisement a USING (id)
where f.id IN (SELECT id FROM filtered_id) 
  and f.type_id = 'F8EM'
  and a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
  ),
  --метрики для месяца публикации
  publish as (
  select date_public as month_date,
         count(id) kolvo_public,
         round(avg(last_price/total_area)::numeric,2) metrprice_public,
         round(avg(total_area)::numeric,2) avg_area_public
  from year
  group by date_public
  ),
  --метрики для месяца снятия
  sale as (
  select date_sale as month_date,
         count(id) kolvo_sale,
         round(avg(last_price/total_area)::numeric,2) metrprice_sale,
         round(avg(total_area)::numeric,2) avg_area_sale
  from year
  group by date_sale
  )
  --общая таблица 
  select 
       rank() over (order by kolvo_public desc,kolvo_sale desc),
  case 
	  when month_date= 1 then 'yanvar'
       when month_date=2 then 'fevral'
       when month_date=3 then 'mart'
       when month_date=4 then 'aprel'
       when month_date=5 then 'may'
       when month_date=6 then 'iyun'
       when month_date=7 then 'iyul'
       when month_date=8 then 'avgust'
       when month_date=9 then 'sentyabr'
       when month_date=10 then 'oktyabr'
       when month_date=11 then 'noyabr'
       when month_date=12 then 'dekabr'
  end in_russian,
    kolvo_public,
    kolvo_sale,
    metrprice_public,
    metrprice_sale,
    avg_area_public,
    avg_area_sale
from publish
full join sale using (month_date)
where month_date is not null;
