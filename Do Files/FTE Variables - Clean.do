/*
********************************************************************************
FTE VARIABLES - CLEAN.DO
	
	THIS FILE COMBINES RESPONSES TO DIFFERENT EDUCATION QUESTION TO DERIVE A DATE
	IN WHICH PARTICIPANT LEFT FULL TIME EDUCATION FOR FIRST DATE OR LATEST AGE AT WHICH
	PARTICIPANT HAD NOT LEFT FULL-TIME EDUCATION. 

********************************************************************************
*/

/*
1. Replace dates to missing if likely to have left education prior to date
*/
/**/
prog_reopenfile "${dta_fld}/Education Variables - Formatted"

quietly prog_makeage *MY
foreach var of varlist LH_*IN_MY S_*IN_MY F_*IN_MY{
	if substr("`var'",1,1)=="S" replace	`var'=. if `var'_Age>19		// IN SCHOOL AFTER AGE 19
	if substr("`var'",1,1)=="F" replace `var'=. if `var'_Age>23		// IN FURTHER/HIGHER EDUCATION AFTER AGE 23
	if substr("`var'",1,1)=="L" replace `var'=. if `var'_Age>26		// LIFE HISTORY AFTER AGE 26 (LATER AS ASKS QUESTION OF END DATE DIRECTLY)
	local j=subinstr("`var'","_MY","",.)
	prog_scrubvars `j'
	}
drop *_Age

//	NOW DECIDED TO NOT USE PROXY FOR ANY EVENT IN PARTICIPANTS PAST AS DISCREPANCY BETWEEN INDIVIDUAL AND PROXY RESPONSES
foreach i of varlist *FIN_MY *NO_MY{
	local j=subinstr("`i'","_MY","_Source",.)
	capture replace `i'=. if strpos(`j',"Proxy")>0
	local k=subinstr("`i'","_MY","",.)
	prog_scrubvars `k'		// THIS PROGRAM OVERWRITE INFORMATION IN SOURCE, QUAL AND WAVE
	}	

/*
2. Choose values for further education, school and life history from different waves and collection methods
*/
// USE ONE VALUE FROM EACH COLLECTION METHOD
foreach i in S F{
	foreach j of numlist 1 2 5 6{
		di "`i'_`j':"
		prog_chooseob `i'_`j'		// THIS PROGRAM SELECTS ONE OBSERVATION WHERE PARTICULAR VARIABLE IS ELICITED IN MULTIPLE WAVES.
		}
	}
prog_chooseob LH

keep pidp Birth_MY *_1_* *_2_* *_5_* *_6_* LH*
by pidp, sort: keep if _n==1

// USE ONE VALUE FROM THE DIFFERENT COLLECTION METHODS
local vlist ""
local stublist ""
foreach i in S F{
		foreach j in IN FIN NO{
			foreach k in MY Source Qual Wave{
				rename `i'_?_`j'_`k'  `i'_`j'_`k'?
				ds `i'_`j'_`k'?
				local vlist "`vlist' `r(varlist)'"
				local stublist "`stublist' `i'_`j'_`k'"
				}
			}
		}
keep pidp Birth_MY `vlist' LH_*
reshape long `stublist', i(pidp Birth_MY) j(Route)
egen tag=tag(pidp)
prog_chooseob S
prog_chooseob F
drop Route tag
duplicates drop

/* KEEPING ONE OBSERVATION FOR EACH OF LH, S & F */
//	PREFER FULL INTERVIEW RESPONSES TO PROXY
foreach i in LH S F{
	count if !missing(`i'_IN_MY,`i'_FIN_MY)
	count if !missing(`i'_IN_MY,`i'_NO_MY)
	count if !missing(`i'_FIN_MY,`i'_NO_MY)
	}

qui{
replace LH_IN_MY=. if !missing(LH_FIN_MY)
replace LH_NO_MY=. if !missing(LH_FIN_MY)
replace LH_NO_MY=. if !missing(LH_IN_MY)
prog_scrubvars LH_

foreach i in S F{
	foreach j in FIN IN NO{
		foreach k in FIN IN NO{
			if "`j'"!="`k'"{
				gen XX=(strpos(`i'_`j'_Source,"Proxy")>0 & /*
					*/ strpos(`i'_`k'_Source,"Proxy")==0 /*
					*/ & !missing(`i'_`j'_Source,`i'_`k'_Source))
				gen YY=1 if XX==1 & "`j'"=="NO" /*
					*/ & `i'_`j'_MY>=`i'_`k'_MY /*
					*/ & !missing(`i'_`j'_MY,`i'_`k'_MY)
				replace YY=1 if XX==1 & "`k'"=="NO" /*
					*/ & `i'_`j'_MY<=`i'_`k'_MY /*
					*/ & !missing(`i'_`j'_MY,`i'_`k'_MY)					
				replace `i'_`j'_MY=. if YY==1
				drop XX YY
				}
			}
		}
	}
	}

quietly prog_makeage S_IN_MY S_FIN_MY S_NO_MY
table S_FIN_MY_Age S_IN_MY_Age
replace S_FIN_MY=. if inrange(S_IN_MY-S_FIN_MY,0,14)
replace S_IN_MY=. if S_IN_MY-S_FIN_MY<0
replace S_IN_MY=. if S_IN_MY-S_FIN_MY>14 & !missing(S_IN_MY,S_FIN_MY)
table S_NO_MY_Age S_IN_MY_Age
replace S_IN_MY=. if S_NO_MY<S_IN_MY & S_IN_MY_Age>19
replace S_IN_MY=. if !missing(S_NO_MY) & S_IN_MY_Age>19
replace S_NO_MY=. if S_IN_MY_Age<=19
table S_NO_MY_Age S_FIN_MY_Age
replace S_FIN_MY=. if S_FIN_MY_Age<12 & !missing(S_NO_MY_Age) 
replace S_NO_MY=. if S_FIN_MY_Age<=23
drop *Age

quietly prog_makeage F_IN_MY F_FIN_MY F_NO_MY
table F_IN_MY_Age F_FIN_MY_Age
replace F_FIN_MY=. if inrange(F_IN_MY-F_FIN_MY,0,14)
replace F_IN_MY=. if F_IN_MY-F_FIN_MY<0 & F_FIN_MY_Age<=23
replace F_FIN_MY=. if F_IN_MY-F_FIN_MY<0 & F_FIN_MY_Age>23
replace F_IN_MY=. if F_IN_MY-F_FIN_MY>14 & !missing(F_IN_MY,F_FIN_MY)
table F_IN_MY_Age F_NO_MY_Age 
replace F_IN_MY=. if F_NO_MY_Age>23 & !missing(F_NO_MY)
replace F_NO_MY=. if F_IN_MY_Age<=19 & !missing(F_NO_MY)
replace F_NO_MY=. if (F_IN_MY-S_IN_MY<=12 | F_FIN_MY-S_IN_MY<=12) /*
	*/ & !missing(F_NO_MY)
replace F_IN_MY=. if !missing(F_NO_MY) & !missing(F_IN_MY)
table F_NO_MY_Age F_FIN_MY_Age
replace F_FIN_MY=. if F_FIN_MY_Age<=23 & F_NO_MY<F_FIN_MY
replace F_NO_MY=. if F_FIN_MY_Age<=23 & !missing(F_FIN_MY)
replace F_FIN_MY=. if F_NO_MY_Age<F_FIN_MY_Age & F_NO_MY_Age>=19
replace F_NO_MY=. if !missing(F_FIN_MY) & !missing(F_NO_MY)
drop *Age

prog_scrubvars S_
prog_scrubvars F_

// CHECK THAT ONE VALUES FROM IN, FIN AND NO HAS BEEN SELECTED.
local j=0
foreach i in LH S F{
	count if !missing(`i'_IN_MY,`i'_FIN_MY)
	local j=max(`j',`r(N)')
	count if !missing(`i'_IN_MY,`i'_NO_MY)
	local j=max(`j',`r(N)')
	count if !missing(`i'_FIN_MY,`i'_NO_MY)
	local j=max(`j',`r(N)')
	}
if `j'>0{
	di in red "All should be equal to zero."
	STOP
	}	

/*
3. Create FTE Dates from School, FE and Life History observations.
	* Several decision rules, but basically, assume no gap in education where FE before age 24. Otherwise, use school if finished before age 19.
*/
//	CREATE EMPTY VARIABLES FOR FINAL VALUES
foreach j in IN FIN NO{
	gen FTE_`j'_MY=.
	gen FTE_`j'_Source=""
	}
format %tm *MY	
// foreach i in IN FIN NO{
// 	replace FTE_`i'_MY=LH_`i'_MY
// 	replace FTE_`i'_Source="LH_`i'" if !missing(LH_`i'_MY)
// 	}
drop *Qual
compress
prog_countsf

/* DERIVE FTE FROM S & F & LH */
// 	S_IN & F_IN (89)
prog_makecombos S_IN_MY F_IN_MY
gen YY=max(S_IN_MY,F_IN_MY)
replace FTE_IN_Source="Greater of S_IN and F_IN" /*
	*/ if XX==1 & F_IN_MY_Age<=23 & S_IN_MY_Age<=19
replace FTE_IN_MY=YY /*
	*/ if XX==1 & F_IN_MY_Age<=23 & S_IN_MY_Age<=19
replace FTE_IN_MY=S_IN_MY /*
	*/ if XX==1 & F_IN_MY_Age>23 & S_IN_MY_Age<=19
drop XX YY *Age
prog_countsf

// 	S_IN & F_FIN (34)
prog_makecombos S_IN_MY F_FIN_MY
count if XX==1 & $i<=$j
replace FTE_FIN_Source="F_FIN" if XX==1 & $i<=$j /*
	 */ & ${j}_Age<=23
replace FTE_FIN_MY=F_FIN_MY if XX==1 & $i<=$j /*
	 */ & ${j}_Age<=23
count if XX==1 & $i>$j
tab ${i}_Age ${j}_Age if XX==1 & $i>$j
replace FTE_IN_Source="S_IN" if XX==1 & $i>$j
replace FTE_IN_MY=S_IN_MY if XX==1 & $i>$j
drop XX *Age
prog_countsf

// 	S_IN & F_NO (83)
prog_makecombos S_IN_MY F_NO_MY
count if XX==1 & $i<=$j
replace FTE_IN_Source="S_IN" if XX==1 & S_IN_MY_Age<=19
replace FTE_IN_MY=S_IN_MY if XX==1 & S_IN_MY_Age<=19
drop XX *Age
prog_countsf

// S_FIN & F_IN (6,782)
	// IDEALLY SHOULD BE ONLY USING PLAUSIBLE F_IN DATA.
prog_makecombos S_FIN_MY F_IN_MY
count if XX==1 & $i<=$j
replace FTE_IN_Source="F_IN" if XX==1 & $i<=$j /*
	*/ & ${i}_Age<=19 & ${j}_Age<=23
replace FTE_IN_MY=F_IN_MY if XX==1 & $i<=$j /*
	*/ & ${i}_Age<=19 & ${j}_Age<=23
replace FTE_IN_Source="S_FIN" if XX==1 & $i<=$j /*
	*/ & ${i}_Age<=19 & ${j}_Age>23
replace FTE_IN_MY=S_FIN_MY if XX==1 & $i<=$j /*
	*/ & ${i}_Age<=19 & ${j}_Age>23
replace FTE_IN_Source="S_FIN" if XX==1 & $i>$j /*
	*/ & ${i}_Age<=19 & ${j}_Age<=23
replace FTE_IN_MY=S_FIN_MY if XX==1 & $i>$j /*
	*/ & ${i}_Age<=19 & ${j}_Age<=23
drop XX *Age
prog_countsf

// S_FIN & F_FIN (19,588)
prog_makecombos S_FIN_MY F_FIN_MY
count if XX==1 & $i<=$j
replace FTE_FIN_Source="F_FIN" if XX==1 & $i<=$j /*
	*/ & ${i}_Age<=19 & ${j}_Age<=23
replace FTE_FIN_MY=F_FIN_MY if XX==1 & $i<=$j /*
	*/ & ${i}_Age<=19 & ${j}_Age<=23
replace FTE_IN_Source="S_FIN" if XX==1 & $i<=$j /*
	*/ & ${i}_Age<=19 & ${j}_Age>23
replace FTE_IN_MY=S_FIN_MY if XX==1 & $i<=$j /*
	*/ & ${i}_Age<=19 & ${j}_Age>23
replace FTE_IN_Source="S_FIN" if XX==1 & $i>$j /*
	*/ & ${i}_Age<=19 & ${j}_Age<=23
replace FTE_IN_MY=S_FIN_MY if XX==1 & $i>$j /*
	*/ & ${i}_Age<=19 & ${j}_Age<=23
drop XX *Age
prog_countsf

// 	S_FIN & F_NO (19,556)
prog_makecombos S_FIN_MY F_NO_MY
count if XX==1 & $i<=$j
replace FTE_FIN_Source="S_FIN and F_NO" if XX==1 & $i<=$j
replace FTE_FIN_MY=S_FIN_MY if XX==1 & $i<=$j
count if XX==1 & $i>$j
*	DIFFICULT TO DEAL WITH AS F_NO AS STILL IN SCHOOL WHERE $i>$j
	*	SOLUTION: REPLACE FTE_IN INSTEAD, BUT MAKE NOTE IN SOURCE.
replace FTE_IN_Source="S_FIN and F_NO" if XX==1 & $i>$j
replace FTE_IN_MY=S_FIN_MY if XX==1 & $i>$j
drop XX *Age
prog_countsf

// S_NO & F_IN (9)
prog_makecombos S_NO_MY F_IN_MY
replace FTE_IN_Source="F_IN" if XX==1 & F_IN_MY_Age<=23
replace FTE_IN_MY=F_IN_MY if XX==1 & F_IN_MY_Age<=23
drop XX *Age
prog_countsf

// S_NO & F_FIN (6)
prog_makecombos S_NO_MY F_FIN_MY
replace FTE_FIN_Source="F_FIN" if XX==1 & F_FIN_MY_Age<=23
replace FTE_FIN_MY=F_FIN_MY if XX==1 & F_FIN_MY_Age<=23
drop XX *Age
prog_countsf

// S_NO & F_NO (104)
prog_makecombos S_NO_MY F_NO_MY
gen YY=max(S_NO_MY,F_NO_MY)
replace FTE_NO_Source="Greater of S_NO & F_NO" if XX==1
replace FTE_NO_MY=YY if XX==1
drop XX YY *Age
prog_countsf


/* DERIVE FTE FROM S OR F */
// S_IN_MY WITH NO F (6,374)
prog_ageremain S_IN_MY
replace FTE_IN_Source="S_IN" if XX==1 & S_IN_MY_Age<=19
replace FTE_IN_MY=S_IN_MY if XX==1 &  S_IN_MY_Age<=19
drop XX *Age // 116 LEFT
prog_countsf

// F_IN_MY WITH NO S (49)
prog_ageremain F_IN_MY
replace FTE_IN_Source="F_IN" if XX==1 & F_IN_MY_Age<=23
replace FTE_IN_MY=F_IN_MY if XX==1 & F_IN_MY_Age<=23
drop XX *Age // 14 LEFT
prog_countsf

// S_FIN_MY WITH NO F (460)
prog_ageremain S_FIN_MY
replace FTE_IN_Source="S_FIN" if XX==1 & S_FIN_MY_Age<=19
replace FTE_IN_MY=S_FIN_MY if XX==1 & S_FIN_MY_Age<=19
drop XX *Age // 8 LEFT
prog_countsf

// F_FIN_MY WITH NO S (160)
prog_ageremain F_FIN_MY
replace FTE_FIN_Source="F_FIN" if XX==1 & F_FIN_MY_Age<=23
replace FTE_FIN_MY=F_FIN_MY if XX==1 & F_FIN_MY_Age<=23
drop XX *Age // 23 LEFT
prog_countsf

// S_NO_MY WITH NO F (509)
prog_ageremain S_NO_MY
replace FTE_NO_Source="S_NO" if XX==1 & S_NO_MY_Age>19 & !missing(S_NO_MY) // JUSTIFICATION: 80 OUT OF 89 WITH S_NO AND F NOT MISSING HAVE F_NO TOO.
replace FTE_NO_MY=S_NO_MY if XX==1 & S_NO_MY_Age>19 & !missing(S_NO_MY)
drop XX *Age // 11 LEFT 
prog_countsf

// F_NO_MY WITH NO S (242)
prog_ageremain F_NO_MY
	// CAN'T DO ANYTHING WITH THIS: COULD HAVE SCHOOL, JUST DON'T KNOW.
prog_countsf // 1,678 OF 105,262

//	LH & FTE
foreach i in IN FIN NO{
	foreach j in IN FIN NO{
		qui count if !missing(LH_`i'_MY) & !missing(FTE_`j'_MY)
		di in red "LH_`i' & FTE_`j': `r(N)'"
		}
	}

//	LH_IN & FTE_IN
prog_lhcombos IN IN
replace FTE_IN_MY=max(LH_IN_MY, FTE_IN_MY) /*
	*/ if XX==1
replace FTE_IN_Source="LH_IN" /*
	*/ if XX==1 & LH_IN_MY==FTE_IN_MY

//	LH_IN & FTE_FIN
prog_lhcombos IN FIN
replace FTE_IN_MY=LH_IN_MY  /*
	*/ if XX==1 & LH_IN_MY>FTE_FIN_MY
replace FTE_IN_Source="LH_IN"  /*
	*/ if XX==1 & LH_IN_MY>FTE_FIN_MY
replace FTE_FIN_MY=.  /*
	*/ if XX==1 & LH_IN_MY>FTE_FIN_MY	
prog_scrubvars FTE_FIN

//	LH_IN & FTE_NO	
prog_lhcombos IN NO	
replace FTE_IN_MY=LH_IN_MY  /*
	*/ if XX==1
replace FTE_IN_Source="LH_IN"  /*
	*/ if XX==1
replace FTE_NO_MY=.  /*
	*/ if XX==1
prog_scrubvars FTE_FIN	
	
//	LH_FIN & FTE_IN
prog_lhcombos FIN IN
replace FTE_FIN_MY=LH_FIN_MY /*
	*/ if XX==1 & !inrange(LH_FIN_MY-FTE_IN_MY,-12,0) & LH_FIN_MY_Age>=14
replace FTE_FIN_Source="LH_FIN" /*
	*/ if XX==1 & !inrange(LH_FIN_MY-FTE_IN_MY,-12,0) & LH_FIN_MY_Age>=14
replace FTE_IN_MY=./*
	*/ if XX==1 & !inrange(LH_FIN_MY-FTE_IN_MY,-12,0) & LH_FIN_MY_Age>=14
prog_scrubvars FTE_IN

// LH_FIN & FTE_FIN
prog_lhcombos FIN FIN
replace FTE_FIN_MY=LH_FIN_MY /*
	*/ if XX==1 & (LH_FIN_MY_Age>=16 | (LH_FIN_MY>FTE_FIN_MY & LH_FIN_MY_Age<16))
replace FTE_FIN_Source="LH_FIN" /*
	*/ if XX==1 & (LH_FIN_MY_Age>=16 | (LH_FIN_MY>FTE_FIN_MY & LH_FIN_MY_Age<16))

// LH_FIN & FTE_NO
prog_lhcombos FIN NO
replace FTE_FIN_MY=LH_FIN_MY /*
	*/ if XX==1 & (LH_FIN_MY<FTE_NO_MY) & LH_FIN_MY_Age>=11
replace FTE_FIN_Source="LH_FIN" /*
	*/ if XX==1 & (LH_FIN_MY<FTE_NO_MY) & LH_FIN_MY_Age>=11
replace FTE_NO_MY=. /*
	*/ if XX==1 & (LH_FIN_MY<FTE_NO_MY) & LH_FIN_MY_Age>=11
prog_scrubvars FTE_NO

// LH_NO...
// prog_lhcombos NO IN	// NO OBSERVATIONS
prog_lhcombos NO FIN	// FTE_FIN SENSIBLE
prog_lhcombos NO NO
replace FTE_NO_MY=max(LH_NO_MY, FTE_NO_MY) /*
	*/ if XX==1
replace FTE_NO_Source="LH_NO" /*
	*/ if XX==1 & LH_IN_MY==FTE_IN_MY

tab1 FTE*Source

drop *Age
keep pidp Birth_MY FTE* LH* S_* F_*
save "${dta_fld}/Education Variables - Cleaned", replace

keep pidp Birth_MY FTE*
count if $FTE_Missing
count if !missing(FTE_IN_MY,FTE_FIN_MY)
count if !missing(FTE_IN_MY,FTE_NO_MY)
count if !missing(FTE_FIN_MY,FTE_NO_MY)
gen FTE_Source="Missing"
foreach var of varlist FTE_*_MY{
	replace FTE_Source="`var'" if !missing(`var')
	}

save "${dta_fld}/Left Full Time Education", replace
rm "${dta_fld}/Education Variables - Formatted.dta"
rm "${dta_fld}/Education Variables.dta"
