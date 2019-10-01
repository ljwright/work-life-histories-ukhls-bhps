/*
********************************************************************************
Clean Non-Dependent Annual History.DO

	THIS FILE CLEANS ANNUAL EMPLOYMENT STATUS HISTORIES USING THE INDRESP AND
	JOBHIST FILES FROM WAVES 1-15 OF THE BHPS (NON-DEPENDENT INTERVIEWING).


********************************************************************************
*/

/**/
*1. Collate datasets and keep only observations from full or telephone interviews.
	/// Proxy interviews do not give jobhist information or start dates so are worthless.
	* All have end_type==0 because elicitation starts with current spell.
prog_reopenfile "${dta_fld}/BHPS 1-15 Jobhist"
append using "${dta_fld}/BHPS 1-15 Indresp"
merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ keepusing(Birth_Y IntDate_*Y ivfio) /*
	*/ keep(match) nogenerate
keep if inlist(ivfio,1,3) & !missing(IntDate_MY)
drop ivfio
sort pidp Wave Spell

gen End_Type=0
gen Start_Flag=0

* FILL IN JOB_HOURS
// by pidp Wave (Spell), sort: gen XX=Job_Hours[_n-1] /*
// 	*/ if Job_Change_R==2 & Status[_n-1]==2 & Job_Change_R[_n-1]!=2
// by pidp Wave (Spell), sort: replace XX=XX[_n-1] if missing(XX)
// replace Job_Hours=XX if Job_Change_R==2 & !missing(XX)
// drop XX


*2. Fill in data from indresp into jobhist data
by pidp Wave (Spell), sort: replace JobHistHas=JobHistHas[1]
gen LB_Y=Wave+1989
gen LB_MY=ym(LB_Y,9)
gen LB_SY=ym(LB_Y,4)

foreach i of numlist 1/11 97{
	gen End_Reason`i'=cond(End_Reason==.i,.i,cond(End_Reason==`i',1,.m))
	}
drop End_Reason

gen XX=Job_Attraction if Spell==1
by pidp Wave (Spell), sort: egen YY=max(XX)
replace Job_Attraction=cond(Spell==0 & !missing(YY),YY,.m)
replace Job_Attraction=.i if !inlist(Status,1,2,100)
foreach i of numlist 1/15 97{
	gen Job_Attraction`i'=cond(Job_Attraction==.i,.i,cond(Job_Attraction==`i',1,.m))
	}
drop Job_Attraction XX YY

gen Job_Change=.i if !inlist(Status,1,2,100)
by pidp Wave (Spell), sort: replace Job_Change=Job_Change_R[_n+1] /*
	*/ if inlist(Status,1,2,100) & inlist(Status[_n+1],1,2,100) /*
	*/ & _n<_N
by pidp Wave (Spell), sort: replace Job_Change=3 /*
	*/ if !inlist(Status[_n+1],1,2,100) & inlist(Status,1,2,100) & _n<_N
by pidp Wave (Spell), sort: replace Job_Change=3 /*
	*/ if inlist(Status[_n+1],1,2) & inlist(Status,1,2) & Status!=Status[_n+1]
by pidp Wave (Spell), sort: replace Job_Change=.m /*
	*/ if inlist(Status,1,2,100) & _n==_N
drop Job_Change_R


*3. Replace start date where...
	* After interview date but other informarion says it should be before.	
gen XX=.
foreach i in Y SY MY{
	replace XX=1 if /*
		*/ Start_`i'>IntDate_`i' & !missing(Start_`i',IntDate_`i') /*
		*/ & JobHistHas==1 & strpos(Source,"indresp")>0
	}
replace XX=1 if missing(Start_Y) & JobHistHas==1 & strpos(Source,"indresp")>0
foreach i in Y SY MY{
	replace Start_`i'=LB_`i' if XX==1
	}
replace Start_Flag=1 if XX==1
drop XX JobHistHas LB*


*5. Drop participants with non-chronological dates
	* (Requires reorder Spell to be chronological)
	* Also drop spells starting after End_Ind==0 because this is the current spell...
		* ...others are encompassed.
by pidp Wave (Spell), sort: replace Spell=_N-_n+1
prog_nonchron Start Y SY MY
by pidp Wave (Start_Y Start_SY Start_MY), sort: replace Spell=_n if NonChron_Wave==1
drop NonChron_Wave
	
by pidp Wave (Spell), sort: gen XX=Spell if End_Ind==0 & _n<_N
by pidp Wave (Spell), sort: egen YY=max(XX)
drop if Spell>YY & !missing(YY)
drop XX YY


*6. Impute correct season where Wave==2 & Season is Winter
prog_assignwinter


*7. Drop pidps with implausible dates.
	* Non-educational outcomes before age 12.
	* After interview date
prog_implausibledates Start
prog_afterint Start
drop Birth_Y


*8. Handle Spells with Missing Status
	*Delete if first spell at has missing status (carry out recursively)
	*Delete if has missing date data (assume imputted accidentally)
	*Delete if preceded or followed by same MY(assume imputted accidentally)
	*Arguably, what left with is informative: a spell which the participant wasn't sure what it was.
count if Spell==1 & missing(Status)
local i=`r(N)'
while `i'>0{
	drop if missing(Status) & Spell==1
	by pidp Wave (Spell), sort: replace Spell=_n
	count if Spell==1 & missing(Status)
	local i=`r(N)'
	}
	
by pidp Wave (Spell), sort: gen XX=1 if /*
	*/ (Start_MY==Start_MY[_n-1] | Start_MY==Start_MY[_n+1]) & missing(Status)
replace XX=1 if missing(Start_Y) & missing(Status)
count if XX==1
drop if XX==1
drop XX
by pidp Wave (Spell), sort: replace Spell=_n
by pidp Wave (Spell), sort: egen XX=max(missing(Status))
drop if XX==1
drop XX


*9. Impute equal dates and impute month from season.
prog_monthfromseason
drop *_SY MinAbove MaxBelow


*10. Run Common Code
do "${do_fld}/Clean Work History.do"


