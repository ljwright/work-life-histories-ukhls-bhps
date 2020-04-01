/*
********************************************************************************
UKHLS LIFE HISTORY.DO
	
	THIS FILE CREATES LIFETIME EMPLOYMENT STATUS HISTORIES USING THE EMPSTAT
	FILES FROM UNDERSTANDING SOCIETY.


********************************************************************************
*/

/*
1. Collect Life History Data for Non-FTE Leavers
*/
*i. Collate data from education section of annual history module.
/**/
qui{
	tempfile notleft_fte
	global notleft_fte `notleft_fte'
	foreach i of numlist $ukhls_lifehistwaves{
		local j: word `i' of `c(alpha)'
		use pidp `j'_lgaped /*
			*/ using "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}" /*
			*/ if `j'_lgaped==2, clear
		rename `j'_* *
		gen Wave=`i'+18
		order pidp Wave
		drop lgaped
		capture append using "`notleft_fte'"
		save "`notleft_fte'", replace
		}
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match) keepusing(IntDate_MY Birth_MY)
	gen Spell=1
	gen Start_MY=Birth_MY
	gen End_MY=IntDate_MY
	gen Status=7
	gen Source_Variable="lgaped_w"+strofreal(Wave)
	gen Job_Hours=.i
	gen Job_Change=.i
	gen Start_Flag=0
	gen End_Flag=1
	gen Status_Spells=1
	gen Source=substr(subinstr("`c(alpha)'"," ","",.),Wave-18,1)+"_indresp"
	drop Birth_MY
	save "`notleft_fte'", replace
	}
*/

/*
2. Collect Life History Data
*/
/**/
qui{
	capture rm "${dta_fld}/UKHLS Life History - Raw.dta"
	foreach i of numlist $ukhls_lifehistwaves{
		local j: word `i' of `c(alpha)'
		use pidp `j'_spellno `j'_leshst `j'_leshem `j'_leshsy4 /*
			*/ using "${fld}/${ukhls_path}_w`i'/`j'_empstat${file_type}", clear
		rename `j'_* *
		gen Wave=`i'+18
		capture append using "${dta_fld}/UKHLS Life History - Raw"
		save "${dta_fld}/UKHLS Life History - Raw", replace
		}
	}
*/
	
/*
3. Clean Life History Data
*/
/**/
qui{	
	*i. Open dataset, tag pidps and bring labels into dataset.
	prog_reopenfile "${dta_fld}/UKHLS Life History - Raw"
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogenerate keepusing(IntDate*Y Birth_*Y) keep(match)
	drop if missing(Birth_MY) | missing(IntDate_MY)	
	prog_recodemissing *
	prog_labels

	
	*ii. Make life history status consistent with other status variables.
	gen Status=.m
	replace Status=104 if leshst==0
	replace Status=1 if leshst==1
	replace Status=2 if inlist(leshst,2,3)
	replace Status=leshst-1 if inrange(leshst,4,10)
	replace Status=103 if leshst==11
	replace Status=97 if leshst==12
	label values Status status
	gen Job_Hours=cond(leshst==2,1,cond(leshst==3,2,cond(leshst==1,.m,.i)))
	gen Job_Change=cond(inlist(Status,1,2,100),4,.i)
	gen Source_Variable="lesht"+strofreal(spellno)+"_w"+strofreal(Wave)
	drop leshst
	
	
	*iii. Check all missing and current status reached values are placed at last spell.
	gen Spell=spellno
	drop spellno
	by pidp Wave (Spell), sort: gen XX=cond(_n==_N,1,0)
	noisily tab Status XX, missing
	count if Status==104 & XX==0
	if `r(N)'>0{
		di in red "'Current status reached' status not last status"
		STOP
		}
	count if Status==.m & XX==0
	if `r(N)'>0{
		di in red "Missing status not last status"
		STOP
		}
	drop XX
	
	
	*iv. Create end indicator variables	
		* These rely on last spell either being 'Current Status Reached' or 'Missing Spell'
	gen End_Ind=.m
	by pidp Wave (Spell), sort: replace End_Ind=0 if Status[_n+1]==104
	by pidp Wave (Spell), sort: replace End_Ind=1 if Status[_n+1]!=104 & !missing(Status[_n+1])
	drop if Status==104 | missing(Status)
	by pidp Wave (Spell), sort: egen XX=max(cond(End_Ind==.m,1,0))
	by pidp Wave (Spell), sort: egen YY=max(cond(End_Ind==0,1,0))
	count if XX==1 & YY==1
	if `r(N)'>0{
			di in red "Invalid: Two end indicator types"
			STOP
			}
	gen End_Type=cond(YY==1,0,.m)
	drop XX YY
	
	
	*v. Create date variables.
		*Treat those with missing years but not months as spurious and set month to missing in this case (/// Mare (2006, p.22) states other researcher do same)
		*Drop participants with missing interview dates.
	replace leshem=.m if leshsy4==.m
	count if leshem==.i | leshsy4==.i
	if `r(N)'>0{
		di in red "Invalid: `r(N)' cases where leshem or leshsy4==.i"
		STOP
		}
	gen Start_Y=leshsy4
	gen Start_M=leshem if inrange(leshem,1,12)
	replace Start_M=12 if leshem==13
	gen Start_S=1 if inlist(leshem,1,2,14)
	replace Start_S=2 if inlist(leshem,3,4,5,15)
	replace Start_S=3 if inlist(leshem,6,7,8,16)
	replace Start_S=4 if inlist(leshem,9,10,11,17)
	replace Start_S=5 if inlist(leshem,12,13)
	replace Start_M=6 if missing(Start_S) & !missing(Start_Y) & Spell==1
	replace Start_S=3 if missing(Start_S) & !missing(Start_Y) & Spell==1
	gen Start_MY=ym(Start_Y,Start_M)
	gen Start_SY=ym(Start_Y,Start_S)
	foreach var of varlist Start_*{
		replace `var'=.m if missing(`var')
		}
	gen Start_Flag=0
	drop leshem leshsy4 Start_S Start_M
	
	count if Start_MY>IntDate_MY & !missing(Start_MY, IntDate_MY)
	if `r(N)'>0{
		di in red "Invalid: `r(N)' cases where Start_MY>IntDate_MY"
		STOP
		}
	

	*vii. Run Common Life History Do File.
	gen Source=substr(subinstr("`c(alpha)'"," ","",.),Wave-18,1)+"_lifehist"
	qui do "${do_fld}/Clean Life History.do"	

	
	save "${dta_fld}/UKHLS Life History", replace
	rm "${dta_fld}/UKHLS Life History - Raw.dta"
	}	
*/	
