/*
********************************************************************************
BHPS WAVES 16-8.DO

	THIS FILE CLEANS ANNUAL EMPLOYMENT STATUS HISTORIES USING THE INDRESP AND
	JOBHIST FILES FROM WAVES 16-18 OF THE BHPS.


********************************************************************************
*/

/*
	1. VARIABLES TO COLLECT
*/
/**/
#delim ;
global vlist 	" jbstat jbft_dv jbhas jboff jbck7 jbsempp jbsempr
				jbck8 jbprom jbchgm jbchgy jbchgy4 jbchgly jbcspl
				jbsemp payck1 jbbgm1 jbbgy1 jbbgy41 jbbgly jsck1
				jssame jsbgm1 jsbgy1 jsbgy41 jsbgly cjsck1 cjsbgm
				cjsbgy cjsbgy4 cjsbly cjsck2 cjsck3 cjsstly cjsem
				cjsey cjsey4 cjscjs cjsck4 jhstpy ivfio jhstat jhcjs
				jhendm jhendy jhendy4 jhck1
				jhck2 jhsemp jblky jspno" ;
#delim cr
*/


/*
	2. COLLECT INDRESP DATA
*/
/**/
forval i=16/$bhps_waves{
	local j: word `i' of `c(alpha)'	
	prog_addprefix vlist b`j' "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}"
	rename b`j'_* *
	gen Wave=`i'
	drop if ivfio==2
	tempfile Temp`i'
	save "`Temp`i''", replace	
	}
if $bhps_waves>16{
	forval i=`=$bhps_waves-1'(-1)16{
		append using "`Temp`i''"
		}
	}
merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ keep(match master) keepusing(IntDate* Prev_Job_Hours LB*) nogen
drop if missing(IntDate_MY)
drop *_S *_SY

order pidp Wave
xtset pidp Wave
prog_recodemissing *
save "${dta_fld}/BHPS 16-18 Annual History - Indresp", replace
*/


/*
	3. COLLECT JOBHSTD DATA
*/
/**/
forval i=16/$bhps_waves{
	local j: word `i' of `c(alpha)'	
	prog_getvars vlist b`j' "${fld}/${bhps_path}_w`i'/b`j'_jobhstd${file_type}"
	rename b`j'_* *
	gen Wave=`i'
	tempfile Temp`i'
	save "`Temp`i''", replace	
	}
if $bhps_waves>16{
	forval i=`=$bhps_waves-1'(-1)16{
		append using "`Temp`i''"
		}
	}
merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ keep(match master) keepusing(IntDate_MY) nogen
drop if missing(IntDate_MY)
	
order pidp Wave jspno
prog_recodemissing *
save "${dta_fld}/BHPS 16-18 Annual History - Jobhstd", replace
*/


/*
	4. FORMAT DATASETS
*/
/**/
/*
	CONTINUOUS SPELL
	inlist(cjsck1,1,2,4) |  (cjsck1==6 & cjsbly==1)
*/
use "${dta_fld}/BHPS 16-18 Annual History - Indresp", clear
keep if inlist(cjsck1,1,2,4) | (cjsck1==6 & cjsbly==1)

gen Spell=1

gen Status=.m
replace Status=1 if inlist(cjsck1,1,2) & jbsemp==2
replace Status=2 if inlist(cjsck1,1,2) & jbsemp==1
replace Status=4 if cjsck1==4
replace Status=jbstat if cjsck1==6 & cjsbly==1
replace Status=100 if inlist(cjsck1,1,2) & missing(jbsemp)

gen Start_MY=LB_MY
replace Start_MY=ym(jbbgy41,jbbgm1) /*
	*/ if inrange(jbbgy41,1890,2009) & inrange(jbbgm1,1,12)
replace Start_MY=ym(jbbgy41,12) /*
	*/ if jbbgy41<LB_Y & inrange(jbbgy41,1890,2009) & missing(jbbgm1)
gen End_MY=IntDate_MY

gen Start_Flag=1
replace Start_Flag=0 /*
	*/ if inrange(jbbgy41,1890,2009) & inrange(jbbgm1,1,12)
replace Start_Flag=4 /*
	*/ if jbbgy41<LB_Y & inrange(jbbgy41,1890,2009) & missing(jbbgm1)
gen End_Flag=1

gen Job_Hours=jbft_dv if inlist(Status,1,2,100)
replace Job_Hours=.m if missing(Job_Hours) & inlist(Status,1,2,100)
replace Job_Hours=.i if !inlist(Status,1,2,100)
gen Job_Change=0 if cjsck1==1 & inlist(Status,1,2,100)
replace Job_Change=.m if inlist(Status,1,2,100) & missing(Job_Change)
replace Job_Change=.i if !inlist(Status,1,2,100)

gen End_Ind=0
gen Source_Variable="jbsemp_w"+strofreal(Wave) if inlist(cjsck1,1,2)
replace Source_Variable="jbstat_w"+strofreal(Wave) if cjsck1==4 | (cjsck1==6 & cjsbly==1)
gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_indresp"

keep pidp Wave Spell Status Start_MY End_MY Job_Hours Job_Change /*
	*/ Start_Flag End_Flag Source_Variable Source IntDate_MY End_Ind
save "${dta_fld}/BHPS 16-18 Annual History", replace
*/


/**/
/*
	NOT CONTINUOUS OR HAS CJS* VARIABLES
	(inlist(cjsck1,3,5) | (cjsck1==6 & cjsbly!=1))
	& inlist(cjscjs,1,.m)
*/
use "${dta_fld}/BHPS 16-18 Annual History - Indresp", clear
keep if inlist(cjsck1,3,5) | (cjsck1==6 & cjsbly!=1)

expand 2 if cjsck1==6, gen(Spell)
replace Spell=Spell+1

gen Status=cond(cjsstly==10,97,cjsstly) if Spell==1
replace Status=jbstat if Spell==2
replace Status=.m if missing(Status)

gen Job_Hours=Prev_Job_Hours if Spell==1
replace Job_Hours=jbft_dv if Spell==2
replace Job_Hours=.i if !inlist(Status,1,2,100)
replace Job_Hours=.m if inlist(Status,1,2,100) & missing(Job_Hours)

gen Job_Change=cond(inlist(Status,1,2,100),.m,.i)

gen Source_Variable="cjsstly_w"+strofreal(Wave) if Spell==1
replace Source_Variable="jbstat_w"+strofreal(Wave) if Spell==2
gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_indresp"

foreach i in M Y MY{
	gen End_`i'=IntDate_`i' if (Spell==1 & cjscjs==1) | Spell==2
	}
replace End_M=cjsem /*
	*/ if Spell==1 & cjscjs==.i & inrange(cjsey4,1900,2010)
replace End_Y=cjsey4 /*
	*/ if Spell==1 & cjscjs==.i & inrange(cjsey4,1900,2010)
replace End_MY=ym(cjsey4,cjsem) /*
	*/ if Spell==1 & cjscjs==.i & inrange(cjsey4,1900,2010)
recode End_* (missing=.m)

preserve
	keep if cjscjs==.i
	drop if Spell==2
	gen End_Ind=1
	keep pidp Wave Spell Status End_M End_Y End_Ind Job_* Source* jhstpy
	save "${dta_fld}/BHPS 16-18 Annual History - Collected", replace
restore
drop if cjscjs==.i

foreach i in M Y MY{
	gen Start_`i'=LB_`i' if Spell==1
	}
replace Start_M=cjsbgm if Spell==2 /*
	*/ & ym(cjsbgy4,cjsbgm)!=LB_MY & inrange(cjsbgy4,1900,2010)
replace Start_Y=cjsbgy4 if Spell==2 /*
	*/ & ym(cjsbgy4,cjsbgm)!=LB_MY & inrange(cjsbgy4,1900,2010)
replace Start_MY=ym(cjsbgy4,cjsbgm) if Spell==2 /*
	*/ & ym(cjsbgy4,cjsbgm)!=LB_MY & inrange(cjsbgy4,1900,2010)
recode Start_* (missing=.m)

drop if Start_Y>End_Y & !missing(Start_Y,End_Y)
drop if Start_MY>End_MY & !missing(Start_MY,End_MY)

gen End_Flag=cond((Spell==1 & cjscjs==1) | Spell==2,1,0)
gen Start_Flag=cond(Spell==1,1,0)

replace Start_Flag=4 if !missing(Start_Y) & missing(Start_MY) /*
	*/ & End_Y>Start_Y & !missing(End_Y)
replace Start_MY=ym(Start_Y,12) if !missing(Start_Y) & missing(Start_MY) /*
	*/ & End_Y>Start_Y & !missing(End_Y)
replace Start_MY=ym(Start_Y,1) if !missing(Start_Y) & missing(Start_MY) /*
	*/ & End_Y==Start_Y & !missing(End_Y) & End_M==1
	
replace End_Flag=4 if !missing(End_Y) & missing(End_MY) /*
	*/ & End_Y>Start_Y & !missing(Start_Y)
replace End_Y=ym(End_Y,1) if !missing(End_Y) & missing(End_MY) /*
	*/ & End_Y>Start_Y & !missing(Start_Y)
replace End_MY=ym(End_Y,12) if !missing(End_Y) & missing(End_MY) /*
	*/ & End_Y==Start_Y & Start_M==12		

replace Start_Flag=5 if !missing(End_MY) & missing(Start_MY)
replace Start_MY=End_MY-1 if !missing(End_MY) & missing(Start_MY)
replace End_Flag=5 if missing(End_MY) & !missing(Start_MY)
replace End_MY=Start_MY+1 if missing(End_MY) & !missing(Start_MY)
replace End_Flag=1 if !missing(End_MY) & End_MY>IntDate_MY
replace End_MY=IntDate_MY if !missing(End_MY) & End_MY>IntDate_MY

by pidp Wave (Spell), sort: drop /*
	*/ if Spell==1 & Start_MY[2]<Start_MY[1] & cjscjs!=.i
// by pidp Wave (Spell), sort: drop /*
// 	*/ if Spell==2 & Start_MY[2]<Start_MY[1] & cjscjs==.i
by pidp Wave (Spell), sort: replace Spell=_n

by pidp Wave (Spell), sort: gen N=_N
gen End_Ind=0 if Spell==2
// replace End_Ind=1 if cjscjs==.i & Spell==1
replace End_Ind=0 if cjscjs==1 & Spell==1 & N==1 
replace End_Ind=1 if cjscjs==1 & Spell==1 & N==2 
replace End_Ind=.m if cjscjs==.m & Spell==1 & N==1
replace End_Ind=1 if cjscjs==.m & Spell==1 & N==2
drop N

keep pidp Wave Spell Status Start_MY End_MY Job_* /*
	*/ Start_Flag End_Flag Source_Variable Source IntDate_MY End_Ind
append using "${dta_fld}/BHPS 16-18 Annual History"
foreach i of numlist 1/11 97{
	gen End_Reason`i'=.m if inlist(Status,1,2,100)
	replace End_Reason`i'=.i if !inlist(Status,1,2,100)
	}
foreach i of numlist 1/15 97{
	gen Job_Attraction`i'=.m if inlist(Status,1,2,100)
	replace Job_Attraction`i'=.i if !inlist(Status,1,2,100)
	}
	
save "${dta_fld}/BHPS 16-18 Annual History", replace
*/

/*
		//	(inlist(cjsck1,3,5) | (cjsck1==6 & cjsbly!=1)) & cjscjs==.i
*/
use "${dta_fld}/BHPS 16-18 Annual History - Jobhstd", clear	
merge m:1 pidp Wave using "${dta_fld}/BHPS 16-18 Annual History - Indresp", /*
	*/ nogen keep(match master) keepusing(jbsemp jbft_dv)

by pidp Wave (jspno), sort: gen Spell=_n+1
drop jspno
	
gen Status=cond(inrange(jhstat,3,9),jhstat,.m)
replace Status=1 if jhsemp==3 | (inlist(jhstat,1,2) & jbsemp==2 & jhck1==3)
replace Status=2 if inlist(jhsemp,1,2) | (inlist(jhstat,1,2) & jbsemp==1 & jhck1==3)
replace Status=97 if jhstat==97
replace Status=100 if missing(Status) & inlist(jhstat,1,2)

gen Job_Hours=.i if !inlist(Status,1,2,100)
replace Job_Hours=jhsemp if inlist(jhsemp,1,2)
replace Job_Hours=jbft_dv if inlist(jhstat,1,2) & jhck1==3
replace Job_Hours=.m if inlist(Status,1,2,100) & missing(Job_Hours)
tab Status Job_Hours, m

gen Job_Change=.i if !inlist(Status,1,2,100)
replace Job_Change=jhstat+1 if inlist(jhstat,1,2)

by pidp Wave (Spell), sort: gen End_M=jhendm /*
	*/ if inrange(jhendy4,1900,2010) & _n<_N
by pidp Wave (Spell), sort: gen End_Y=jhendy4 /*
	*/ if inrange(jhendy4,1900,2010) & _n<_N
recode End_* (missing=.m)

by pidp Wave (Spell), sort: gen End_Ind=cond(_n<_N,1,0)

gen Source_Variable="jhstat_w"+strofreal(Wave)
gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_jobhstd"

append using "${dta_fld}/BHPS 16-18 Annual History - Collected"
gen End_Reason=jhstpy if inrange(jhstpy,1,11)
replace End_Reason=97 if inlist(jhstpy,12,13)
replace End_Reason=.i if !inlist(Status,1,2, 100)
replace End_Reason=.m if inlist(Status,1,2, 100) & missing(End_Reason)
foreach i of numlist 1/11 97{
	gen End_Reason`i'=cond(End_Reason==.i,.i,cond(End_Reason==`i',1,.m))
	}
drop End_Reason

gen Job_Attraction=jblky if inrange(jblky,1,15)
replace Job_Attraction=15 if jblky==16
replace Job_Attraction=97 if jblky==96
replace Job_Attraction=.i if !inlist(Status,1,2, 100) & missing(Job_Attraction)
replace Job_Attraction=.m if inlist(Status,1,2, 100) & missing(Job_Attraction)
foreach i of numlist 1/15 97{
	gen Job_Attraction`i'=cond(Job_Attraction==.i,.i,cond(Job_Attraction==`i',1,.m))
	}
drop Job_Attraction

keep pidp Wave Spell Status End_* Job_* Source*
do "${do_fld}/Clean Dependent Annual History.do"

/*
	Merge Together and Sort Out Wave Overlap
*/
/**/
append using "${dta_fld}/BHPS 16-18 Annual History"
prog_waveoverlap
prog_collapsespells

prog_format
save "${dta_fld}/BHPS 16-18 Annual History", replace
*/

rm "${dta_fld}/BHPS 16-18 Annual History - Collected.dta"
rm "${dta_fld}/BHPS 16-18 Annual History - Jobhstd.dta"
rm "${dta_fld}/BHPS 16-18 Annual History - Indresp.dta"
