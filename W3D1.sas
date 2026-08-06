libname shop "/home/student/shop_db";
proc import datafile='/home/student/shop_csv/orders_dirty.csv'
	out=shop.orders_dirty
	dbms=csv
	replace;
	getnames=Yes;
	guessingrows=max;
run;

/*ctrl+/ 누르면 주석처리 됨 
	컬럼의 데이터 타입 확인 */
title '컬럼 정보확인';
proc contents data=shop.orders_dirty; run;

/*적재   */
title '처음 5행 데이터보기';
proc print data=shop.orders_dirty (obs=5);
run;
title '적재된 데이터갯수 확인'
proc sql; 
	select count(*) from shop.orders_dirty; quit; 
title;

proc print data=sashelp.cars (obs=10);
run;

proc contents data=sashelp.cars;run;

/*shop.users-adding tax column where tax=total_spent*0.1 and save
	as work.temp and print reatining total_amount by channel and
save as shop.user_tax */

data work.temp ;
	set shop.users;
	tax=total_spent * 0.1;
run;

proc sort data=work.temp; by channel; run;

DATA work.temp;
    SET work.temp;
    BY channel;

    RETAIN cum_sales;   /* 누적값을 유지할 변수 선언 */

    IF FIRST.channel THEN cum_sales = 0;   /* 새 channel 시작하면 0으로 리셋 */
    cum_sales + total_spent; /* 누적 합산 (RETAIN 자동 적용) */
	keep user_id channel age tax total_spent cum_sales;
run;

data shop.user_tax;
	set work.temp;
run;

proc contents data=shop.user_tax; run;

proc means data=shop.users_dirty maxdec=3;
var age;
run;

proc means data=shop.users_dirty n mean median Q1 Q3 maxdec=3 /*소숫점 3자리까지*/;
/* var age ; */  
run;

proc means data=shop.users_dirty sum skewness p95 maxdec=1 ;
var age;
run;

proc means data=shop.users_dirty min max range mode nmiss n maxdec=2 ;
var age;
run;

proc means data=shop.users_dirty n mean sum maxdec=1;
	var age;
	class channel;
run;

/*채널별 성별 교차  */
proc means data=shop.users_dirty n mean std maxdec=1;
var age;
class channel signup_device gender;
types channel * gender;
run;

proc means data=shop.users_dirty n mean std maxdec=1;
var age;
class channel gender;
/* types channel * gender; */
run;

/*output out=정정하고자 하는 파일명 */
proc means data=shop.users_dirty noprint;
	var age;
	class channel;
	output out=ch_stats N=cnt mean=age_mean std=age_std;
/*cnt는 결측값 제외 값 	 */
run;

/*작성된 데이터 출력*/
proc print data=ch_stats noobs;
	where _TYPE_=1;
	var channel cnt age_mean age_std;
	format age_mean age_std 8.1; 
/*8.1은 SAS의 숫자 포맷으로, 전체 자리수 8, 소수점 이하 1자리로 값을 표시하라는 뜻*/
run;

proc sgplot data=work.ch_stats;
	where _TYPE_=1;
	Vbar channel / response=age_mean;
	xaxis label = 'signup channel';
	yaxis label = 'avg revenue'; 
run;

proc means data=shop.users_dirty;
run;

proc means data=shop.users_dirty maxdec=2;
	var age;
	class channel gender;
	output out=ch_stats_2;
run;

proc print data=ch_stats_2 noobs;
	where _TYPE_ not in (0,1);
run;

/*누적제외  */
proc freq data=shop.users_dirty;
	tables channel / noCUM;
	/*/ 뒤에 오는 건 옵션이란 뜻 */
run;

/* 빈도순으로 정렬 */
proc freq data=shop.users_dirty order=freq;
/*freq: 빈도가 큰 순서  
  internal: 빈도가 작은 순서*/
	tables channel / nocum;
run;

/* 결측값 포함 */
proc freq data=shop.users_dirty;
	tables gender / nocum missing;
run;

/*막대그래프 작성  */
proc freq data=shop.users_dirty order=freq;
	tables channel / nocum plots=freqplot;
run;

/* 2차원 교차표 -> gender * channel */
proc freq data=shop.users_dirty;
	tables channel * gender;
run;

proc freq data=shop.users_dirty;
	tables channel * gender / nocol ; /*칼럼백분율제외*/
run;

proc freq data=shop.users_dirty;
	tables channel * gender / norow nocol nopercent;
run;

proc freq data=shop.users_dirty;
	tables gender * city *channel;
run;

data users_freq;
	set shop.users;
	year=year(signup_date);
	keep year channel gender;
run;

proc freq data=users_freq;
	tables channel * gender /chisq expected;
run;

/* orders에 있는 channel과 device를 가지고 proc freq 작성 
실습에있는  */
/* step 1 */
proc freq data=shop.orders;
	tables channel /nocum;
run;
/* step 2 */
proc freq data=shop.orders;
	tables channel * device  /norow nocum;
run;
/* step 3 */
proc freq data=shop.orders;
tables channel * device / chisq;
run;
/* step 4 */
proc freq data=shop.orders;
	tables channel * device /chisq;
	 output out=work.ch_cross;
run;	
/* step 5 */


/*정규성 검정 + QQ plot  */
proc univariate data=shop.orders normal;
	var total_amount;
	histogram total_amount / normal;
	qqplot total_amount / normal(mu=est sigma=est);
run;


/* 1) NODUPKEY 기본 */
PROC SORT DATA=mylib.users OUT=u_uniq NODUPKEY;
BY user_id;
RUN;
/* 1005 → 1000 (중복 5 제거) */
/* 2) DUPOUT - 중복 따로 */
PROC SORT DATA=mylib.users
OUT=u_uniq DUPOUT=u_dup NODUPKEY;
BY user_id;
RUN;
PROC PRINT DATA=u_dup; RUN; /* 중복 5행 */
/* 3) NODUPLICATES - 모든 컬럼 동일 */
PROC SORT DATA=mylib.users
OUT=u_dup_all NODUPLICATES;
BY user_id;
RUN;
/* 4) MERGE 전 양쪽 정렬 */
PROC SORT DATA=mylib.users; BY user_id; RUN;
PROC SORT DATA=mylib.orders; BY user_id; RUN;
DATA combined; MERGE users orders; BY user_id; RUN;


