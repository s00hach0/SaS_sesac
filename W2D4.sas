libname mylib "/home/student/shop_db";
libname shop "/home/student/shop_db";

proc sql;
	create table mylib.monthly_kpi as
	select
		intnx('month', order_date, 0, 'B') as month format=yymmdd8.,
	    count(*) as order_number,
		sum(total_amount) as whole_amount format=dollar12.,
		avg(total_amount) as avg_amount format=dollar12.
	from shop.orders where status='paid'
	group by intnx('month', order_date, 0, 'B');
quit; 

proc sql noprint;
	select count(*) into :n_users
	from shop.users;
quit;

%put 회원수: &n_users;

proc sql noprint;
	select user_id into : vip_list seperated by ','
	from shop.users
	where vip_grade='gold';
quit;

%put vip_list : &vip_list;

proc sql outobs=10;
	select user_id, vip_grade
	from shop.users
	where user_id in (&vip_list);
quit;

%let tbl=shop.users;
proc sql outobs=10;
	select user_id, vip_grade
	from &tbl
	where user_id in (&vip_list);
quit;

/*202601 이후 주문한 내역만 출력*/
%let day= '01JAN26'd;
proc sql;
	select * from shop.orders
	where order_date > &day;
quit;

%let year =2026;
proc sql;
	create table shop.kpi_&year as
	select * from shop.orders
	where order_date > &day;
quit;

/*고객명, 고객의 매출총합, 마지막주문일자, 주문건수를 출력
	1단계: users에서 gold또는 vip회원의 명단만 동적변수에 저장 후
	2단계: 1단계에서 저장한 고객만 해당자료 추출*/

proc sql noprint;
	/*step 1*/
	select user_id into : vip_list separated by ','
	from shop.users
	where vip_grade = 'gold'
	order by vip_grade;
quit;

proc sql outobs=20;
	select u.name, u.total_spent, 
	(select max(order_date) from shop.orders where user_id=u.user_id) as last_order_date,
	(select count(*) from shop.orders where user_id=u.user_id) as order_count
	from shop.users u inner join shop.orders o on u.user_id=o.user_id
	where u.user_id in (&vip_list);
quit;

/*library 검색*/
/*테이블의 정보*/
proc sql;
	select memname, nobs as row_number, crdate as create_date
	from dictionary.tables
	where libname='SHOP' /*라이브러리는 대소문자 구분*/;
quit;

proc sql outobs=10;
	select * from dictionary.tables;
quit;

proc sql;
	select name as column, type, length
	from dictionary.columns
	where libname = 'SHOP'
	and memname='USERS';
quit;

/*dictionary tables의 컬럼정보 확인 */
proc sql;
	select name as column, type, length
	from dictionary.columns
	where libname = 'DICTIONARY'
	and memname='TABLES';
quit;

/*index정보*/
proc sql;
	select * from dictionary.indexes
	where libname = 'SHOP';
quit;

/*라이브러리정보확인*/
proc sql;
	select * from dictionary.members;
quit;

proc sql;
	select memname as table_name, name as column_name,
	type as data_type, length
	from dictionary.columns
	where libname = "SHOP"
	and memname IN ('USERS','ORDERS');
quit;

/*user_id컬럼이 존재하는 테이블명을 검색 */
proc sql;
	select memname, name, type
	from dictionary.columns
	where libname = 'SHOP'
	and upcase(name) like '%USER_ID%';
quit;

/*전체데이터의 사이즈*/
proc sql;
	select libname, count(*) as 테이블갯수, sum(nobs) as 총행갯수
	from dictionary.tables
	group by libname;
quit;

proc sql;
	select t.memname as table, t.nobs as 행, t.crdate as 생성일 format=datetime20.,
	count(c.name) as columns
	from dictionary.tables as t 
	left join dictionary.columns as c on t.libname=c.libname
		and t.memname=c.memname
	where t.libname = 'SHOP'
	group by t.memname, t.nobs, t.crdate
	order by t.memname;
quit;

/*index생성전 */
proc sql;
	select * from shop.orders
	where user_id=42;
quit;

proc sql _METHOD;
	select * from shop.orders
	where user_id=42;
quit;

/*index 생성 -> orders의 user_id 컬럼 */
proc sql;
	create index user_id on shop.orders(user_id);
quit;

proc sql;
	select * from dictionary.indexes
	where libname='SHOP';
quit;

proc sql;
	select * from dictionary.indexes
	where libname = 'SHOP';
quit;

/*주문 상품명, 총주문 상품별로 금액 */

proc sql _method;
	select p.product_name, sum(oi.line_total) as order_amount
	from shop.order_items oi inner join shop.products p on oi.product_id=p.product_id
	group by p.product_name;
quit;

/*products(product_id)를 index로*/
proc sql;	
	create index product_id on shop.products(product_id);
quit;

/*orders -> user_id, order_date 복합 인덱스 생성 : idx_user_date
	고객명, 주문일자, 주문총액 
	260101이후 주문한 내용중 고객id가 42인 고객의주문만
	주문일자로 정렬*/
proc sql;
	create index idx_user_date on shop.orders(order_date, user_id);
quit;

proc sql;
	select u.name, o.order_date, sum(o.total_amount) as whole_amount
	from shop.users u inner join shop.orders o on u.user_id=o.order_id
	where o.user_id=42 and	
		o.order_date > '01JAN2026'd
	group by  o.order_date, o.user_id;
quit;

options fullstimer msglevel=N;
	
proc sql;
	create table cust_sales as	select	
	user_id, count(*) as order_number, sum(total_amount) as whole_amount
	from shop.orders where status='paid'
	group by user_id;
quit;

/*기존데이터에서 column추가할 수 있음*/
data cust_seg;
	set cust_sales;
	length 등급 $10 캠페인 $30;
	if whole_amount >= 1000000 then do;
		등급='vip'; 캠페인='vip행사초대'; end;
	else if whole_amount >= 500000 then do;
		등급 = 'gold'; 캠페인='신상품우선안내'; end;
	else if whole_amount >= 100000 then do;
		등급 = 'silver'; 캠페인='10%할인쿠폰'; end;
	else  do;
		등급 = 'bronze'; 캠페인='복귀30%쿠폰'; end;
run;

proc sql outobs=20;
	select * from cust_seg;
quit;

/*빈도, 비율, 백분율 계산하는 proc freq*/
proc freq data=cust_seg;
	tables 등급;
run;

/*고객의 첫 주문내역 user_id, order_id, order_date, total_amount
	출력을 해보려고 함 */
proc sort data=shop.orders out=sorted_orders;
	by user_id order_date;
run;

/*고객의 첫주문만 테이블생성*/
data first_orders;
	set work.sorted_orders;
	by user_id;
	if first.user_id;
run;

/*누적매출 cum_orders 생성 고객별 */
data cum_orders;
	set sorted_orders;
	by user_id;
	retain 누적매출 0;
	if first.user_id then 누적매출=0;
	누적매출+total_amount;
	format 누적매출 dollar15.;
run;

proc sql outobs=20;
	select user_id, order_date, total_amount, 누적매출
	from cum_orders;
quit;

/*고객의 마지막 주문만 테이블 생성 */
data last_orders;
	set work.sorted_orders;
	by user_id;
	if last.user_id;
run;

/*고객의 첫 주문과 마지막 주문의 일자 주문금액 출력*/
proc sql outobs=50;
	select f.user_id as user_number, 
	f.order_date format yymmdd10. as first_order_date,
	f.total_amount as first_total_amount,
	l.order_date format yymmdd10. as last_order_date,
	l.total_amount as last_total_amount 
	from first_orders f inner join last_orders l on f.user_id=l.user_id;
quit;


/*sas base vs viya case 속도비교*/
options fullstimer;

/*디스크기반 순차처리*/
proc sql;
	select u.vip_grade,
	count(*) as order_number,
	sum(o.total_amount) as whole_sales,
	avg(o.total_amount) as avg
	from shop.orders o inner join shop.users u on o.user_id=u.user_id
	where status='paid'
	group by u.vip_grade
	order by whole_sales desc;
quit;

/*cas환경*/
cas mysession;
caslib _all_ assign;

proc cas;
	builtins.serverStatus;
quit;

/*sas data -> cas memory로 load*/
proc casutil;
	load data = shop.orders outcaslib='casuser'
	casout='orders' replace;
	load data=shop.users outcaslib='casuser'
	casout='users' replace;
quit;

/*cas 메모리기반-병렬처리 */
proc fedsql sessref=mysession;
	select u.vip_grade,
	count(*) as order_number,
	sum(o.total_amount) as whole_sales,
	avg(o.total_amount) as avg
	from casuser.orders o inner join casuser.users u on o.user_id=u.user_id
	where status='paid'
	group by u.vip_grade
	order by whole_sales desc;
quit; /*cpu시간이 거의 10배 빨라짐*/

proc casutil;
	load data=shop.orders outcaslib='public'
	casout='orders' promote;
quit; 

cas mysession terminate; /*cas환경종료하기 */