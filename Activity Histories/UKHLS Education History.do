/*
********************************************************************************
UKHLS EDUCATION HISTORY.DO
	
	THIS FILE CREATES HISTORIES OF FULL-TIME EDUCATION USING THE ANNUAL HISTORY
	MODULE FROM UNDERSTANDING SOCIETY.


********************************************************************************
*/

/*
2. Dataset Preparation.
	* Annual Education History Modules asked from Wave 2 onwards.
*/
/**/
qui{
	forval i=2/$ukhls_waves{	
		local j: word `i' of `c(alpha)'
		use pidp `j'_contft `j'_ftend* `j'_fted* `j'_ft2* /*
			*/ using "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}", clear
		merge 1:1 pidp using "${fld}/${ukhls_path}_w`i'/`j'_indall${file_type}", /*
			*/ keepusing(`j'_ff_everint `j'_ff_ivlolw `j'_ivfio) /*
			*/ keep(match) nogenerate
		prog_recodemissing *
		compress
		rename `j'_* *
		gen Wave=`i'+18
		keep if ivfio==1 & (ff_ivlolw==1 | ff_everint==1)
		tempfile Temp`i'
		save "`Temp`i''", replace		
		}
	forval i=`=$ukhls_waves-1'(-1)2{
		append using "`Temp`i''"
		}
	save "${dta_fld}/UKHLS Education History - Raw", replace
	}
*/

/*
3. Format and clean annual education history dataset
	* GETS START AND END DATES FOR EACH SPELL.
*/
/**/
*i. Open dataset
prog_reopenfile "${dta_fld}/UKHLS Education History - Raw"		// PROG_REOPENFILE OPENS UP A DATASET IF IT ISN'T ALREADY IN MEMORY UNCHANGED.
prog_labels		// CREATES LABELS
order *, alphabetic
order pidp Wave ff_*

*ii. Index Spell
gen Has_Activity0=1 if contft!=.i

gen Source_Variable0="contft_w"+strofreal(Wave) if Has_Activity0==1

gen End_Ind0=.m if Has_Activity0==1
replace End_Ind0=0 if contft==1
replace End_Ind0=1 if contft==2

gen Start_M0=.i
gen Start_Y0=.i

gen End_M0=cond(End_Ind0==1,ftendm,.i)
gen End_Y0=cond(End_Ind0==1,ftendy4,.i)

*iii. Spells 1+*
ds ftedmor*
local spells: word count `r(varlist)'
forval i=1/`spells'{
	if `i'==1{
		gen Has_Activity`i'=1 if ftedany==1
		gen Source_Variable`i'="ftedany_w"+strofreal(Wave) if Has_Activity`i'==1
		}
	else if `i'>1{
		local j=`i'-1
		gen Has_Activity`i'=1 if ftedmor`j'==1		
		gen Source_Variable`i'="ftedmor`j'_w"+strofreal(Wave) if Has_Activity`i'==1
		}
	
	gen End_Ind`i'=.m if Has_Activity`i'==1
	replace End_Ind`i'=0 if ftedend`i'==2
	replace End_Ind`i'=1 if ftedend`i'==1
	
	gen Start_M`i'=ftedstartm`i'
	gen Start_Y`i'=ftedstarty4`i'
	
	gen End_M`i'=cond(End_Ind`i'==1,ft2endm`i',.i)
	gen End_Y`i'=cond(End_Ind`i'==1,ft2endy4`i',.i)
	}	
	
*iv. Reshape into long format
keep pidp Wave Start* End* Has* Source*
egen XX=rownonmiss(Has_Activity*)
drop if XX==0
drop XX

reshape long Has_Activity Source_Variable End_Ind /*
	*/ Start_M Start_Y End_M End_Y, /*
	*/ i(pidp Wave) j(Spell)
keep if Has_Activity==1
drop Has_Activity

*v. Merge with Interview Grid and delete observations with missing interview dates
merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ keepusing(LB_MY IntDate_MY jbstat) keep(match) nogenerate
drop if missing(IntDate_MY, LB_MY)

*vi. Replace missing end indicator
	/// Assumes no stops in FTE where end indicator is missing and participant gives FTE as current jbstat
replace End_Ind=0 if jbstat==7 & End_Ind==.m
drop jbstat

*vii .Generate month-year variables
	* Continuing activities are given interview date as end date
	* Index spells are given start date at time of previous interview.
	* Missing end or start years are set equal start or end year where these are the same as the interview or previous interview year
	* Start or end dates outside interview date range set to be coterminuous with these, except:
			* Observations dropped where this leads to negative duration spells.
			* Observations dropped where corresponding end and start dates are missing (without this wouldn't know if the event occured completely before or after period between interviews).
		* Start and end dates set equal where one but not the other is equal
		/// Only using data from events taking place between interviews:
			/// 1. To ensure observations from closest point in time to the event are used.
			/// 2. To stop overlap between observations.
foreach i in Start End{
	gen `i'_MY=ym(`i'_Y,`i'_M)
	replace `i'_MY=.m if missing(`i'_MY)
	}
prog_missingdate Start End
gen Start_Flag=0 if Missing_StartDate==0
gen End_Flag=0 if Missing_EndDate==0
label values Start_Flag End_Flag flag	

replace Start_MY=LB_MY if Spell==0	
replace End_MY=IntDate_MY if End_Ind==0
replace Start_Flag=1 if Spell==0
replace End_Flag=1 if End_Ind==0
prog_missingdate Start End
drop LB_MY

replace Start_Flag=3 if Start_Y<End_Y & Missing_StartDate==1
replace Start_Flag=0 if Start_Y==End_Y & Missing_StartDate==1 & month(dofm(End_MY))==1
replace Start_MY=ym(Start_Y,12) if Start_Y<End_Y & Missing_StartDate==1
replace Start_MY=ym(Start_Y,1) if Start_Y==End_Y & Missing_StartDate==1 & month(dofm(End_MY))==1
replace End_Flag=3 if Start_Y<End_Y & Missing_EndDate==1
replace End_Flag=0 if Start_Y==End_Y & Missing_EndDate==1 & month(dofm(Start_MY))==12
replace End_MY=ym(End_Y,1) if Start_Y<End_Y & Missing_EndDate==1
replace End_MY=ym(End_MY,12) if Start_Y==End_Y & Missing_EndDate==1 & month(dofm(Start_MY))==12
prog_missingdate Start End	

replace Start_Flag=4 if Missing_StartDate!=0 & Missing_EndDate==0
replace Start_MY=End_MY-1 if Missing_StartDate!=0 & Missing_EndDate==0
replace End_Flag=4 if Missing_StartDate==0 & Missing_EndDate!=0
replace End_MY=Start_MY+1 if Missing_StartDate==0 & Missing_EndDate!=0
prog_missingdate Start End	

replace End_Flag=1 if End_MY>IntDate_MY & Missing_EndDate!=0
replace End_MY=IntDate_MY if End_MY>IntDate_MY & Missing_EndDate!=0

drop if Missing_StartDate!=0 | Missing_EndDate!=0	
drop if Start_MY>End_MY
drop if Start_MY==End_MY
drop *_M *_Y Missing_*Date

*viii. Combine overlapping spells and save dataset.
	* If end date is after start date of next spell but before its end date, replaces end date with end date[_n+1] 
	* If end date is after start date of next spell and after its end date, next spell dropped as it is subsumed entirely.
prog_cleaneduhist
prog_format

save "${dta_fld}/UKHLS Education History", replace
rm "${dta_fld}/UKHLS Education History - Raw.dta"
*/
