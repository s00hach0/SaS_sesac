/*session 1: 결측치 처리연습  */
libname shop "/home/student/shop_db";

proc sql;
	select count(*), sum(missing(email)),
	sum(missing(city)), sum(missing(age)), sum(age=999),
	sum(age<0) from shop.users_dirty;
quit;

data shop.users_clean;
    set shop.users_dirty;
    length age_grp $6 email_status $10;
    if missing(age) then age=0;
    if age=999 or age <0 then delete;
    age_grp=floor(age/10)*10;
    format signup_date datetime16.;
run;

/* before preprocessing data */
proc freq data=shop.users_dirty;
	tables age city / nocum missing;
run;

/* after preprocessing  data*/
proc freq data=shop.users_clean;
	tables age city / nocum missing;
run;

title 'after users_clean status';
proc sql;
	select count(*), sum(missing(email)),
	sum(missing(city)), sum(missing(age)), sum(age=999),
	sum(age<0) from shop.users_clean;
quit;
title;

/* session 2  */
data work.users_chk;
	set shop.users_dirty;
	if missing(age) then age_missing =1;
		else age_missing=0;
	nmiss_cnt=nmiss(age, total_spent);
	cmoss_cnt=cmiss(age, email, city);
	if not missing(age) and age > 0 then
		age_valid=1;
run;

proc print data=users_chk (obs=10);
	var age total_spent email nmiss_cnt age_valid cmoss_cnt;
run;

title '결측진단-users_dirty';
proc means data=shop.users_dity n nmiss;
	var age;
run;

/*  age 평균으로 결츠값 대체 */
proc sql noprint;
	select mean(age), median(age) into :age_mean, :age_med
	from shop.users_dirty
	where age between 1 and 99;
quit;
%put 정상평균 = &age_mean 중앙값=&age_med;

/*age가 결측이면 중앙값으로 대체 -> 결과확인user2*/
data user2; set shop.users_dirty;
	if age=. then age = &age_med;
run;

/*이상치를 null로 바꾸고 null데이터처리*/
data user3;
	set shop.users_dirty;
	if age=999 or age < 1 then age=.;
	if age=. then age = &age_med;
	if missing(city) then city='unknown';
	if missing(gender) then gender='u';
	if missing(email) then email='no email';
run;

title '이상치 처리전';
proc sql;
	select count(*) as n_total,
	sum(missing(city)) as n_city_null,
	sum(missing(email)) as n_email_null,
	sum(age=999) as n_age_999,
	sum(age<0) as n_age_neg
from shop.users_dirty; quit;

title '이상치 처리후';
proc sql;
	select count(*) as n_total,
	sum(missing(city)) as n_city_null,
	sum(missing(email)) as n_email_null,
	sum(age=999) as n_age_999,
	sum(age<0) as n_age_neg
from user3; quit;

title;

/*coalescec() 함수로 결측값 처리 */
%let personal_email = 'abcd@naver.com';
data user4; set shop.users_dirty;
	email_fix=coalescec(email, &personal_email, 'unknown');
	keep user_id name email email_fix;
run;

proc print data=user4(obs=5);
	where missing(email);
run;

/* 결측행 제거 */
data user5;
	set shop.users_dirty;
	if missing(age) or missing(city) then delete;
run;

proc sql;
	select count(*) as users_dirty_rows from shop.users_dirty;
	select count(*) as user5_rows from user5;
quit;



/* 실습 2-결측처리 */
proc freq data=shop.users_dirty;
	tables age city email / nocum nopercent missing ;
run;

data work.u_zero; set shop.users_dirty;
	if age=. or age=-1 then age=0;
	if city='' then city= '미상';
run; 

data work.u_coalesce; set shop.users_dirty;
	age=coalesce(age, 0);
	city=coalescec(city, '미상');
	email=coalescec(email, 'no-email');
run;

data work.u_delete; set shop.users_dirty;
	if missing(age) or missing(city) or missing(email) then delete;
run;

proc sql;
	select 'u_zero' as ds length=15,
	 count(*) as n from  work.u_zero
	union all select 'u_coalesce', count(*) from work.u_coalesce
	union all select 'u_delete', count(*) from work.u_delete;
quit;

/* session 3 이상치 제거 및 처리 */
/* IQR 기준으로 범위지정 */
proc means data=shop.users_dirty N min max q1 q3 maxdec=2;
	var age;
run;

/* (1) 단순하게 값 제거 방법*/
data u_no_outlier ; set shop.users_dirty;
	if age=999 then delete;
	if age < 0 then delete;
	if age > 120 then delete;
run;
proc means data=u_no_outlier N min max q1 q3 maxdec=2;
	var age;
run;

/*iQR 기준으로 범위지정  */
proc means 

/* (2) IQR기준으로 제거 */
proc univariate data=shop.users_dirty;
	var age;
run;
%let q1=27;
%let q3=42;

/*  */

/*계산된 통계량을 매크로변수에 저장  */
proc sql noprint;
	select min(age), max(age), pctl(25, age), pctl(75,age)
		into :age_min, :age_max, :age_q1, :age_q3
	from shop.users_dirty
	where age > 0 ;
quit;

%put &age_q1 &age_q3;
%put &q1 &q3;

/*iQR 및 상ㅎ하한 경계값 계산  */
%let iqr=%sysevalf(&age_q3-&age_q1);
%let low=%sysevalf(&age_q1-1.5*&iqr);
%let high=%sysevalf(&age_q3+1.5*&iqr);

%put iqr: &iqr, lower_bound:&low, upper_bound:&high;

data work.users_no_outlier; set shop.users_dirty;
	if age > &high then delete;
	if age < &low then delete;
run;

/* orders_dirty데이터셋에서 total_amount 이상치제거. IQR기준 하한과 상한을
	검색한 뒤 화면에 출력, orders_dirty에 적용한 뒤 orders_clean 생성 */
proc univariate data=shop.orders_dirty;
	var total_amount;
run;
%let total_q1=53040;
%let total_q3=907110;
	

data orders_clean; set shop.orders_dirty;
	if total_amount > &total_q3+1.5*&total_q3 then delete;
	if total_amount < &total_q3-1.5*&total_q1 then delete;
run;

proc means data=orders_clean n min max; 
	var total_amount;
run;

proc means data=shop.orders_dirty n min max; 
	var total_amount;
run;

/*other method  */
proc means data=shop.orders_dirty;
	where order_status='paid';
	var total_amount;
	output out=orders_iqr
		min=t_min
		max=t_max
		p25=t_q1
		p75=t_q3;
run;

proc sql;
	select t_q1, t_q3 into :t_q1, :t_q3 from orders_iqr; 
quit;

%let iqr=%sysevalf(&t_q3-&t_q1);
%let lo=%sysevalf(&t_q1-1.5*&iqr);
%let hi=%sysevalf(&t_q3+1.5*&iqr);


data orders_clean_1; set shop.orders_dirty;
	if total_amount > &hi then delete;
	if total_amount < &lo then delete;
run;

/*1%와 99% 백분위수 계산 후 테이블로 저장  */

proc means data=shop.users_dirty;
	where age>0 and age<99;
	var age;
	output out=work.age_pctl p1=age_p1 p99=age_p99;
run;

proc sql;
	select age_p1, age_p99
	into :age_p1, :age_p99
	from work.age_pctl;
quit;

/* 비대칭분포정규화 */
data work.orders_log;
	set shop.orders_dirty;
	where total_amount > 0 ;
	amt_log=log(total_amount);
run;

title 'log transformation-normaility achieve';
proc univariate data=work.orders_log normal noprint;
	var total_amount amt_log;
	histogram total_amount amt_log / normal;
run;
title;


/* session 4 문자변환함수  */
data work.users_scan; set shop.users;
	length email_id $30 email_dom $30
			city_main $10 city_dist $20;

/* email-id/domain	 */
	email_id=scan(email, 1, '@');
	email_dom=scan(email, 2, '@');
	/*domain company*/
	email_co=scan(email_dom, 1, '.');
	
	city_main=scan(city,1,'');
	city_dist=scan(city,2,'');
run;

/* 도메인별 카운트 */
proc freq data=work.users_scan order=freq;
	tables email_dom / nocum;
run;

/*session4 실습   */
proc freq data=shop.users_dirty;
	tables channel / nocum;
run;

data work.u_clean_str;
	set shop.users_dirty;
	length channel_u $20 email_fix &50 email_dom $20 city_main $10;
	
	channel_u=upcase(strip(channel)); /*대소문자+공백*/
	email_fix=tranwrd(email, '_at_', '@');
	email_dom =scan(email_fix, 2, '@');
run;

/* session 5 날짜변환 */
data work.users_date;
	set shop.users;
	length _s_str $25;
	 /*문자 -> date*/
	_s_str=strip(vvalue(signup_date));
	signup_d=input(_s_str, anydtdte25.);
	format signup_d YYMMDD10.;

	/*문자 -> datetime*/
	signup_dt=input(_s_str, anydtdtm25.);
	format signup_dt datetime16.;

	/*특정형식 -date9.*/
	d1=input('01JAN2025', date9.);

	/*특정형식 -yymmdd*/
	d2=input('2025-01-01', yymmdd10.);

	format d1 date9. d2 yymmdd10.;
	drop _s_str;
run;

proc print data=users_date(obs=10);
	var signup_date signup_d signup_dt d1 d2;
run;

/*put - 날짜(num)->문자(chr)*/
DATA work.users_put;
	SET work.users_date;
	/* 1) 월별 키 */
	month_key = PUT(signup_d, YYMMN6.);
	/* → "202501" */
	/* 2) 한국 표기 */
	signup_kr = PUT(signup_d, YYMMDD10.);
	/* → "2025-01-01" */
	/* 3) 요일 (영문) */
	wkday = PUT(signup_d, DOWNAME.);
	/* → "Wednesday" */
	/* 4) 월 이름 */
	mon_name = PUT(signup_d, MONNAME.);
	/* → "January" */
RUN;
/* PROC FREQ - 월별 가입 분포 */
PROC FREQ DATA=work.users_put;
TABLES month_key / NOCUM;
RUN;


DATA work.users_d;
	SET shop.users;
	/* 1) DATETIME → DATE */
/* 	signup_d = DATEPART(signup_date); /*이미 date여서 date만 뽑으려하면 초기화됨 */
	signup_d = signup_date;
	FORMAT signup_d YYMMDD10.;
	/* 2) 시간만 */
	signup_t = TIMEPART(signup_date);
	FORMAT signup_t TIME8.;
	/* 3) 연·월·일·요일 */
	signup_year = YEAR(signup_d);
	signup_month = MONTH(signup_d);
	signup_day = DAY(signup_d);
	signup_wkday = WEEKDAY(signup_d);
	signup_qtr = QTR(signup_d);
	/* 4) DATE → DATETIME */
	d_only = INPUT("2025-01-01", YYMMDD10.);
	dt_new = DHMS(d_only, 10, 30, 0);
	FORMAT dt_new DATETIME16.;
	keep signup_date signup_d signup_t signup_year signup_month
		signup_day signup_wkday signup_qtr;
RUN;

