libname shop "/home/student/shop_db";

Proc sql outobs=10;
	select name, channel,
	case channel
	when 'paid_search' then 'search ads'
	when 'social' then 'organic'
	when 'referral' then 'recommendation'
	else 'etc'
	end as channel_kr
	from shop.users;
quit;

/*연령대별 회원수를 출력 
	20대, 30대, 40대, 나머지는 50대+*/

proc sql outobs=100;
	select 
	case when age < 30 then '20s'
	when age <40 then '30s'
	when age <50 then '40s'
	else '50+'
	end as ages, 
	count(age) as member
	from shop.users
	group by calculated ages;
quit;


/*서울 30~50대 vip회원 top10*/
proc sql outobs=10;
	select user_id, name, city, 
	age , vip_grade, total_spent format=comma12.0 from  shop.users 
	where age between 30 and 50
	and city='서울'
	and vip_grade='vip'
	order by total_spent desc;
quit;

/*가입채널별 회원수+평균매출*/
proc sql;
	select channel, count(user_id) as channel_members,
	mean(total_spent) as average_spent
	from shop.users
	group by channel
	order by calculated average_spent desc;
quit;

/*연령대+등급 동시부여*/
proc sql outobs=100;
	select user_id, name, age, total_spent,
	case when age < 30 then '20s'
	when age <40 then '30s'
	when age <50 then '40s'
	else '50+'
	end as ages,
	case when total_spent > 1000000 then 'vip'
	when total_spent > 100000 then 'good'
	else 'general'
	end as grade
	from shop.users
	where age is not null
	order by age desc, total_spent desc;
quit;

proc sql;
	select count(*) as numbe_of_order,
	sum(total_amount) as whole_spent format=comma15.0,
	mean(total_amount) as avg_amount format=comma12.0,
	min(total_amount) as min format=comma6.0,
	max(total_amount) as max format=comma12.0
from shop.orders;
quit;

/*결제 정상주문 + 채널별정렬 (where+order  다중)*/
/*활성회원 분류 (case when+last_login_date)*/

proc sql;
	select channel,
	count(*) as numbe_of_order,
	sum(total_amount) as whole_spent format=comma15.0,
	mean(total_amount) as avg_amount format=comma12.0
	from shop.orders
	where status='paid'
	group by channel;
quit;

/*위에서 device만 추가해서 group by 해보기*/
proc sql;
	select channel,device,
	count(*) as numbe_of_order,
	strip(put(sum(total_amount),comma15.)) || '원' as whole_amount,
	mean(total_amount) as avg_amount format=comma12.0
	from shop.orders
	where status='paid'
	group by channel, device;
quit;

proc sql;
	/*고객의 등급별 주문, 채널별 주문수, 매출총액,*/
	select u.vip_grade as custo_grade, 
	o.channel as order_channel, 
	count(o.order_id) as total_order, 
	sum(o.total_amount) as whole_amount
	from shop.users as u, shop.orders as o
	where u.user_id = o.user_id	and o.status='paid'
	group by u.vip_grade, o.channel;
quit;


proc sql;
	/*고객의 가입채널명, 매출총액 단 매출총액이 500만원
	이상인 채널만 매출총액이 많은 채널수으로 출력*/
	select channel, sum(total_amount) as whole_amount format=comma15.0
	from shop.orders
	group by channel
	having calculated whole_amount >= 25000000000
	order by calculated whole_amount desc;
quit;

proc sql;
	/*고객별 누적매출, 주문수를 출력, 누적매출이 500만원
	이상인 고객만 20건만 출력
	주문건수가 1건 이상인 고객, 정상주문만 누적매출 많은 순서로
	*/
	select user_id, sum(total_amount) as whole_amount format=comma15.0,
	count(user_id) as number_order
	from shop.orders
	where status='paid'
	group by user_id
	having calculated whole_amount >= 5000000
	order by  whole_amount desc;
quit;

proc sql;
	/*연도별 주문수, 주문총액 그리고 항상 정상주문만*/
	select year(order_date) as year,
	count(*) as order_number,
	sum(total_amount) as whole_amount
	from shop.orders
	where status='paid'
	group by calculated year
	order by whole_amount desc;
quit;
	

proc sql outobs=30;
	/*날짜함수 year(), month(), day(), qtr()
	intnx('month', orderdate, 0, 'B')*/
	/*고객명, 마지막접속한 연, 월, 일, 분기,
	접속한 달의 1일 출력*/
	select name, year(last_login_date) as last_year,
	month(last_login_date) as last_month,
	day(last_login_date) as last_day,
	qtr(last_login_date) as quantile,
	intnx('month', last_login_date, 0, 'B') format=yymmdd10. as 마지막접속월,
	intnx('month', last_login_date, 1, 'E') format=yymmdd10. as 마지막접속다음월 
	from shop.users
	where last_login_date is not null
	order by last_year,last_month,last_day;	
quit;

/*월별 주문수, 매출총액을 영구저장을 하려고한다 
	-> momthly_kpi 테이블명*/
proc sql;
	create table shop.monthly_kpi
	as select intnx('month', order_date, 0, 'b') format yymmdd8. as 월,
		count(*) as 주문수, sum(total_amount) as 매출액
	from shop.orders
	group by calculated 월
	order by 월;
quit;

proc sql;
	select * from shop.monthly_kpi;
quit;

proc sql;
	create view shop.vw_monthly_kpi
	as select intnx('month', order_date, 0, 'b') format yymmdd8. as 월,
		count(*) as 주문수, sum(total_amount) as 매출액
	from shop.orders
	where calculated 월 >=260701
	group by calculated 월
	order by 월;
quit;

proc sql outobs=10;
	select * from shop.vw_monthly_kpi;
quit;

proc sql outobs=1;
	select year(order_date), month(order_date) from shop.orders;
quit;

PROC SQL;
   CREATE VIEW shop.vw_channel_monthly_1 AS
   SELECT channel  AS 채널,
   YEAR(order_date)*100 + MONTH(order_date) AS 년월,
   COUNT(*)  AS 주문수  FORMAT=COMMA10.,
   SUM(total_amount)  AS 매출  FORMAT=COMMA15.
   FROM shop.orders
   WHERE order_date >= '01JAN2025'd
   group by channel, calculated 년월;
quit; 

proc sql;
	select * from shop.vw_channel_monthly_1
	order by 채널, 년월;
quit;

proc sql;
	select u.vip_grade as 고객등급, o.channel as 주문채널,
	count(o.order_id) as 총주문수, sum(o.total_amount) as 총매출액
	from shop.users as u inner join shop.orders as o 
		on u.user_id=o.user_id
	where o.status='paid'
	group by u.vip_grade, o.channel
	order by o.channel;
quit;

	/*고객명, 주문일자, 상품id, 주문금액을 출력: 정상거래만,
	users, orders, order_items join
	1. order_items.csv -> sas database로 shop_db에 저장
	2. 컬럼정보확인
	3. 쿼리문장작성 */
proc import datafile="/home/student/shop_csv/order_items.csv"
	out=shop.order_items
	DBMS=csv
	replace;
	getnames=Yes;
	guessingrows=1000;
	datarow=2;
Run;

proc sql outobs=100;
	select u.name, o.order_date, oi.item_id, o.total_amount,
			p.product_name
	from shop.orders as o inner join shop.users as u 
		on o.user_id = u.user_id
	inner join shop.order_items as oi 
		on o.order_id=oi.order_id
	inner join shop.products as p
	on oi.product_id=p.product_id
	where o.status='paid'
	order by item_id asc;
quit;

/*상품명별로 누적주문건수와 누적주문금액을 출력*/

proc sql;
	select p.product_name as 상품명, 
	count(oi.order_id) as 누적주문건수,
	sum(oi.line_total) format=comma20. as 누적주문금액
	from shop.products as p inner join shop.order_items as oi
		on p.product_id=oi.product_id
	inner join shop.orders as o 
		on oi.order_id=o.order_id
	group by p.product_name;
quit;
	
proc sql;
	/*channel별 상품명별 누적주문금액*/
	select p.product_name as 상품명, 
	sum(oi.line_total) format=comma20. as 누적주문금액,
	o.channel as 채널
	from shop.products as p inner join shop.order_items as oi
		on p.product_id=oi.product_id
	inner join shop.orders as o 
		on oi.order_id=o.order_id
	group by p.product_name, o.channel;
quit;

PROC SQL OUTOBS=20;
   SELECT u.user_id  AS 고객ID,
   u.name  AS 고객,
   u.signup_date FORMAT=YYMMDDS10. AS 가입일,
   u.vip_grade  AS 등급
   FROM shop.users AS u
   LEFT JOIN shop.orders AS o
   ON u.user_id = o.user_id
   WHERE o.order_id IS NULL
   ORDER BY u.signup_date;
QUIT;

proc sql outobs=20;
	select p.product_name as 상품명,
	sum(oi.line_total) format=comma20. as 누적주문금액
	from shop.products as p 
		left join shop.order_items as oi
		on p.product_id=oi.product_id
	group by p.product_name;
quit;


proc sql;
/*실습1: 등급별+월별매출추세 */
	select u.vip_grade as grade , month(o.order_date) as order_month , count(o.order_id), sum(o.total_amount)
	from shop.users as u inner join shop.orders as o on u.user_id=o.user_id
	where  o.order_date >= '01JAN2025'd
	group by calculated grade, calculated order_month
	order by  grade, order_month;
quit;

proc sql;
/*실습2: 휴먼고객명단+2025q1가입*/
	select u.user_id, u.name, u.city, u.signup_date
	from shop.users as u left join shop.orders as o on u.user_id=o.user_id
	where o.user_id is null 
	and	year(u.signup_date)=2025
	and qtr(u.signup_date) = 1;
quit;
proc sql outobs=10;
	/*실습3: 인기상품 탑10 영구저장 */
	create table shop.top_products
	as select p.product_name, p.brand, sum(oi.quantity) as total_quantity, 
		sum(oi.line_total) as total_line
		from shop.products as p inner join shop.order_items as oi on 
		p.product_id=oi.product_id
		group by p.product_name
		order by total_line desc;
quit;
proc sql;
/*실습4: 채널별+월별매출추세 */
	select p.product_name, p.brand, sum(oi.quantity) as total_quantity, sum(oi.line_total) as total_line
	from shop.products as p inner join shop.order_items as oi on p.product_id=oi.product_id
	
quit;
proc sql;
/*실습5: 지역별 VIP 비율 VIEW */
	select
quit;
