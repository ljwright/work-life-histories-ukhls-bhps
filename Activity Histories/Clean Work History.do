/*
********************************************************************************
CLEAN WORK HISTORY.DO
	
	THIS FILE WORK HISTORIES WHICH HAVE START AND END Y, SY, AND MY AND END
	INDICATORS.

********************************************************************************
*/

*1. Collapse into single spell
	*NOTE FORMULA FOR USING SY PRESUMES EACH SEASON OF SAME LENGTH. NOT TRUE.
	*XX: MIGHT BE WORTH RECODING MISSING_*DATE TO 2 & 3 IN ANNUAL HISTORY FOR CONSISTENCY.
prog_missingdates
gen XX=0
replace XX=1 if MissingDates==0
by pidp Wave (Spell), sort: replace XX=1 /*
  */ if _n==1
by pidp Wave (Spell), sort: replace XX=1 /*
  */ if Status!=Status[_n-1] | Job_Hours!=Job_Hours[_n-1]
by pidp Wave (Spell), sort: gen Status_Spell=sum(XX)

by pidp Wave Status_Spell (Spell), sort: gen YY=_n if MissingDates==1
by pidp Wave Status_Spell (Spell), sort: egen ZZ=min(YY)
by pidp Wave Status_Spell (Spell), sort: replace XX=1 if ZZ==_n & MissingDates[1]==2
by pidp Wave (Spell), sort: replace Status_Spell=sum(XX)

by pidp Wave Status_Spell (Spell), sort: gen Status_Spells=_N
drop XX YY ZZ

prog_range
count if Status_Spells>1
if `r(N)'>0{		
preserve
	keep if Status_Spells>1

	by pidp Wave Status_Spell (Spell), sort: replace End_Ind=End_Ind[_N]
	by pidp Wave Status_Spell (Spell), sort: /*
		*/ replace Job_Change=cond(inlist(Status,1,2,100),4,.i)
	by pidp Wave Status_Spell (Spell), sort: /*
		*/ gen XX=max(ym(Start_Y,1),Start_MY)
	by pidp Wave Status_Spell (Spell), sort: /*
		*/ egen MinEnd_MY=max(XX)
	by pidp Wave Status_Spell (Spell), sort: /*
		*/ replace MinEnd_MY=max(MinEnd,MaxBelow_MY,ym(MaxBelow_Y,1))	
	drop XX

	gen Reverse=-Spell
	foreach var of varlist Source*{
		by pidp Wave Status_Spell (Reverse), sort: /*
			*/ replace `var'=`var'+"; "+`var'[_n-1] /*
			*/ if _n>1 & strpos(`var'[_n-1],`var')==0
		}	
	foreach var of varlist End_Reason* Job_Attraction*{
		by pidp Wave Status_Spell (Spell), sort: egen XX=sum(`var')
		by pidp Wave Status_Spell (Spell), sort: egen YY=sum(missing(`var'))
		replace `var'=XX if YY<Status_Spells
		replace `var'=.i if !inlist(Status,1,2,100) & `var'!=.i
		replace `var'=.m if inlist(Status,1,2,100) & missing(`var')
		drop XX YY		
		}
	by pidp Wave Status_Spell (Spell), sort: drop if _n>1
	drop Reverse
	tempfile Temp
	save "`Temp'", replace
restore
}
	
drop if Status_Spells>1
if "`Temp'"!=""{
	append using "`Temp'"
	recode MinEnd_MY (missing=.m)
	}
by pidp Wave (Spell), sort: replace Spell=_n
drop Status_Spell MinAbove* MaxBelow* Gap


* 2. Impute dates if less than tolerated gap length
prog_imputeequaldates Y MY
prog_missingdates
forval i=1/2{
	prog_range
	if `i'==1{
		gen XX=1 if inrange(Gap,1,$gap_length) & MissingDates==1
		}
	else if `i'==2{
		by pidp Wave (Spell), sort: gen XX=1 /*
			*/ if inrange(Gap,1,$gap_length) & MissingDates==2 /*
			*/ & MinAbove_MY[_n-1]<=MaxBelow_MY
		by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: replace XX=XX[1]
			// BECAUSE MINABOVE[_n-1] NOT WHAT I WANT WHERE _n>1
		}

	by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: gen YY=sum(Status_Spells)
	by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: gen n=cond(_n==1,1,YY[_n-1]+1)
	by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: gen N=(YY[_N])

	replace Start_Flag=3 if XX==1 
	by pidp Wave MinAbove_MY MaxBelow_MY (Spell), sort: replace Start_MY=floor( /*
		*/ MaxBelow_MY+(n*(MinAbove_MY-MaxBelow_MY)/(N+1))) /*
		*/ if XX==1
	drop XX YY n N
	}

replace Start_Y=year(dofm(Start_MY)) if !missing(Start_MY)
prog_range
prog_missingdates


* 3. Create Indicator to Drop Spell after Truncation
gen DropSpell=0
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==1 & MissingDates[_n+1]==1 /*
	*/ & Start_Y==Start_Y[_n+1]
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==1 & MissingDates[_n+1]==2
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==2 & MissingDates[_n+1]>0 /*
	*/ & _n<_N
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==2 & _n==_N & End_Ind!=0
by pidp Wave (Spell), sort: replace DropSpell=1 /*
	*/ if MissingDates==1 & _n==_N & End_Ind!=0

	
* 4. Truncate Start Dates where gap greater than tolerance
	*a. Set Start_MY=Start_MY[_n+1]-1
by pidp Wave (Spell), sort: gen XX=Start_MY[_n+1]-1 /*
	*/ if MissingDates==2 & MissingDates[_n+1]==0 /*
	*/ & (Start_MY[_n+1]-1>=MaxBelow_MY | _n==1)
replace Start_MY=XX if !missing(XX)
replace Start_Flag=5 if !missing(XX)
drop XX	

by pidp Wave (Spell), sort: replace Start_MY=Start_MY[_n+1]-1 /*
	*/ if MissingDates==1 & MissingDates[_n+1]==0 /*
	*/ & Start_MY[_n+1]-1>=MaxBelow_MY /*
	*/ & Start_Y==Start_Y[_n+1] & month(dofm(Start_MY[_n+1]))>1

	*b. Set Start_MY=Start_MY[_n+1]
by pidp Wave (Spell), sort: replace Start_MY=Start_MY[_n+1] /*
	*/ if MissingDates==2 & MissingDates[_n+1]==0 /*
	*/ & Start_MY[_n+1]==MaxBelow_MY
by pidp Wave (Spell), sort: replace Start_MY=Start_MY[_n+1] /*
	*/ if MissingDates==1 & MissingDates[_n+1]==0 /*
	*/ & Start_MY[_n+1]==MaxBelow_MY
by pidp Wave (Spell), sort: replace Start_MY=Start_MY[_n+1] /*
	*/ if MissingDates==1 & MissingDates[_n+1]==0 /*
	*/ & Start_Y==Start_Y[_n+1] & month(dofm(Start_MY[_n+1]))==1
	
	*c. Set Start_MY=IntDate_MY-1
by pidp Wave (Spell), sort: gen XX=IntDate_MY-1 /*
	*/ if MissingDates==2 & _n==_N & End_Ind==0 /*
	*/ & IntDate_MY-1>=MaxBelow_MY
replace Start_MY=XX if !missing(XX)
replace Start_Flag=5 if !missing(XX)
drop XX		

by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY-1 /*
	*/ if MissingDates==1 & _n==_N & End_Ind==0 /*
	*/ & IntDate_MY-1>=MaxBelow_MY /*
	*/ & Start_Y==IntDate_Y & month(dofm(IntDate_MY))>1

	*d. Set Start_MY=IntDate_MY
by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY /*
  */ if MissingDates==2 & _n==_N & End_Ind==0 /*
  */ & IntDate_MY==MaxBelow_MY
by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY /*
  */ if MissingDates==1 & _n==_N & End_Ind==0 /*
  */ & IntDate_MY==MaxBelow_MY
by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY /*
  */ if MissingDates==1 & _n==_N & End_Ind==0 /*
  */ & Start_Y==IntDate_Y & month(dofm(IntDate_MY))==1

	*e. Set Start_MY=ym(Start_Y,12)
by pidp Wave (Spell), sort: gen XX=ym(Start_Y,12) /*
  */ if MissingDates==1 & MissingDates[_n+1]<2 /*
  */ & Start_Y<Start_Y[_n+1]
replace Start_MY=XX if !missing(XX)
replace Start_Flag=4 if !missing(XX)
drop XX			
	
by pidp Wave (Spell), sort: gen XX=ym(Start_Y,12) /*
  */ if MissingDates==1 & _n==_N & End_Ind==0 /*
  */ & Start_Y<IntDate_Y
replace Start_MY=XX if !missing(XX)
replace Start_Flag=4 if !missing(XX)
drop XX	

replace Start_Y=year(dofm(Start_MY)) if !missing(Start_MY)


* 5. Create End Dates
gen End_MY=.m
gen End_Flag=0
format *MY %tm
order pidp Wave Spell Start_MY End_MY End_Ind
	
	*a. Set End_MY=IntDate_MY
by pidp Wave (Spell), sort: gen XX=IntDate_MY /*
  */ if _n==_N & End_Ind==0
replace End_MY=XX if !missing(XX)
replace End_Flag=1 if !missing(XX)
drop XX

	*b. Set End_MY=Start_MY[_n+1]
by pidp Wave (Spell), sort: replace End_MY=Start_MY[_n+1] /*
  */ if _n<_N & MissingDates[_n+1]==0

	*c. Set End_MY=Start_MY+1
by pidp Wave (Spell), sort: gen XX=Start_MY+1 /*
  */ if _n==_N & End_Ind!=0 & Start_MY+1<=IntDate_MY
replace End_MY=XX if !missing(XX)
replace End_Flag=5 if !missing(XX)
drop XX	

by pidp Wave (Spell), sort: gen XX=Start_MY+1 /*
  */ if MissingDates[_n+1]==2 & Start_MY+1<=MinAbove_MY[_n+1]
replace End_MY=XX if !missing(XX)
replace End_Flag=5 if !missing(XX)
drop XX

by pidp Wave (Spell), sort: gen XX=Start_MY+1 /*
  */ if MissingDates[_n+1]==1 & Start_MY+1<=MinAbove_MY[_n+1]
  */ & Start_Y==Start_Y[_n+1] & month(dofm(Start_MY))<12
replace End_MY=XX if !missing(XX)
replace End_Flag=4 if !missing(XX)
drop XX

	*d.Set End_MY=Start_MY
by pidp Wave (Spell), sort: replace End_MY=Start_MY /*
  */ if _n==_N & Start_MY==IntDate_MY
by pidp Wave (Spell), sort: replace End_MY=Start_MY /*
  */ if MissingDates==0 & inlist(MissingDates[_n+1],1,2) /*     // SPECULATIVE
  */ & Start_MY==MinAbove_MY[_n+1]
by pidp Wave (Spell), sort: replace End_MY=Start_MY /*
  */ if MissingDates==1 & Start_MY==Start_MY[_n+1]

	*e. Set End_MY=ym(Start_Y[_n+1],1)
by pidp Wave (Spell), sort: gen XX=ym(Start_Y[_n+1],1) /*
  */ if MissingDates<2 & MissingDates[_n+1]==1 /*
  */ & Start_Y<Start_Y[_n+1]
replace End_MY=XX if !missing(XX)
replace End_Flag=4 if !missing(XX)
drop XX	

by pidp Wave (Spell), sort: gen XX=ym(Start_Y[_n+1],1) /*
  */ if MissingDates==1 & MissingDates[_n+1]==0 /*
  */ & Start_Y<Start_Y[_n+1]
replace End_MY=XX if !missing(XX)
replace End_Flag=4 if !missing(XX)
drop XX

	*f. Set End_MY=MinEnd_MY
drop if DropSpell==1
by pidp Wave (Spell), sort: replace Spell=_n

capture confirm variable MinEnd_MY
if _rc==0{
	by pidp Wave (Spell), sort: gen XX=MinEnd_MY /*
		*/ if !missing(MinEnd_MY)  & MinEnd_MY>End_MY & MinEnd_MY<=Start_MY[_n+1]
	replace End_MY=XX if !missing(XX)
	replace End_Flag=4 if !missing(XX)
	drop XX MinEnd_MY
	}
drop DropSpell MissingDates* MinAbove* MaxBelow*  /*
	*/ Start_Y Gap IntDate_Y


*6. Overlap Check
di in red "Overlap Check 1"
prog_checkoverlap


*7. Create spells in End_Type=.m equal to jbstat.
	*XX: ADD seam effects check while at it.
	*XX: NOT GOING TO WORK WITH BHPS.
prog_lastspellmissing
drop End_Type


*8. Replace start/end dates that are overlapping across Waves
	*Count number of pidps observed in multiple waves.
	*First drop if Status=.m because don't want this to change dates for spell where status is known.
	*Drop spells which are encompassed.
	*XX: THINK ABOUT WHERE STATUS IS MISSING - MIGHT BE BEST TO OVERWRITE/DELETE MISSING STATUS SPELLS. 
		* NOTE I DON'T HAVE ANY MISSING STATUS SPELLS HERE SO NOT A PROBLEM AS IT STANDS.
egen IDxWave_Tag=tag(pidp Wave)
by pidp (Wave Spell), sort: egen XX=min(Wave)
count if XX<Wave & IDxWave_Tag==1
di in red "`r(N)' pidps with life histories collected in more than 1 waves."
drop XX IDxWave_Tag				

drop if Status==.m		
by pidp (Wave Spell), sort: gen XX=_n
gen YY=.
qui sum XX
forval i=1/`r(max)'{
	by pidp (Wave Spell), sort: replace Start_Flag=1 if Start_MY<End_MY[_n-1] & _n>1
	by pidp (Wave Spell), sort: replace Start_MY=End_MY[_n-1] if Start_MY<End_MY[_n-1] & _n>1
	by pidp (Wave Spell), sort: replace YY=1 if /*
		*/ Start_MY==End_MY & Start_MY==Start_MY[_n+1] & Wave!=Wave[_n+1] & _n<_N
	drop if YY==1
	drop if Start_MY>End_MY
	if `r(N_drop)'==0{
		continue, break
		}
	}
drop XX YY
	
	
*9. Drop spells of no duration.
	* Previously, split into fractional months where multiple spells begin in same MY.
drop if Start_MY==End_MY
by pidp (Wave Spell), sort: replace Spell=_n	


*10. Make Checks 
di in red "Overlap Check 2"
prog_checkoverlap
count if missing(End_MY,Start_MY)
if `r(N)'>0{
	di in red "`r(N)' cases of missing dates. Should be zero"
	STOP
	}
compress
