%let userid=&sysuserid;
/*   %&_   */
/*  ""   ()   */
%let root = /home/&userid;
%put &userid &dir;

%let db=shop_db;
libname shop "&root/&db";

/*% 목표 %let으로 yyyymm cutoff 정의 후 title/where/file에 적용  &*/

%let yyyymm=202611; %let cutoff=100000; %let report_root=&root/reports;

ods pdf file="&report_root/&yyyymm._revenue.pdf";
title "&yyyymm monthly revenue (cutoff=&cutoff) ";

data month;
	set shop.orders;
	where put(order_date, yymmn6.)= "&yyyymm"
		and total_amount >= &cutoff;
run;

proc print data=month(obs=20) noobs; run;
title;
ods pdf close;

/* 매크로변수 응용 */
%let target =paid;
%let min_amt= 50000;
%let top_n = 10;

proc sql outobs=&top_n;
	select order_id, user_id, total_amount, channel
	from shop.orders
	where status="&target"
	and total_amount >= &min_amt
	order by total_amount desc;
quit;

/*session2: %macro ~ %mend*/
%macro vip_report(grade=);
	proc print data=shop.users (obs=10);
	where vip_grade="&grade"; var user_id name total_spent vip_grade;
run;
%mend;
%vip_report(grade=gold);
%vip_report(grade=silver);

/*channel별 kpi -> 주문건수, 주문총금액 -> 정상거래만,
	channle을 값을 받아서 실행   */
%macro ch_kpi(ch=);
	title "&ch 채널 kpi";

	proc sql;
	select "&ch" as channel length=15,
	count(*) as 주문건수, sum(total_amount) as 주문총금액 format=comma15.
	from shop.orders
	where status='paid' and channel="&ch";
	quit;
	title;

%mend;

%ch_kpi(ch=organic);

/*다중매개변수+기본값  */
/*채널 및 나이 하한값, 상한값 -> top_n출력 */
%macro ch_age_kpi(ch=organic, lo=20, hi=60, top=10);
	title "&ch(&lo~&hi 세 ) top=&top";
	
	proc sql outobs=&top;
		select o.channel,u.user_id, u.name, u.age, o.total_amount
		from shop.users u inner join shop.orders o on u.user_id=o.user_id
		where u.age between &lo and &hi
		and o.channel = "&ch"
		and o.status='paid'
		order by o.total_amount desc;
	quit; 
	title;
%mend;

%ch_age_kpi(); /*기본값 설정에 대해서 쭉 나옴*/
%ch_age_kpi(ch=paid_search); /*나머지는 기본값인 lo=20 hi=60 top=10*/
%ch_age_kpi(ch=social, lo=5, hi=40, top=30); 

options mprint mlogic symbolgen; /*디버깅시작 */
%ch_age_kpi();
options nomprint nomlogic nosymbolgen; /*디버깅종료*/

/*  vip 등급별 매크로 - kpi집계 -> vip_kpi(grade=)
	grade, 건수, 평균주문액, 평균주문건수 format 8.1*/
%macro vip_kpi(grade=);
	title "vip grade : &grade stat.";
	proc sql ;
/* 	select "&grade" as vip_grade length=10,  */
	select vip_grade,
	count(*) as 건수, 
	avg(total_spent) as 평균주문액 format=comma12.,
	avg(order_count) as 평균주문건수 format=8.1
	from shop.users
	where vip_grade="&grade";
	quit; 
	title;
%mend;

%vip_kpi(grade=gold);
%vip_kpi(grade=bronze);
%vip_kpi(grade=silver);


proc sql outobs=10;
	select "test", 10 from shop.users;
quit;


/*session 3: %do %if  */
%macro yearly_pdf(year=);
	%do m=1 %to 12;
		%let m2=sysfunc(putn(&m, z2.));
		%let ym=&year.&m2;
		ods pdf file="&report_root/&ym.revebue.pdf";
		proc print data=shop.orders;
			where put(order_date, yymm6.)="&ym";
		run;
		ods pdf close;
	%end;
%mend;
%yearly_pdf(year=2024);

%let channels=organic paid_search social referral email other;
%macro loop_channels_before;
	%do i=1 %to 6;
	%let ch=%scan(&channels,  &i);
	%put [&i] &ch;
	%ch_kpi(ch=&ch);
%end;
%mend;
%loop_channels_before;

/*users에서 검색해서 channels를생성  */
proc sql;
	select distinct channel into :channels separated by " "
	from shop.users;
quit;
%put channels: &channels; /*이 query로 channel에 있는 값들을 알 수 있음*/

%macro loop_channels;
	%do i=1 %to 6;
	%let ch= %scan(&channels, &i);
	%put [&i] &ch;
	%ch_kpi(ch=&ch);
%end;
%mend loop channels;

%loop_channels;

