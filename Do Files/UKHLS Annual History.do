/*
********************************************************************************
UKHLS ANNUAL HISTORY COLLECT.DO
	
	THIS FILE CREATES A DATASET OF JOB HISTORY AND INTERVIEW DATE VARIABLES FROM
	CURRENT AND PRECEEDING FULL OR TELPHONE INTERVIEWS.

	
********************************************************************************
*/

/*
1. Dataset Preparation.
	A. Collate raw data and create routing flags.
*/

*i. Bring together UKHLS annual employment history variables and variables upon which routing depends from indresp and  indall files (Wave 2 onwards)
	* Replace missing values with .m or .i.
qui{
	forval i=2/$ukhls_waves{
		local j: word `i' of `c(alpha)'
		use pidp `j'_notempchk-`j'_jbhas `j'_jbft_dv `j'_ff_jbstat /*
			*/ `j'_jbstat `j'_jbsemp /*
			*/ using "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}", clear
		merge 1:1 pidp using "${fld}/${ukhls_path}_w`i'/`j'_indall${file_type}", /*
			*/ keepusing(`j'_ff_everint `j'_ff_ivlolw `j'_ivfio) /*
			*/ keep(match) nogenerate
		prog_recodemissing *
		compress
		rename `j'_* *
		gen Wave=`i'+18
		tempfile Temp`i'
		save "`Temp`i''", replace		
		}
	forval i=`=$ukhls_waves-1'(-1)2{
		append using "`Temp`i''"
		}
	save "${dta_fld}/UKHLS Annual History - Raw", replace
	}
	
*ii. Drop participants who do not have annual employment histories in a given wave.
	* Create flags for how individuals are routed through annual history modules.
qui{
	prog_reopenfile "${dta_fld}/UKHLS Annual History - Raw.dta"
	qui prog_labels
	keep if ivfio==1 & (ff_ivlolw==1 | ff_everint==1)
	drop if notempchk==.i & empchk==.i
	
	foreach var of varlist nextstat* nextelse* currstat* nextjob* currjob* /*
		*/jobhours* statend* jbatt*{
		capture replace `var'=.i if `var'==.
		}

	gen AnnualHistory_Routing=cond(notempchk!=.i,cond(empchk==.i,1,3),2)
	label values AnnualHistory_Routing annualhistory_routing
	
	gen Route3_Type=.i
	replace Route3_Type=1 if notempchk==.m & empchk==.m
	replace Route3_Type=2 if notempchk==.m & empchk==1
	replace Route3_Type=3 if notempchk==.m & empchk==2
	replace Route3_Type=4 if notempchk==1 & empchk==.m
	replace Route3_Type=5 if notempchk==1 & empchk==1
	replace Route3_Type=6 if notempchk==1 & empchk==2
	replace Route3_Type=7 if notempchk==2 & empchk==.m
	replace Route3_Type=8 if notempchk==2 & empchk==1
	replace Route3_Type=9 if notempchk==2 & empchk==2
	label values Route3_Type route3_type
	
	save "${dta_fld}/UKHLS Annual History - Raw", replace
	}
tab Wave AnnualHistory_Routing
tab Route3_Type Wave

/*
2A. Harmonise and save spell end reason data.
	// Main reason for job end recorded only in a single variable in Waves 1-3. 
	// From Wave 4 onwards, each reason recorded in separate variables.
*/
*i. Creates variables for each reason and replaces with 1 if stated as main reason for leaving job, otherwise missing.
	* Also reformats reasend97`i' to reasend97_`i' in line with other reasend variables.
	// Creation of variables works using fact that variable ==. if not previously present when waves are appended to one another.
	// Given only one answer possible in main reason, not stating other reasons does not imply these were not factors for leaving job (hence missing)
	// NXTENDREASi QUESTIONS NOT ASKED IN WAVE 3 AND EARLIER.
qui{
	prog_reopenfile "${dta_fld}/UKHLS Annual History - Raw.dta"
	qui ds nextstat*
	local spells: word count `r(varlist)'
	replace nxtendreas=cond(cjob==2,.m,.i) if nxtendreas==. & nxtendreas1==.
	foreach var of varlist stendreas jbendreas nxtendreas{
		foreach i of numlist 1/11 97{
			replace `var'`i'=cond(`var'==`i',1,cond(`var'==.i,.i,.m)) if `var'!=.
			}
		drop `var'
		}
	rename reasend97* reasend97_*
	forval i=1/`spells'{
		capture gen reasend`i'=.i
		foreach j of numlist 1/11 97{
			capture gen reasend`j'_`i'=.i
			replace reasend`j'_`i'=cond(reasend`i'==`j',1,cond(reasend`i'==.i,.i,.m)) if reasend`i'!=.
			}
		drop reasend`i'
		}
	
	foreach i of numlist 1/11 97{
		gen End_Reason`i'_0=cond(empchk==2,stendreas`i',cond(jbsamr==2,jbendreas`i',.i))
		gen End_Reason`i'_1=cond(cjob==2,nxtendreas`i',.i) 
		}
	qui ds nextstat*
	local spells: word count `r(varlist)'
	forval i=1/`spells'{
		local j=`i'+1
		foreach k of numlist 1/11 97{
			gen End_Reason`k'_`j'=cond(currjob`i'==2,reasend`k'_`i',.i)
			}
		}	
	
	keep pidp Wave End_Reason*
	compress
	ds End_Reason*_1
	local vlist=subinstr("`r(varlist)'","_1","_",.)
	di "`vlist'"
	reshape long `vlist', i(pidp Wave) j(Spell)
	rename *_ *
	drop if End_Reason1==.i
	save "${dta_fld}/UKHLS Annual History End Reasons", replace
	}
*/

/*
2B. Format annual history dataset - All Routes
	/// Logic of Route 3 is that only spells via notempchk can be relied upon. 
	* Left hand notempchk routing takes precedence where both sides route into a question (UKHLS Forum Issue #957).
*/
/**/
qui{
	prog_reopenfile "${dta_fld}/UKHLS Annual History - Raw.dta"

	drop stendreas* jbendreas* nxtendreas* reasend*
	merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogenerate keepusing(Prev_Job_Hours Next_ff_jbstat Next_ff_jbsemp) /*
		*/ keep(match master)
	replace Prev_Job_Hours=.m if Prev_Job_Hours==.

	*Index Spell*
	gen Has_Activity0=1

	gen Status0=ff_jbstat

	gen Source_Variable0="ff_jbstat_w"+strofreal(Wave)

	gen End_Ind0=.m
	replace End_Ind0=0 if (notempchk==1 | samejob==1 | (empchk==1  & ff_jbstat==1)) /*
		*/ & inrange(AnnualHistory_Routing,1,2)
	replace End_Ind0=1 if (notempchk==2 | empchk==2 | jbsamr==2 | samejob==2) /*
		*/ & inrange(AnnualHistory_Routing,1,2)
	replace End_Ind0=0 if notempchk==1 & AnnualHistory_Routing==3
	replace End_Ind0=1 if notempchk==2 & AnnualHistory_Routing==3

	gen End_D0=cond(notempchk==2 | empchk==2,empstendd,cond(jbsamr==2 | samejob==2,jbendd,.)) /*
		*/ if inrange(AnnualHistory_Routing,1,2)
	gen End_M0=cond(notempchk==2 | empchk==2,empstendm,cond(jbsamr==2 | samejob==2,jbendm,.)) /* 
		*/ if inrange(AnnualHistory_Routing,1,2)
	gen End_Y0=cond(notempchk==2 | empchk==2,empstendy4,cond(jbsamr==2 | samejob==2,jbendy4,.)) /*
		*/ if inrange(AnnualHistory_Routing,1,2)
	replace End_D0=empstendd if notempchk==2 & AnnualHistory_Routing==3
	replace End_M0=empstendm if notempchk==2 & AnnualHistory_Routing==3
	replace End_Y0=empstendy4 if notempchk==2 & AnnualHistory_Routing==3
	
	gen Job_Hours0=Prev_Job_Hours if notempchk==.i & /*
		*/ (End_Ind0==.m | (End_Ind0==0 & missing(jbft_dv)) | End_Ind0==1) /*
		*/ & inrange(AnnualHistory_Routing,1,2)
	replace Job_Hours0=jbft_dv if notempchk==.i & End_Ind0==0 & !missing(jbft_dv) /*
		*/ & inrange(AnnualHistory_Routing,1,2)
	replace Job_Hours0=. if missing(Job_Hours0)
	
	gen Job_Change0=.i
	replace Job_Change0=0 if inlist(Status0,1,2,100)

	gen Job_Attraction0=.

	*Spell 1*
	gen Has_Activity1=1 if End_Ind0==1

	gen Status1=.m if Has_Activity1==1
	replace Status1=1 if (inrange(AnnualHistory_Routing,1,2) | (AnnualHistory_Routing==3 & nxtst==1)) & /*
		*/ (nxtjbes==2 | /*
		*/ (cjob==1 & Next_ff_jbstat==1) | /*
		*/ (cjob==1 & inrange(Next_ff_jbstat,1,2)!=1 & jbstat==1) | /*
		*/ (cjob==1 & inrange(Next_ff_jbstat,1,2)!=1 & inrange(jbstat,1,2)!=1 & Next_ff_jbsemp==2) | /*
		*/ (cjob==1 & inrange(Next_ff_jbstat,1,2)!=1 & inrange(jbstat,1,2)!=1 & inrange(Next_ff_jbsemp,1,2)!=1 & jbsemp==2))
	replace Status1=2 if (inrange(AnnualHistory_Routing,1,2) | (AnnualHistory_Routing==3 & nxtst==1)) & /*
		*/ (nxtjbes==1 | /*
		*/ (cjob==1 & Next_ff_jbstat==2) | /*
		*/ (cjob==1 & inrange(Next_ff_jbstat,1,2)!=1 & jbstat==2) | /*
		*/ (cjob==1 & inrange(Next_ff_jbstat,1,2)!=1 & inrange(jbstat,1,2)!=1 & Next_ff_jbsemp==1) | /*
		*/ (cjob==1 & inrange(Next_ff_jbstat,1,2)!=1 & inrange(jbstat,1,2)!=1 & inrange(Next_ff_jbsemp,1,2)!=1 & jbsemp==1))
	replace Status1=nxtstelse+2 if inrange(nxtstelse,1,7)
	replace Status1=97 if nxtstelse==8
	replace Status1=100 if inrange(Status1,1,2)!=1 & /*
		*/ (nxtst==1 |(inrange(AnnualHistory_Routing,1,2) & (jbsamr==2 | samejob==2)))
	replace Status1=101 if nxtst==2 & missing(nxtstelse)

	gen Source_Variable1=""
	replace Source_Variable1="nxtjbes_w"+strofreal(Wave) /*
		*/ if inrange(Status1,1,2) & inrange(nxtjbes,1,2)
	replace Source_Variable1="ff_jbstat_w"+strofreal(Wave+1) /*
		*/  if inrange(Status1,1,2) & Source_Variable1=="" & inrange(Next_ff_jbstat,1,2)
	replace Source_Variable1="jbstat_w"+strofreal(Wave) /*
		*/  if inrange(Status1,1,2) & Source_Variable1=="" & inrange(jbstat,1,2)
	replace Source_Variable1="ff_jbsemp_w"+strofreal(Wave+1) /*
		*/  if inrange(Status1,1,2) & Source_Variable1=="" & inrange(Next_ff_jbsemp,1,2)
	replace Source_Variable1="jbsemp_w"+strofreal(Wave) /*
		*/  if inrange(Status1,1,2) & Source_Variable1=="" & inrange(jbsemp,1,2)
	replace Source_Variable1="nxtstelse_w"+strofreal(Wave) /*
		*/  if inrange(Status1,3,97)
	replace Source_Variable1="nxtst_w"+strofreal(Wave) /*
		*/  if Status1==100 & nxtst==1
	replace Source_Variable1="jbsamr_w"+strofreal(Wave) /*
		*/  if Status1==100 & jbsamr==2
	replace Source_Variable1="samejob_w"+strofreal(Wave) /*
		*/  if Status1==100 & samejob==2
	replace Source_Variable1="nxtst_w"+strofreal(Wave) if Status1==101
	replace Source_Variable1="nxtst_w"+strofreal(Wave) /*
		*/  if inrange(Status1,100,101) & AnnualHistory_Routing==3

	gen End_Ind1=.m if Has_Activity1==1
	replace End_Ind1=0 if (cstat==2 | cjob==1) & inrange(AnnualHistory_Routing,1,2)
	replace End_Ind1=1 if (cstat==1 | cjob==2) & inrange(AnnualHistory_Routing,1,2)
	replace End_Ind1=0 if (cstat==2 | (cjob==1 & nxtst==1)) & Has_Activity1==1 & AnnualHistory_Routing==3
	replace End_Ind1=1 if (cstat==1 | (cjob==2 & nxtst==1)) & Has_Activity1==1 & AnnualHistory_Routing==3

	gen End_D1=cond(cstat==1,nxtstendd,cond(cjob==2,nxtjbendd,.)) if End_Ind1==1
	gen End_M1=cond(cstat==1,nxtstendm,cond(cjob==2,nxtjbendm,.)) if End_Ind1==1
	gen End_Y1=cond(cstat==1,nxtstendy4,cond(cjob==2,nxtjbendy4,.)) if End_Ind1==1

	gen Job_Hours1=nxtjbhrs if cjob==2 & (inrange(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))
	replace Job_Hours1=jbft_dv if cjob==1 & (inrange(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))
	replace Job_Hours1=. if missing(Job_Hours1)
	
	gen Job_Change1=.i if Has_Activity1==1
	replace Job_Change1=2 if samejob==2 & inlist(Status1,1,2,100)
	replace Job_Change1=3 if jbsamr==2 & inlist(Status1,1,2,100)	
	replace Job_Change1=3 if nxtst==1
	
	gen Job_Attraction1=cjbatt if cjob==1 & (inrange(AnnualHistory_Routing,1,2) | (nxtst==1 & AnnualHistory_Routing==3))
		
	*Spells 2+*
	qui ds nextstat*
	local spells: word count `r(varlist)'
	forval i=1/`spells'{

		local j=`i'+1

		gen Has_Activity`j'=1 if End_Ind`i'==1

		gen Status`j'=.m if Has_Activity`j'==1
		replace Status`j'=1 if nextjob`i'==3
		replace Status`j'=2 if inlist(nextjob`i',1,2,4)
		replace Status`j'=nextelse`i'+2 if inrange(nextelse`i',1,7)
		replace Status`j'=97 if nextelse`i'==8
		replace Status`j'=100 if nextstat`i'==1 & missing(nextjob`i')
		replace Status`j'=101 if nextstat`i'==2 & missing(nextelse`i')

		gen Source_Variable`j'=""
		replace Source_Variable`j'="nxtjob`i'_w"+strofreal(Wave) if Status`j'==1 | Status`j'==2
		replace Source_Variable`j'="nxtstelse`i'_w"+strofreal(Wave) if inrange(Status`j',3,97)
		replace Source_Variable`j'="nxtst`i'_w"+strofreal(Wave) if Status`j'==100 | Status`j'==101

		gen End_Ind`j'=.m if Has_Activity`j'==1
		replace End_Ind`j'=0 if Has_Activity`j'==1 & (currstat`i'==2 | currjob`i'==1)
		replace End_Ind`j'=1 if Has_Activity`j'==1 & (currstat`i'==1 | currjob`i'==2)

		gen End_D`j'=statendd`i' if End_Ind`j'==1
		gen End_M`j'=statendm`i' if End_Ind`j'==1
		gen End_Y`j'=statendy4`i' if End_Ind`j'==1

		gen Job_Hours`j'=jobhours`i' if currjob`i'==2
		replace Job_Hours`j'=jbft_dv if currjob`i'==1
		replace Job_Hours`j'=. if missing(Job_Hours`j')
		
		gen Job_Change`j'=.i if Has_Activity`j'==1
		replace Job_Change`j'=.m if nextjob`i'==.m
		replace Job_Change`j'=1 if nextjob`i'==4
		replace Job_Change`j'=2 if nextjob`i'==1
		replace Job_Change`j'=3 if nextjob`i'==2
		replace Job_Change`j'=3 /*
			*/ if (!inlist(Status`i',1,2,100) & nextstat`i'==1 & nextjob`i'!=4) /*
			*/ | nextjob`i'==3
		
		gen Job_Attraction`j'=jbatt`i' if currjob`i'==1
		
		}

	keep pidp Has_Activity* Status* Source_Variable* End* Job* /*
		*/ Wave Route3_Type
	reshape long Status Has_Activity Source_Variable End_Ind /*
		*/ End_D End_M End_Y Job_Hours Job_Attraction Job_Change, i(pidp Wave) j(Spell)
	keep if Has_Activity==1
	drop Has_Activity
	replace Job_Hours=.m if missing(Job_Hours) & inlist(Status,1,2,100)
	replace Job_Hours=.i if !inlist(Status,1,2,100)
	
	gen XX=ym(End_Y,End_M)
	gen YY=XX if Spell==1
	by pidp Wave, sort: egen ZZ=max(YY)
	gen AA=1 if ZZ>XX & !missing(ZZ,XX) & Spell>1 & Route3_Type==8
	drop if AA==1
	drop XX YY ZZ AA Route3_Type
	
	merge 1:1 pidp Wave Spell using "${dta_fld}/UKHLS Annual History End Reasons", keep(match master) nogen
	recode End_Reason* (missing=.i) if End_Ind==0
	recode End_Reason* (missing=.m) /*
		*/ if (End_Ind==1 | End_Ind==.m) & inlist(Status,1,2,100)
	recode End_Reason* (*=.i) if !inlist(Status,1,2,100)
	
	replace Job_Attraction=.m if inlist(Status,1,2,100) & missing(Job_Attraction)
	replace Job_Attraction=.i if !inlist(Status,1,2,100)
	foreach i of numlist 1/15 97{
		gen Job_Attraction`i'=cond(Job_Attraction==.i,.i,cond(Job_Attraction==`i',1,.m))
		}
	drop Job_Attraction
	
	gen Source=substr(subinstr("`c(alpha)'"," ","",.),Wave-18,1)+"_indresp"
	
	by pidp Wave (Spell), sort: replace Spell=_n
	drop End_D		
	
	save "${dta_fld}/UKHLS Annual History - Collected", replace
	}

	
/*
3. Clean annual history dataset
*/
/**/
do "${do_fld}/Clean Dependent Annual History.do"	
save "${dta_fld}/UKHLS Annual History", replace
*/


/*
4. Merge with Initial Job Information
*/
/**/
do "${do_fld}/UKHLS Initial Job.do" 
append using "${dta_fld}/UKHLS Annual History", gen(XX)
by pidp Wave, sort: gen YY=_N
drop if XX==0 & YY>1
by pidp (Wave), sort: egen ZZ=min(Wave)
drop if XX==0 & Wave>ZZ		// DROP IF INITIAL JOB IS AFTER UKHLS ANNUAL HISTORY.
drop XX YY ZZ

prog_waveoverlap			// TRUNCATES SPELLS WHICH OVERLAP WITH RESPONSES FROM A PREVIOUS WAVE
prog_collapsespells			// COLLAPSES SIMILAR NON-EMPLOYMENT SPELLS INTO CONTINUOUS SPELL

prog_format
save "${dta_fld}/UKHLS Annual History", replace
*/


/*
5.	Delete Unused Files
*/
/**/
rm "${dta_fld}/UKHLS Initial Job.dta" 
rm "${dta_fld}/UKHLS Annual History - Collected.dta"
rm "${dta_fld}/UKHLS Annual History - Raw.dta"
rm "${dta_fld}/UKHLS Annual History End Reasons.dta"
*/
