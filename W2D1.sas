libname shop "/home/student/shop_db";
/* users.csv to users.sasdat로 변환 */
proc import datafile="/home/student/shop_csv/users.csv"
	out=shop.users
	DBMS=csv
	replace;
	getnames=Yes;
	guessingrows=1000;
	datarow=2;
Run;

proc import datafile="/home/student/shop_csv/orders.csv"
	out=shop.orders
	DBMS=csv
	replace;
	getnames=Yes;
	guessingrows=1000;
	datarow=2;
Run;


/* 사용자의 이름, 아이디, 나이, 지역을 출력 */
proc sql outobs=10;
	select user_id, name, age, city
	from shop.users;
quit;

/* data step seoul인 고객만 추출*/
data work.seoul_users;
	set shop.users;
	keep user_id name city;
	where city = '서울';
	run;

proc sql outobs=10;
	select * from work.seoul_users;
quit;

proc sql outobs=30;
	select * from shop.users
	where city = '서울'
	and age between 30 and 39;
quit;

proc sql outobs=20;
	select user_id, name, age, city, vip_grade
	from shop.users;
	select user_id, name, age, city, vip_grade
	from shop.users
	where city='서울';
quit;

proc sql outobs=10;
	select name as 고객명,
	age as 나이,
	age*12 as 개월수,
	cat(city, '', vip_grade) as 지역등급,
	vip_grade as 등급
from shop.users;
quit;
	
/* 실습문제 */
proc import datafile="/home/student/shop_csv/products.csv"
	out=shop.products
	DBMS=csv
	replace;
	getnames=Yes;
	guessingrows=1000;
	datarow=2;
Run;

proc sql outobs=10;
	select * from shop.products;
	quit;

proc sql outobs=10;
	select product_id, product_name,price as 정가, rating_avg 
	from shop.products;
quit;

proc sql outobs=10;
	select upcase(payment_method) as 결제수단,
    round(total_amount, 100) as 금액반올림 format=comma12.,
	substr(channel, 1, 3) as 채널약어,
	total_amount format=comma12. as 금액
	from shop.orders;
quit;

proc sql;
	select count(*) as 주문수 format=comma12.,
	sum(total_amount) as gmv format=comma15.,
	avg(total_amount) as aov format=comma12.,
	calculated gmv / calculated 주문수 as 재계산aov format=comma12.
	from shop.orders;
quit;

proc sql outobs=20;
select order_id, user_id, total_amount, status, channel from shop.orders
where status='paid' and total_amount >=100000
order by order_date desc;
quit;

/*write sql code of cutomer`s name, age, and region 
that region is seoul, busan, daegu*/
proc sql outobs=20;
	select name, age, city from shop.users
	where city in ('서울', '부산', '대구');
quit;



/*write sql code of cutomer`s name, age, and region 
that region is seoul, busan, daegu and surname is Kim*/
proc sql outobs=20;
select name, city, age from shop.users
where city in('서울', '부산', '대구')
and name like '김%';
quit;

proc sql outobs=20;
	select order_id, user_id, total_amount format comma12.0, status,
			channel, order_date format=YYMMDDS10.
	from shop.orders
	where status='paid'
	and total_amount >= 1000000
	order by order_date desc;
quit;

/*print customer`s name and channel which channel is NULL */
proc sql outobs=20;
	select name, channel from shop.users
	where channel is NULL;
quit;

proc sql outobs=100;
	select name as 고객명, vip_grade as 고객등급, total_spent as 총금액
	from shop.users
	order by 2, 총금액 desc;
quit;

/*count(*) count(user_id) count(distinct user_id)*/
proc sql;
	select count(*) as 총주문수, count(user_id) as 사용고객수, count(distinct user_id) as 유효고객수
	from shop.orders;
quit;


/*파일명이 .sasbdat이면 그냥 그 파일이 있는 폴더 libname으로 불러오면 됨*/

/*도시종류를 구하는데 count(*) count(city) count(distinct city)출*/
proc sql;
	select distinct city as 도시종류 from shop.users;
	select distinct channel as 채널종류 from shop.orders;
	select count(distinct user_id)as 활동고객 from shop.orders
	where status='paid';
quit;

proc sql;
	select distinct channel as 고객_채널종류 from shop.users;
	select distinct channel as 주문_챈널종류 from shop.orders;
quit;


/*전체주문수, 고객수, 인당주문수(전체고객수/고객)*/
proc sql;
	select count(order_id) as 전체주문수,
	count(distinct user_id) as 고객수, 
	calculated 전체주문수 / calculated 고객수 as 인당주문수
	from shop.orders where status='paid';
quit;
	
/*orders에서 총주문금액, 주문고객수, 인당주문금액, 정상거래만 status='paid'*/
proc sql;
	select sum(total_amount) format=comma15.0 as 총주문금액,
	count(distinct user_id) as 주문고객수,
	calculated 총주문금액 / calculated 주문고객수 as 인당주문금액
	from shop.orders where status='paid';
quit;

proc sql outobs=20;
	select name as 이름, age as 나이, 
	case when age >=60 then '시니어' else '청년' end as 연령대
	from shop.users ;
quit;


/*10대, 20대, 30대, 40대, 50대, 시니어 -> 연령대로 출력*/
proc sql outobs=20;
	select name as 이름, age as 나이,
	case when age<20 then '10대'
	when age<30 then '20대'
	when age <40 then '30대'
	when age<50 then '40대'
	when age <60 then '50대'
	else '시니어' end as 연령대
	from shop.users;
quit;

proc sql outobs=50;
	select name as 이름, age as 나이, total_spent as 총주문금액,
		case when age >= 60 then '시니어'
		when age>=40 then '중장년'
		when age >=20 then '청년'
		else '미성년' end as 연령대,
	case when total_spent >= 1000000 then 'VIP'
		when total_spent >=100000 then '우수'
		else '일반' end as 고객등급 
	from shop.users;
quit;






