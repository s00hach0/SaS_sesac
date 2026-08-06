libname shop "/home/student/shop_db";
/*주문번호, 주문금액, 주문평균, 주문금액이 주문평균보다 큰 경우만 */

proc sql outobs=100;
	select order_id, total_amount, 
	(select avg(total_amount) from shop.orders) as mean_order
	from shop.orders
	where total_amount > (select avg(total_amount) from shop.orders);
quit;

/*평균초과 탑텐 구하기*/
proc sql outobs=10;
	select order_id, total_amount, 
	(select avg(total_amount) from shop.orders) as mean_order,
	total_amount - (select avg(total_amount) from shop.orders) as diff
	from shop.orders
	where total_amount > (select avg(total_amount) from shop.orders)
	order by diff desc;
quit;

proc sql;
	select u.vip_grade, sum(o.total_amount) as grade_amount format=comma15.0
	from shop.users as u inner join shop.orders as o 
		on u.user_id=o.user_id
	where o.status='paid'
	group by u.vip_grade
	having sum(o.total_amount) > (select avg(o.total_amount) from shop.orders 
		where status='paid') * 100
	order by grade_amount;
quit;

proc sql outobs=15;
	select order_id, total_amount format=dollar12.,
	(select max(total_amount) from shop.orders) format=dollar12. as whole_max,
	(select min(total_amount) from shop.orders) format=dollar12. as whole_min,
	(select std(total_amount) from shop.orders) as sd,
	(total_amount-select(avg(total_amount) from shop.orders)) /
		(select std(total_amount) from shop.orders) as z_score format=8.2
	from shop.orders
	order by abs(z_score) desc;
quit;	

/* 고객 자신의 등급의 평균 주문액보다 많은 고객의 정보
	주문번호, 등급, 주문액*/
proc sql outobs=15;
	select order_id, vip_grade, total_amount,
	(select avg(total_amount) from shop.orders where user_id  in
		(select user_id from shop.users where u.vip_grade=vip_grade)) as 등급평균 
	from shop.orders o inner join shop.users u on u.user_id=o.user_id
	where o.total_amount > (
	/*고객등급의 평균주문액 보다 */
	select avg(total_amount) from shop.orders o2
	inner join shop.users u2 on o2.user_id=u2.user_id
	where u.vip_grade=u2.vip_grade);
quit;

proc sql ;
	/*등급별 매출+취소율+우수필터 */
	select u.vip_grade, 
	count(*) as whole_order,
	sum(case when status='paid' then o.total_amount
		else 0 end) as general_revenue,
	sum(case when status='cancelled' then 1 
		else 0 end ) / count(*) as canceled_rate
	from shop.users u inner join shop.orders o on u.user_id=o.user_id
	group by vip_grade
	having calculated general_revenue > 100000000;
quit;	

/*등급별지역별 정상매출, 추소매출*/
proc sql;
	select u.vip_grade,	u.city,
	count(*) as whole_order,
	sum(case when status='paid' then total_amount else 0 end) as general_revenue,
	sum(case when status='cancelled' then total_amount else 0 end) as cancelled_revenue
	from shop.users u inner join shop.orders o on u.user_id=o.user_id
	group by vip_grade, city
	having calculated cancelled_revenue >0;
quit;

/*1단계 테이블조인->새로운테이블형성*/
proc sql;
	create table work.joined as 
	select o.order_id, u.vip_grade, o.order_date, o.total_amount
	from shop.orders o inner join shop.users u on o.user_id=u.user_id;
quit;
/*2단계 work.joined 정렬 */
proc sort data=work.joined;
	by vip_grade order_date;
run; /*joined 테이블이 정렬되어있음 */

/*3단계 등급내 누적합->data+retain*/
data work.result;
	set work.joined;
	by vip_grade;
	retain 등급내누적 0;
	if first.vip_grade then 등급내누적=0;
	등급내누적+total_amount;
run;

proc sql outobs=60;
	select * from work.result;
quit;

/*화면에 테이블데이터 출력0*/
proc print data=work.result(obs=20);
	var vip_grade order_date total_amount 등급내누적;
run;

proc sql;
	create view work.vip_vw as
	select user_id from shop.users where vip_grade='gold';

	create view big_orders_vw as
	select * from shop.order where total_amount > 50000;
quit;