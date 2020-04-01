/*
********************************************************************************
BHPS ANNUAL HISTORY - WAVES 1 -15.DO
	
	THIS FILE CLEANS ANNUAL HISTORY DATA FROM WAVES 1-15 OF THE BHPS
	(I.E. BEFORE DEPENDENT INTERVIEWING WAS INTRODUCED)

********************************************************************************
*/


/*
1. Collect indresp data
*/
/**/
#delim ;
global vlist 	"jbstat nemst emplw jbhas jboff jbsemp ivfio
				jbft_dv jbstat_bh cjsbgm cjsbgy cjsbgy4 cjsbly" ;
#delim cr
forval i=1/`=min(15,$bhps_waves)'{
	local j: word `i' of `c(alpha)'	
	prog_getvars vlist b`j' "${fld}/${bhps_path}_w`i'/b`j'_indresp${file_type}"
	rename b`j'_* *
	gen Wave=`i'
	tempfile Temp`i'
	save "`Temp`i''", replace	
	}
forval i=`=min(15,$bhps_waves)-1'(-1)1{
	append using "`Temp`i''"
	}
	
save "${dta_fld}/BHPS 1-15 Indresp - Raw", replace
macro drop vlist
*/

/*
2. Clean indresp data
*/
/**/
prog_reopenfile "${dta_fld}/BHPS 1-15 Indresp - Raw"
prog_labels
keep if inlist(ivfio,1,3)
drop ivfio
prog_recodemissing *

gen Spell=0
gen emplw=cond(jbhas==1 | jboff==1,1,2)
count if jbstat==7 & Wave==1
if `r(N)'!=664{			
	di in red "Wave 1 dataset may have been cleaned."
	STOP
	}	
replace jbstat=8 if jbstat_bh==7 & Wave==1
replace nemst=97 if nemst==10
gen JobHistHas=cjsbly
label values JobHistHas jobhisthas
drop jbstat_bh jbhas jboff cjsbly

gen Status=.m
replace Status=1 if emplw==1 & jbsemp==2
replace Status=2 if emplw==1 & jbsemp==1
replace Status=100 if emplw==1 & missing(jbsemp)
replace Status=nemst if !missing(nemst) & (emplw!=1 | (jbstat==7 & Wave>1))
replace Status=jbstat if missing(nemst) & !missing(jbstat) /*
	*/ & (emplw!=1 | (jbstat==7 & Wave>1))
label values Status status
noisily tab1 Status emplw nemst jbstat, missing

gen Source_Variable=""
replace Source_Variable="jbsemp_w"+strofreal(Wave) if emplw==1
replace Source_Variable="nemst_w"+strofreal(Wave) /*
	*/ if !missing(nemst) & (emplw!=1 | (jbstat==7 & Wave>1))
replace Source_Variable="jbstat_w"+strofreal(Wave) /*
	*/ if missing(nemst) & !missing(jbstat) /*
	*/ & (emplw!=1 | (jbstat==7 & Wave>1))
	
gen Job_Hours=jbft
replace Job_Hours=.i if !inrange(Status,1,2)
replace Job_Hours=.m if inrange(Status,1,2) & missing(Job_Hours)
label values emplw emplw
label values Job_Hours job_hours
drop jb* nemst emplw 

replace cjsbgy4=.m if cjsbgy4>2010 & !missing(cjsbgy4)
replace cjsbgm=cjsbgy4 if missing(cjsbgy4)
gen Start_Y=cjsbgy4
gen Start_M=cond(cjsbgm>=1 & cjsbgm<=12,cjsbgm,.m)
gen Start_S=cond(cjsbgm==.i,.i,.m)
replace Start_S=1 if inrange(cjsbgm,1,2)
replace Start_S=2 if inlist(cjsbgm,3,4,5,14)
replace Start_S=3 if inlist(cjsbgm,6,7,8,15)
replace Start_S=4 if inlist(cjsbgm,9,10,11,16)
replace Start_S=5 if cjsbgm==12
gen Winter=cond(cjsbgm==13,1,0)
gen Start_MY=ym(Start_Y,Start_M)
gen Start_SY=ym(Start_Y,Start_S)
drop cjsbgm cjsbgy4 cjsbgy Start_M Start_S

gen End_Ind=0
gen End_Reason=.i

order pidp Wave Spell Status Start* Job_Hours JobHist*
gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_indresp"
save "${dta_fld}/BHPS 1-15 Indresp", replace
rm "${dta_fld}/BHPS 1-15 Indresp - Raw.dta"
*/

/*
3. Collect jobhist data
*/
/**/
global vlist "jhstat jspno jhbgm jhbgy jhbgy4 jhsemp jhstpy jblky"
forval i=1/`=min(15,$bhps_waves)'{
	local j: word `i' of `c(alpha)'
	prog_getvars vlist b`j' "${fld}/${bhps_path}_w`i'/b`j'_jobhist${file_type}"
	rename b`j'_* *
	capture rename *_bh *
	gen Wave=`i'
	noisily label list b`j'_jhstat
	if `i'==1{
		recode jhstat 5=6 6=7 7=8 8=5
		}
	keep pidp Wave jhstat jspno jhbgm jhbgy4 jhsemp* jhstpy jblky
	order pidp Wave jspno
	tempfile Temp`i'
	save "`Temp`i''", replace		
	}
forval i=`=min(15,$bhps_waves)-1'(-1)1{
	append using "`Temp`i''"
	}
save "${dta_fld}/BHPS 1-15 Jobhist - Raw.dta", replace
*/

/*
4. Clean jobhist data
*/
/**/
use "${dta_fld}/BHPS 1-15 Jobhist - Raw", clear
prog_labels
prog_recodemissing *

gen Spell=jspno
drop jspno

gen Job_Attraction=jblky if inrange(jblky,1,5) & Wave==1
replace Job_Attraction=jblky+1  if inrange(jblky,6,14) & Wave==1
replace Job_Attraction=jblky if inrange(jblky,1,15) & Wave>=2
replace Job_Attraction=15 if jblky==16 & Wave>=2
replace Job_Attraction=97 if jblky==96
replace Job_Attraction=.m if missing(Job_Attraction)
drop jblky

replace jhstat=97 if jhstat==10
gen Status=cond(inrange(jhstat,3,97),jhstat,.m)
replace Status=1 if jhsemp==3
replace Status=2 if jhsemp==1 | jhsemp==2 | jhstat==1
replace Status=100 if missing(jhsemp) & jhstat==2
label values Status status
noisily tab1 jhstat Status, missing

gen Source_Variable="jhstat_w"+strofreal(Wave)

gen Job_Hours=cond(inlist(jhsemp,1,2,.m),jhsemp,.i) // !missing(jbsemp) only for jhstat=2 but change of job could have been change of hours so keep missing!
replace Job_Hours=.i if inrange(Status,3,97)
replace Job_Hours=.m if Status==100 | Status==.i | (inrange(Status,1,2) & missing(Job_Hours))
label values Job_Hours job_hours

gen Job_Change_R=.i if !inlist(Status,1,2,100)
replace Job_Change_R=jhstat+1 if inlist(jhstat,1,2)
drop jhstat jhsemp

gen End_Reason=jhstpy if /*
	*/ inrange(jhstpy,1,10) | (jhstpy==11 & Wave>5)
replace End_Reason=11 if jhstpy==12 & Wave<=5
replace End_Reason=97 if /*
	*/ (inlist(jhstpy,11,13) & Wave<=5) | (inlist(jhstpy,12,13) & Wave>5) 
replace End_Reason=.i if inrange(Status,3,97)
replace End_Reason=.m if !inrange(Status,3,97) & missing(End_Reason)
drop jhstpy

replace jhbgm=.m if missing(jhbgy4) | jhbgy4>2010
replace jhbgm=.m if missing(jhbgy4)
gen Start_Y=jhbgy4
gen Start_M=cond(jhbgm>=1 & jhbgm<=12,jhbgm,.m)
gen Start_S=.m
replace Start_S=1 if inrange(jhbgm,1,2)
replace Start_S=2 if inlist(jhbgm,3,4,5,14)
replace Start_S=3 if inlist(jhbgm,6,7,8,15)
replace Start_S=4 if inlist(jhbgm,9,10,11,16)
replace Start_S=5 if jhbgm==12
gen Winter=cond(jhbgm==13,1,0)
gen Start_MY=ym(Start_Y,Start_M)
gen Start_SY=ym(Start_Y,Start_S)
drop jhbgm jhbgy4 Start_M Start_S

gen End_Ind=1

order pidp Wave Spell
gen Source="b"+substr(subinstr("`c(alpha)'"," ","",.),Wave,1)+"_jobhist"
save "${dta_fld}/BHPS 1-15 Jobhist", replace
rm "${dta_fld}/BHPS 1-15 Jobhist - Raw.dta"
*/


/*
5. Merge and Clean Data
*/
/**/
do "${do_fld}/Clean Non-Dependent Annual History.do"

prog_waveoverlap
prog_collapsespells

prog_format
save "${dta_fld}/BHPS 1-15 Annual History", replace
rm "${dta_fld}/BHPS 1-15 Indresp.dta"
rm "${dta_fld}/BHPS 1-15 Jobhist.dta"
