-- OYO Data Analysis

# Data Cleaning
SELECT DISTINCT(status) FROM fact_bookings;
SET SQL_SAFE_UPDATES = 0;
ALTER TABLE fact_bookings ADD COLUMN new_check_in DATE;
ALTER TABLE fact_bookings ADD COLUMN new_check_out DATE;
ALTER TABLE fact_bookings ADD COLUMN new_date_of_booking DATE;
UPDATE fact_bookings
SET new_check_in=str_to_date(substr(check_in,1,10),'%d-%m-%Y');
UPDATE fact_bookings
SET new_check_out=str_to_date(substr(check_out,1,10),'%d-%m-%Y');
UPDATE fact_bookings
SET new_date_of_booking=str_to_date(substr(date_of_booking,1,10),'%d-%m-%Y');

-- 0. Cities where OYO runs their business
SELECT DISTINCT(city) AS city
FROM dim_hotels;

-- 1. Hotels per city
SELECT city,COUNT(*) AS hotels
FROM dim_hotels
GROUP BY city
ORDER BY hotels DESC;

-- 2. Total Hotel Bookings per City
SELECT city,COUNT(booking_id) AS total_bookings
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id
GROUP BY city
ORDER BY total_bookings DESC;

-- 3. Citywise Completion,Cancellation,No Show Percentage
WITH x AS (
SELECT city,COUNT(booking_id) AS total_bookings,
COUNT(CASE WHEN status='Stayed' THEN booking_id ELSE NULL END) AS completed_bookings,
COUNT(CASE WHEN status='Cancelled' THEN booking_id ELSE NULL END) AS cancelled_bookings,
COUNT(CASE WHEN status='No Show' THEN booking_id ELSE NULL END) AS no_show_bookings
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id
GROUP BY City)
SELECT city,ROUND(completed_bookings*100/total_bookings,2) AS completion_percentage,
ROUND(cancelled_bookings*100/total_bookings,2) AS cancellation_percentage,ROUND(no_show_bookings*100/total_bookings,2) AS no_show_percentage
FROM x;

-- 4. Avg days of stay in hotel
SELECT city,ROUND(AVG(TIMESTAMPDIFF(HOUR,new_check_in,new_check_out)),0) AS hours_stayed
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id
WHERE status!='Cancelled'
GROUP BY City;

-- 5. City and Monthwise bookings
SELECT city,MONTHNAME(new_date_of_booking) AS month,MONTH(new_date_of_booking) AS mn,COUNT(booking_id) AS total_bookings
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id
GROUP BY City,month,mn
ORDER BY city,mn;

-- 6. Monthly Cancellation Rate
SELECT city,MONTHNAME(new_date_of_booking) AS month,MONTH(new_date_of_booking) AS mn,
ROUND(COUNT(CASE WHEN status='Cancelled' THEN booking_id END)*100/COUNT(booking_id),2) AS cancellation_percentage
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id
GROUP BY City,month,mn
ORDER BY city,mn;

-- 7. City and Monthwise Booking by New customers and Existed customers
WITH x AS (
SELECT city,new_date_of_booking,MONTHNAME(new_date_of_booking) AS month,customer_id,MONTH(new_date_of_booking) AS mn,
MIN(new_date_of_booking) OVER(PARTITION BY customer_id) AS first_booking
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id),
y AS (
SELECT city,month,mn,
COUNT(DISTINCT(CASE WHEN first_booking=new_date_of_booking THEN customer_id ELSE NULL END)) AS new_customer,
COUNT(DISTINCT(CASE WHEN first_booking<new_date_of_booking THEN customer_id ELSE NULL END)) AS repeated_customer
FROM x
GROUP BY city,month,mn
ORDER BY city,mn)
SELECT city,month,new_customer,repeated_customer,ROUND(repeated_customer*100/new_customer,2) AS repeated_to_new_ratio
FROM y
ORDER BY city,mn;

-- 8. Monthly Revenue Trend
SELECT city,MONTHNAME(new_check_in) AS month,MONTH(new_check_in) AS mn,SUM(amount-discount) AS revenue
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id
WHERE MONTH(new_check_in) BETWEEN 1 AND 3
GROUP BY City,month,mn
ORDER BY city,mn;

-- 9. Cities that generates 80% of total revenue
WITH x AS (
SELECT city,SUM(amount-discount) AS revenue
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id
GROUP BY city),
y AS (
SELECT city,revenue,
SUM(revenue) OVER(ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_sum,SUM(revenue) OVER() AS total_revenue,
0.8*SUM(revenue) OVER() AS 80_percent_revenue
FROM x)
SELECT *
FROM y
WHERE 80_percent_revenue>running_sum;

-- 10. Citywise Top customer
WITH x AS (
SELECT city,customer_id,COUNT(*) AS bookings
FROM dim_hotels h 
LEFT JOIN fact_bookings b 
ON h.Hotel_id=b.hotel_id
GROUP BY city,customer_id),
y AS (
SELECT *,
RANK() OVER(PARTITION BY city ORDER BY bookings DESC,customer_id ASC) AS rnk1,
RANK() OVER(PARTITION BY city ORDER BY bookings ASC,customer_id ASC) AS rnk2
FROM x)
SELECT city,
GROUP_CONCAT(CASE WHEN rnk1=1 THEN customer_id ELSE NULL END) AS top_customer_id,
GROUP_CONCAT(CASE WHEN rnk2=1 THEN customer_id ELSE NULL END) AS bottom_customer_id
FROM y
GROUP BY city;

-- 11
WITH x AS (
SELECT TIMESTAMPDIFF(DAY,new_date_of_booking,new_check_in) AS days_before_check_in,COUNT(*) AS bookings,
ROUND(AVG(TIMESTAMPDIFF(HOUR,new_check_in,new_check_out)),0) AS hours_stayed
FROM fact_bookings
GROUP BY days_before_check_in
ORDER BY days_before_check_in)
SELECT days_before_check_in,hours_stayed,ROUND(bookings*100/SUM(bookings) OVER(),2) AS booking_percentage
FROM x;
