/*
********************************************************************************
UKHLS INITIAL SPELL.DO
	
	THIS FILE CREATES A DATASET OF JOB START DATES FROM FIRST UKHLS INTERVIEW.

	
********************************************************************************
*/

/*
1. Dataset Preparation.
	A. Collate raw data.
*/
forval i=1/$ukhls_waves{
	local j: word `i' of `c(alpha)'
	use pidp `j'_jb* `j'_ivfio using /*
		*/ "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}" /*
		*/ if (`j'_jbhas==1 | `j'_jboff==1) & `j'_ivfio==1, clear
	gen Wave=`i'+18
	gen Source="`j'_indresp"
	rename `j'_* *
	tempfile Temp`i'
	save "`Temp`i''", replace
	}
forval i=1/`=$ukhls_waves-1'{
	append using "`Temp`i''"
	}
keep pidp Wave Source jbstat jbsemp jbbgm jbbgy jbft_dv
merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ nogen keep(match) keepusing(IntDate_MY Birth_MY Next_*)
drop if missing(IntDate_MY) | missing(Birth_MY)
drop if jbbgm==-8
by pidp (Wave), sort: keep if _n==1


/*
2. Dataset Cleaning.
	A. Create Start and End Dates and Flags.
*/
gen Start_M=jbbgm /*
	*/ if jbbgm>0 & jbbgy>0 & !missing(jbbgm, jbbgy)
gen Start_Y=jbbgy if jbbgy>0 & !missing(jbbgy)
drop jbbg*

gen Start_MY=ym(Start_Y,Start_M)
gen Start_Flag=0

gen XX=1 if missing(Start_MY) & Start_Y<year(dofm(IntDate_MY))
replace Start_MY=ym(Start_Y,12) if XX==1
replace Start_Flag=4 if XX==1
drop XX
	
gen XX=1 if missing(Start_MY) & Start_Y==year(dofm(IntDate_MY)) /*
	*/ & month(dofm(IntDate_MY))>1
replace Start_MY=IntDate_MY-1 if XX==1
replace Start_Flag=4 if XX==1
drop XX

gen XX=1 if missing(Start_M) & missing(Start_Y)
replace Start_MY=IntDate_MY-1 if XX==1
replace Start_Flag=5 if XX==1
drop XX

gen End_MY=IntDate_MY
gen End_Flag=1


//	DROP IMPLAUSIBLE DATES
qui prog_makeage Start_MY
drop if Start_MY_Age<=10 | Start_MY>=End_MY
drop Start_? *Age Birth_MY

// CREATE JOB CHARACTERISTICS
gen Status=Next_ff_jbstat if inlist(Next_ff_jbstat,1,2)
replace Status=3-Next_ff_jbsemp /*
	*/ if inlist(Next_ff_jbsemp,1,2) & missing(Status) & missing(Next_ff_jbstat)
replace Status=jbstat /*
	*/ if inlist(jbstat,1,2) & missing(Status)
replace Status=3-jbsemp /*
	*/ if inlist(jbsemp,1,2) & missing(Status) & jbstat<0
drop if missing(Status)

gen Source_Variable="ff_jbstat_w"+strofreal(Next_Wave) /*
	*/ if inlist(Next_ff_jbstat,1,2)
replace Source_Variable="ff_jbsemp"+strofreal(Next_Wave) /*
	*/ if inlist(Next_ff_jbsemp,1,2) & missing(Source_Variable) & missing(Next_ff_jbstat)
replace Source_Variable="jbstat"+strofreal(Wave) /*
	*/ if inlist(jbstat,1,2) & missing(Source_Variable)
replace Source_Variable="jbsemp"+strofreal(Wave) /*
	*/ if inlist(jbsemp,1,2) & missing(Source_Variable) & jbstat<0
gen Spell=0
gen Status_Spells=1
gen End_Ind=0

gen Job_Hours=cond(inlist(jbft_dv,1,2),jbft_dv,.m)
gen Job_Change=.m
foreach i of numlist 1/15 97{
	if !inrange(`i',12,15){
		gen End_Reason`i'=.m
		}
	gen Job_Attraction`i'=.m
	}

drop *jb* Next*
format *MY %tm
order pidp Wave Status Job* Start_MY End_MY *Flag
sort pidp Wave

save "${dta_fld}/UKHLS Initial Job", replace
