/*
********************************************************************************
INTERVIEW GRID.DO
	
	THIS FILE CREATES A DATASET OF VARIABLES (BIRTH DATES, INTERVIEW DATES) WHICH
	ARE USED FREQUENTLY TO CONSTRUCT WORKING-LIFE HISTORIES.
	
********************************************************************************
*/

/*
1. Dataset Preparation.
*/
/**/
	*i. Bring in interview dates, interview type and main work status/job characteristics variables from indresp files.
		*Feed these forward and backwards best on next and last interviews.
		*Replace missing values with .m (missing) or .i (inapplicable).
		*Check the number of discordances between ff_jbstat and Prev_jbstat is small (some will be due to data cleaning).
		/// BHPS Wave 1 interviews all took place in 1991 and no interview date variable is available for this wave.
* A. COLLECT VARIABLES FROM INDRESP FILES RELATED TO:
	* INTERVIEW DATES, CURRENT AND LAGGED JOB AND ECONOMIC ACTIVITY.
global vlist 	istrtdatm istrtdaty jbft ivfio intdatm_dv ///
				intdaty_dv jbft_dv ff_jbstat ff_jbsemp jbstat	
local k=0
forval i=1/$max_waves{
	local j: word `i' of `c(alpha)'
	if `i'<=$ukhls_waves{
		prog_getvars vlist `j' "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}"		// prog_getvars adds wave specfic stubs to names in global vlist and then searches for these variables in relevent data file
		rename `j'_* *
		gen Wave=`i'+18		// UKHLS set as Wave>=19
		local k=`k'+1
		tempfile Temp`k'
		save "`Temp`k''", replace
		}
	if `i'<=$bhps_waves{
		prog_getvars vlist b`j' "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}"
		rename b`j'_* *
		gen Wave=`i'
		local k=`k'+1
		tempfile Temp`k'
		save "`Temp`k''", replace
		}
	}
forval i=`=`k'-1'(-1)1{
	append using "`Temp`i''"
	}
	
* B. COLLECT BIRTH DATES AND HOUSEHOLD IDs FROM CROSS-WAVE FILES.	
merge m:1 pidp using "${fld}/${bhps_path}_wx/xwaveid_bh${file_type}", /*
	*/ keepusing(birth*) keep(match master) nogenerate
merge m:1 pidp using "${fld}/${ukhls_path}_wx/xwavedat${file_type}", /*
	*/ keepusing(dob*) keep(match master) nogenerate	
preserve
	use pidp *hidp using "${fld}/${ukhls_path}_wx/xwaveid${file_type}", clear
	merge 1:1 pidp using "${fld}/${bhps_path}_wx/xwaveid_bh${file_type}", /*
		*/ keepusing(*hidp) nogenerate
	forval i=1/$max_waves{
		local j=word("`c(alpha)'",`i')
		if `i'<=$bhps_waves{
			rename b`j'_hidp hidp`i'
			}
		if `i'<=$ukhls_waves{
			rename `j'_hidp hidp`=`i'+18'
			}
		}
	reshape long hidp, i(pidp) j(Wave)
	drop if hidp<0
	tempfile Temp
	save "`Temp'", replace
restore
merge 1:1 pidp Wave using "`Temp'", keep(match master) nogenerate

* C. CLEAN DATASET
	* i. REPLACE NEGATIVE VALUES WITH STATA . MISSING VALUES (prog_recodemissing)
order pidp Wave
prog_recodemissing *

	* ii. GET BIRTH DATES. IF MONTH OF BIRTH MISSING (AS IN NORMAL EUL DATASET, SET BIRTH MONTH TO 6)
capture confirm variable dobm_dv birthm
if _rc==0{
	gen Birth_M=cond(!missing(dobm_dv),dobm_dv,birthm)
	replace Birth_M=.m if missing(Birth_M)
	}
else{
	gen Birth_M=6
	}
gen Birth_Y=cond(!missing(doby_dv),doby_dv,birthy)
replace Birth_Y=.m if missing(Birth_Y)
replace Birth_M=6 if missing(Birth_M) & !missing(Birth_Y)
gen Birth_S=floor(Birth_M/3)+1
gen Birth_MY=ym(Birth_Y,Birth_M)
gen Birth_SY=ym(Birth_Y,Birth_S)
drop dob* birth*

	* ii. CLEAN INTERVIEW DATE AND JOB HOUR VARIABLES.
gen Job_Hours_IG=cond(Wave<=18,jbft,jbft_dv)	
replace istrtdaty=1991 if Wave==1 & istrtdatm!=.
gen IntDate_M=cond(intdatm_dv!=.,intdatm_dv,istrtdatm)
gen IntDate_S=cond(!missing(IntDate_M),floor(IntDate_M/3)+1,.m)
gen IntDate_Y=cond(intdaty_dv!=.,intdaty_dv,istrtdaty)
gen IntDate_MY=ym(IntDate_Y,IntDate_M)
gen IntDate_SY=ym(IntDate_Y,IntDate_S)	
drop istrtdat* intdat* jbft*

	* iii. DRAG JOB HOURS/ACTIVTY FROM THE NEXT AND PREVIOUS NON-PROXY INTERVIEWS (I.E. IVFIO!=2)
by pidp (Wave), sort: gen n=_n
gen Reverse=-Wave			// STATA EVALUATES COMMANDS ROW-BY-ROW AND BASES CALCULATIONS ON CURRENT VALUES, NOT ON THOSE BEFORE THE COMMAND WAS RUN. A COMMAND WHICH USES A VALUE IN THE PREVIOUS ROW (E.G. GEN XX=XX[_n-1]) WILL BE BASED ON THE VALUE OF THE PREVIOUS ROW AFTER IT MAY HAVE BEEN ALREADY CHANGED. THIS LINE ALLOWS ME TO SORT THE DATASET SO THAT VALUES IN LATER WAVES CAN BE DRAGGED THROUGH THE DATASET WITH A SINGLE LINE RATHER THAN A LOOP.
foreach i in Prev Next{
	if "`i'"=="Prev"	local sort "Wave"
	else				local sort "Reverse"	
	gen XX=n if inlist(ivfio,1,3) 	// F2F AND TELPHONE INTERVIEWS
	by pidp (`sort'), sort: gen `i'_Wave=XX[_n-1]
	by pidp (`sort'), sort: replace `i'_Wave=`i'_Wave[_n-1] /*
		*/ if missing(`i'_Wave)
	drop XX
	}
by pidp (Wave), sort: gen Prev_Job_Hours=Job_Hours_IG[Prev_Wave]
foreach var of varlist ff_jbstat ff_jbsemp{
	by pidp (Wave), sort: gen Next_`var'=`var'[Next_Wave]
	}
drop Reverse n

	* iv. GENERATE LOWER BOUND DATES FOR THE ANNUAL HISTORY QUESTIONNAIRES.
		* IN THE UKHLS & BHPS WAVES 16-18 FOR RETURNING PARTICIPANTS, THIS IS PREVIOUS NON-PROXY INTERVIEW. 
		* IN BHPS WAVES 1-15 (OR 1-18 IF NEW PARTIPANT), THIS IS SEPTEMBER PRIOR TO FIELDWORK BEGGINING (E.G. SEP 1990 IN WAVE 1)
foreach i in M S Y MY SY{
	by pidp (Wave), sort: gen LB_`i'=IntDate_`i'[Prev_Wave]  /*
		*/ if (Wave>18 | /*
		*/ (inrange(Wave,16,18) & inrange(Wave-Wave[Prev_Wave],1,2))) /*
		*/ & !missing(IntDate_MY)
	replace LB_`i'=.m if missing(LB_`i')
	}
local if "if (inrange(Wave,16,18) & !inrange(Wave-Wave[Prev_Wave],1,2)) | Wave<=15"
by pidp (Wave), sort: replace LB_M=9 `if'
by pidp (Wave), sort: replace LB_S=4 `if'
by pidp (Wave), sort: replace LB_Y=1989+Wave `if'
by pidp (Wave), sort: replace LB_MY=ym(1989+Wave,9) `if'
by pidp (Wave), sort: replace LB_SY=ym(1989+Wave,4) `if'
	
by pidp (Wave), sort: replace Prev_Wave=Wave[Prev_Wave]
by pidp (Wave), sort: replace Next_Wave=Wave[Next_Wave]
drop ff*

order Prev* Next* LB*, last
save "${dta_fld}/Interview Grid", replace
*/
	
