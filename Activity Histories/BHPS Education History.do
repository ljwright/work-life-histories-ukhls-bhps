/*
********************************************************************************
BHPS EDUCATION HISTORY.DO
	
	THIS FILE CREATES ANNUAL FULL-TIME EDUCATION HISTORIES USING THE INDRESP 
	FILES FROM THE WAVES 8-18 OF BHPS - SUFFICIENT INFORMATION IS NOT INCLUDED IN
	EARLIER WAVES

********************************************************************************
*/

/*
1. Collect Education History Data
	* Annual Education History collected in BHPS between ages 8-18
*/
/**/
qui{
	forval i=$first_bhps_eh_wave/$last_bhps_eh_wave{
		local j: word `i' of `c(alpha)'
		use pidp b`j'_ed* b`j'_ivfio using /*
			*/ "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}", clear
		rename b`j'_* *
		gen Wave=`i'
		keep if ivfio==1
		keep pidp edblyr* edbg* eden* edmore* edtype* Wave
		tempfile Temp`i'
		save "`Temp`i''"
		}
	forval i=`=$last_bhps_eh_wave-1'(-1)$first_bhps_eh_wave{
		append using "`Temp`i''"
		}
	save "${dta_fld}/BHPS Education History - Raw", replace
	}	
*/

/*
2. Clean Education History Data
*/
/**/
	*i. Open dataset
		*Reshape
prog_reopenfile "${dta_fld}/BHPS Education History - Raw" 
merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ nogenerate keep(match) keepusing(IntDate* Birth*Y)
prog_labels
prog_recodemissing *
drop if missing(IntDate_MY)
reshape long edblyr edbgm edbgy edenm edeny edenne edmore edtype, i(pidp Wave) j(Spell) 
drop if edblyr==. | edblyr==.i

*ii. Dates		
gen LB_Y=Wave+1989
gen LB_MY=ym(LB_Y,9)

gen Start_Flag=cond(edblyr==2,1,0)
gen Start_Y=cond(edblyr==1,edbgy,cond(edblyr==2,LB_Y,.m))
gen Start_MY=cond(edblyr==1,ym(edbgy,edbgm),cond(edblyr==2,LB_MY,.m))
gen End_Flag=cond(edenne==1,1,0)
gen End_Y=cond(edenne==1,IntDate_Y,edeny)
replace End_Y=.m if missing(End_Y)
gen End_MY=cond(edenne==1,IntDate_MY,ym(edeny,edenm))
replace End_MY=.m if missing(End_MY)
prog_missingdate Start End

gen End_Ind=cond(edenne==1,0,cond(edenne==.i,1,.m))
gen Source_Variable="edtype"+strofreal(Spell)+"_w"+strofreal(Wave)

*iii. Adjustments to missing or negative duration dates.
replace Start_Flag=4 if /*
	*/ Missing_StartDate==1 & inrange(Missing_EndDate,0,1) & Start_Y<End_Y
replace Start_MY=ym(Start_Y,12) if /*
	*/ Missing_StartDate==1 & inrange(Missing_EndDate,0,1) & Start_Y<End_Y
replace End_Flag=4 if /*
	*/ inrange(Missing_StartDate,0,1)  & Missing_EndDate==1 & Start_Y<End_Y
replace End_Y=ym(Start_Y,1) if /*
	*/ inrange(Missing_StartDate,0,1)  & Missing_EndDate==1 & Start_Y<End_Y
replace Start_Flag=5 if missing(Start_MY) & !missing(End_MY)
replace Start_MY=End_MY-1 if missing(Start_MY) & !missing(End_MY)
replace End_Flag=5 if !missing(Start_MY) & missing(End_MY)
replace End_MY=Start_MY+1 if !missing(Start_MY) & missing(End_MY)
drop if missing(Start_MY, End_MY)

drop if Start_MY>IntDate_MY	
replace End_MY=IntDate_MY if End_MY>IntDate_MY	
drop if End_MY<Start_MY | End_MY==Start_MY
drop Missing_*Date

foreach var in Start End{
	replace `var'_Y=year(dofm(`var'_MY))
	}

*iv. Check for unreasonable spells.
gen XX=floor((Start_MY-Birth_MY)/12)
di in red "Summary of ages at which FTE education spells started. All are reasonable dates."
noisily sum XX, d
drop if XX<0
drop XX

*v. Keep Latest Date in School
	* To Be Siphoned Off for Working Out Date Left FTE.
preserve
	gen EdType=1 if inrange(edtype,1,6)
	replace EdType=2 if inrange(edtype,7,11)
	replace EdType=.m if missing(edtype)
	format *MY %tm
	foreach i in S_3_IN S_3_FIN F_3_IN F_3_FIN{
		if "`i'"=="S_3_IN" local if "EdType==1 & edenne==1"
		else if "`i'"=="S_3_FIN" local if "EdType==1 & edenne!=1" 
		else if "`i'"=="F_3_IN" local if "EdType==2 & edenne==1" 
		else if "`i'"=="F_3_FIN" local if "EdType==2 & edenne!=1" 
		
		by pidp Wave (Spell), sort: gen XX=End_MY if `if'
		by pidp Wave (Spell), sort: egen `i'_MY=max(XX)
		by pidp Wave (Spell), sort: gen YY=_n if `i'_MY==XX
		by pidp Wave (Spell), sort: egen ZZ=max(YY)
		by pidp Wave (Spell), sort: gen `i'_edtype=edtype[ZZ]
		
		drop XX YY ZZ
		}
	local lbl: value label edtype
	label values *_edtype `lbl'
	keep pidp Wave *_3_*
	duplicates drop
	save "${dta_fld}/BHPS Education Dates", replace
restore

*vi. Overlaps and Clean
keep pidp Wave IntDate_MY Start_MY End_MY *Flag Source* End_Ind
prog_cleaneduhist
prog_format


save "${dta_fld}/BHPS Education History", replace
rm "${dta_fld}/BHPS Education History - Raw.dta"
*/
	
