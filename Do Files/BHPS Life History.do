/*
********************************************************************************
BHPS LIFE HISTORY.DO
	
	THIS FILE CREATES LIFETIME EMPLOYMENT STATUS HISTORIES USING THE LIFEMST 
	FILES FROM WAVES 2, 11, AND 12 OF THE BHPS (WAVES B, K AND L)

********************************************************************************
*/

/*
1. Create Life Histories for FTE never leavers
*/
/**/
qui{
	tempfile notleft_fte
	global notleft_fte `notleft_fte'
	foreach i of numlist $bhps_lifehistwaves{
		local j: word `i' of `c(alpha)'
		use pidp b`j'_lednow /*
			*/ using "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}" /*
			*/ if b`j'_lednow==0, clear
		gen Wave=`i'
		order pidp Wave
		keep pidp Wave
		capture append using "`notleft_fte'"
		save "`notleft_fte'", replace
		}
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match) keepusing(IntDate_MY Birth_MY)
	gen Spell=1
	gen Start_MY=Birth_MY
	gen End_MY=IntDate_MY
	gen Status=7
	gen Source_Variable="lednow_w"+strofreal(Wave)
	gen Job_Hours=.i
	gen Job_Change=.i
	gen Start_Flag=0
	gen End_Flag=1
	gen Status_Spells=1
	gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_indresp"
	drop Birth_MY
	save "`notleft_fte'", replace
	}
*/	


/*
2. Collect Lifemst Data
	* bb_lifemst_bh
	* bk_lifemst_bh 
	* bl_lifemst_bh
*/
/**/
qui{
	capture rm "${dta_fld}/BHPS Life History - Raw.dta"
	foreach i of numlist $bhps_lifehistwaves{
		local j: word `i' of `c(alpha)'
		use "${fld}/${bhps_path}_w`i'/b`j'_lifemst${file_type}", clear
		merge m:1 pidp using "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}", /*
			*/ keep(match) nogenerate keepusing(b`j'_led*) 
		rename b`j'_* *
		capture rename *_bh *
		keep pidp *lesh* *led*
		capture drop leshey ledendy leshsy
		gen Wave=`i'
		rename leshno Spell
		order pidp Wave Spell
		capture append using "${dta_fld}/BHPS Life History - Raw"
		save "${dta_fld}/BHPS Life History - Raw", replace
		}
	}
*/
	
/*
3. Clean Lifemst Data
*/
/**/
qui{
	*i. Open raw dataset
	prog_reopenfile "${dta_fld}/BHPS Life History - Raw"
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match master) keepusing(IntDate_*Y Birth_*Y)
	drop if missing(Birth_MY) | missing(IntDate_MY)	 
	prog_labels
	prog_recodemissing *
	foreach var of varlist leshsy4 leshey4 ledeny4{
		replace `var'=.m if `var'>2018 & !missing(`var')
		}
	
	*ii. See whether start and end cells in adjacent spells are consistent
		/// Only 4 inconsistencies, and the inconsistencies are small, so ignore.
	by pidp Wave (Spell), sort: gen XX=leshsm[_n+1]
	by pidp Wave (Spell), sort: gen YY=leshsy4[_n+1]
	gen ZZ=(XX!=leshem | YY!=leshey4) & !missing(XX,YY)
	count if ZZ==1
	di in red "`r(N)' cases where start and ends do not match up in adjacent spells. Ignore as so few."
	count if Spell==1 & (leshsy4!=ledeny4 | leshsm!=ledendm)
	di in red "`r(N)' cases where end FTE and start first spell are inconsistent."
	drop leshe*	XX YY ZZ	
	
	*iii. Clean Status data
	gen Status=.m
	replace Status=1 if leshst==1
	replace Status=2 if inrange(leshst,2,3)
	replace Status=leshst-1 if inrange(leshst,4,10)
	replace Status=103 if leshst==11
	replace Status=97 if leshst==12
	label values Status status
	gen Job_Hours=cond(inrange(leshst,2,3),leshst-1,cond(leshst==1,.m,.i))
	gen Job_Change=cond(inlist(Status,1,2,100),4,.i)
	gen Source_Variable="lesht"+strofreal(Spell)+"_w"+strofreal(Wave)
	drop leshst
	
	*iv. Check if sequences end with current activities
		* DROP THOSE WITH STATUS==.M WHERE NOT FINAL SPELL (ONLY FIVE PEOPLE)
	by pidp Wave (Spell), sort: gen XX=cond(_n==_N,1,0)
	gen End_Ind=.m
	replace End_Ind=0 if leshne==1
	replace End_Ind=1 if leshne==.i | (leshne==.m & XX==0)
	by pidp Wave (Spell), sort: gen End_Type=End_Ind[_N]
	drop if Status==.m & XX==1
	by pidp Wave: egen YY=max(Status==.m)
	drop if YY==1
	drop leshne XX YY
	
	*v. Create start dates.
		// Winter is not split into two for bb_lifemst. Next section deals with this.
	replace leshsm=.m if leshsy4==.m
	gen Winter=cond(Wave==2 & leshsm==13,1,0)
	gen Start_Y=leshsy4
	gen Start_M=cond(leshsm>=1 & leshsm<=12,leshsm,.m)
	gen Start_S=.m
	replace Start_S=1 if inlist(leshsm,1,2) | (leshsm==13 & Wave!=2)
	replace Start_S=2 if inlist(leshsm,3,4,5,14)
	replace Start_S=3 if inlist(leshsm,6,7,8,15)
	replace Start_S=4 if inlist(leshsm,9,10,11,16)
	replace Start_S=5 if inlist(leshsm,12,17)
	gen Start_MY=ym(Start_Y,Start_M)
	gen Start_SY=ym(Start_Y,Start_S)
	gen Start_Flag=0
	drop leshsm leshsy4 Start_M *_S led*
	
	*vi. Impute correct season where Wave==2 & Season is Winter.
	prog_assignwinter


	*ix. Run Common Life History Do File.
	gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_lifehist"
	qui do "${do_fld}/Clean Life History.do"	

	
	save "${dta_fld}/BHPS Life History", replace
	rm "${dta_fld}/BHPS Life History - Raw.dta"
	}
