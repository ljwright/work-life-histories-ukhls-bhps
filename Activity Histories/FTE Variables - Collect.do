/**/
#delim ;
global schoolvars 	" school scend scnow sctype fetype fenow fenow_bh
feend hiqual qfhas fachi hiqual_dv
qfhigh_dv edtypev j1none lgaped lednow
ledendm ledendy ledeny4 edtype edlyr jbstat
jbstat_bh edendm edendy4 qfachi qfedhi ivfio" ;
#delim cr

local a=0
foreach survey in bhps ukhls{
	
	if "`survey'"=="bhps"	local b="b"
	else	local b=""

	forval i=1/$`survey'_waves{
		local a=`a'+1
		local j: word `i' of `c(alpha)'
		prog_addprefix schoolvars `b'`j' /*
			*/ "${fld}/${`survey'_path}_w`i'/`b'`j'_indresp${file_type}"
		rename `b'`j'_* *
		if "`survey'"=="bhps"{
			rename school school_bh
			capture rename edtype edtype_bh
			}
		gen Wave=`a'
		if `a'==1	replace jbstat=8 if jbstat_bh==7
		tempfile Temp`a'
		save "`Temp`a''", replace
		}
	}
forval i=`=`a'-1'(-1)1{
	append using "`Temp`i''"
	}
merge m:1 pidp using "${fld}/${ukhls_path}_wx/xwavedat${file_type}", /*
		*/ nogen keepusing(scend_dv feend_dv school_dv)	keep(match master)
merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keepusing(IntDate_MY Birth_MY)	
merge 1:1 pidp Wave using "${dta_fld}/BHPS Education Dates", /*
		*/ nogen
gen Age_Y=floor((IntDate_MY-Birth_MY)/12)
save "${dta_fld}/Education Variables", replace	

foreach i of global ukhls_lifehistwaves{
	local j: word `i' of `c(alpha)'
	use pidp *lesh* `j'_spellno using /*
		*/ "${fld}/${ukhls_path}_w`i'/`j'_empstat${file_type}", clear
	rename `j'_* *
	gen Wave=`i'+18
	tempfile Temp2_`i'
	save "`Temp2_`i''", replace
	}
append using `Temp2_1'
merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match master) keepusing(Birth_MY)	
gen Start_M=	cond(leshsy4<0,.m, /*
			*/	cond(leshem<0,7, /*
			*/	cond(inrange(leshem,1,12),leshem, /*
			*/	cond(leshem==13,12, /*
			*/	cond(inrange(leshem,14,17),(leshem-14)*3+1,.m)))))
gen Start_Y=cond(leshsy4>0,leshsy4,.m)
gen Start_MY=ym(Start_Y,Start_M)
gen Spell=spellno
drop leshem leshsy4 Start_? spellno

by pidp Wave (Spell), sort: gen N=(_n==_N)
tab leshst N
gen XX=Spell if !inlist(leshst,-2,-1,0,8)
by pidp Wave (Spell), sort: egen YY=min(XX)
by pidp Wave (Spell), sort: gen UKHLS_LH_FIN_MY=Start_MY[YY]
keep if Spell==1 & !missing(UKHLS_LH_FIN_MY)
keep pidp Wave UKHLS_LH_FIN_MY
merge 1:1 pidp Wave using "${dta_fld}/Education Variables", nogen

order pidp Wave
quietly labelbook
label drop `r(notused)'
numlabel _all, add
format *MY %tm
compress

by pidp (Wave), sort: gen tag= (_n==1)
prog_sort
by pidp (Wave), sort: egen XX=max(Age_Y<15)
drop if XX==1 | missing(Age_Y)
drop XX

// BHPS NEW (1)
cls
tab1 school_bh scend scnow fetype fenow_bh feend if Wave<=18, m

table scend Age_Y if scend>Age_Y & Wave<=18
gen S_1_FIN_MY=ym(year(dofm(Birth_MY))+scend,6) /*
	*/ if month(dofm(Birth_MY))<9 & Wave<=18 /*
	*/ & scend>0 & scend<=Age_Y
replace S_1_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
	*/ if month(dofm(Birth_MY))>=9 & Wave<=18 /*
	*/ & scend>0 & scend<=Age_Y	
prog_monthsafterint S_1_FIN_MY
replace S_1_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+scend*12)/2) if $if
gen S_1_IN_MY=IntDate_MY if (school_bh==2 | scnow==1) & Wave<=18
replace S_1_IN_MY=IntDate_MY /*
	*/ if Wave<=18 & scend>0 & scend>Age_Y & !missing(scend)
gen S_1_NO_MY=IntDate_MY if school_bh==1 & Wave<=18

table feend Age_Y if feend>Age_Y & Wave<=18
gen F_1_FIN_MY=ym(year(dofm(Birth_MY))+feend,6) /*
	*/ if month(dofm(Birth_MY))<9 & Wave<=18 /*
	*/ & feend>0 & feend<=Age_Y
replace F_1_FIN_MY=ym(year(dofm(Birth_MY))+feend+1,6) /*
	*/ if month(dofm(Birth_MY))>=9 & Wave<=18 /*
	*/ & feend>0 & feend<=Age_Y
prog_monthsafterint F_1_FIN_MY
replace F_1_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+feend*12)/2) if $if
gen F_1_IN_MY=IntDate_MY if fenow_bh==1 & Wave<=18
replace F_1_IN_MY=IntDate_MY /*
	*/ if Wave<=18 & feend>0 & feend>Age_Y & !missing(feend)
gen F_1_NO_MY=IntDate_MY if fetype==7 & Wave<=18

foreach i in S F{
	prog_makevars `i'_1_FIN `i'_1_IN `i'_1_NO
	}
prog_sort
drop school_bh scnow fenow_bh fetype

// BHPS OLD [WAVE,2,7] (2)
cls
tab1 jbstat edlyr edendm edendy4 edtype if inrange(Wave,2,7), m
gen XX=edendm if inrange(edendm,1,12)
replace XX=9 if missing(edendm) & inrange(edendy4,1991,1996)
gen YY=edendy4 if inrange(edendy4,1991,1996)

gen S_2_FIN_MY=ym(YY,XX) if inrange(edtype_bh,1,2) & inrange(Wave,2,7)
gen S_2_IN_MY=IntDate_MY if inrange(edtype_bh,1,2) & inrange(Wave,2,7) /*
	*/ & (jbstat==7 | edendm==-3 | edendy4==-3)
prog_monthsafterint S_2_FIN_MY

gen F_2_FIN_MY=ym(YY,XX) if inrange(edtype_bh,3,5) & inrange(Wave,2,7)
gen F_2_IN_MY=IntDate_MY if inrange(edtype_bh,3,5) & inrange(Wave,2,7) /*
	*/ & (jbstat==7 | edendm==-3 | edendy4==-3)
prog_monthsafterint F_2_FIN_MY

foreach i in S F{
	prog_makevars `i'_2_FIN `i'_2_IN
	}
prog_sort
drop edendm edendy4 XX YY

// UKHLS NEW (5)
cls
tab1 school scend fenow feend if Wave>18, m

table scend Age_Y if scend>Age_Y & Wave>18
gen S_5_FIN_MY=ym(year(dofm(Birth_MY))+scend,6) /*
	*/ if month(dofm(Birth_MY))<9 & Wave>18 /*
	*/ & scend>0 & scend<=Age_Y
replace S_5_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
	*/ if month(dofm(Birth_MY))>=9 & Wave>18 /*
	*/ & scend>0 & scend<=Age_Y	
gen S_5_IN_MY=IntDate_MY if school==3 & Wave>18
replace S_5_IN_MY=IntDate_MY /*
	*/ if Wave>18 & scend>0 & scend>Age_Y & !missing(feend)
gen S_5_NO_MY=IntDate_MY if school==2 & Wave>18
prog_monthsafterint S_5_FIN_MY
replace S_5_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+scend*12)/2) if $if

table feend Age_Y if feend>Age_Y & Wave>18
gen F_5_FIN_MY=ym(year(dofm(Birth_MY))+feend,6) /*
	*/ if month(dofm(Birth_MY))<9 & Wave>18 /*
	*/ & feend>0 & feend<=Age_Y
replace F_5_FIN_MY=ym(year(dofm(Birth_MY))+feend+1,6) /*
	*/ if month(dofm(Birth_MY))>=9 & Wave>18 /*
	*/ & feend>0 & feend<=Age_Y
gen F_5_IN_MY=IntDate_MY if fenow==3 & Wave>18
replace F_5_IN_MY=IntDate_MY /*
	*/ if Wave>18 & feend>0 & feend>Age_Y & !missing(scend)
gen F_5_NO_MY=IntDate_MY if fenow==2 & Wave>18
prog_monthsafterint F_5_FIN_MY
replace F_5_FIN_MY=floor((IntDate_MY/2)+(Birth_MY+feend*12)/2) if $if

foreach i in S F{
	prog_makevars `i'_5_FIN `i'_5_IN `i'_5_NO
	}
prog_sort
drop school scend fenow feend

// UKHLS ALL (6)
cls
tab1 jbstat edtype if Wave>18, m
gen S_6_IN_MY=IntDate_MY if inrange(edtype,1,2) & Wave>18
gen F_6_IN_MY=IntDate_MY if inrange(edtype,3,5) & Wave>18

prog_makevars S_6_IN F_6_IN
prog_sort
drop jbstat edtype

// LIFE HISTORY (7,8,9)
cls
tab1 ledendm ledendy ledeny4 lgaped lednow /*
	*/ if inlist(Wave,2,11,12,19,23), m
gen XX=		cond(ledeny4<0,.m, /*
		*/	cond(ledendm<0,7, /*
		*/	cond(inrange(ledendm,1,12),ledendm, /*
		*/	cond(ledendm==13,7, /*
		*/	cond(inrange(ledendm,14,16),(ledendm-13)*3+1,.m)))))
gen YY=cond(inrange(ledeny4,1890,2009),ledeny4,.m)
gen LH_FIN_MY=ym(YY,XX)
replace LH_FIN_MY=UKHLS_LH_FIN_MY if !missing(UKHLS_LH_FIN_MY)
gen LH_IN_MY=IntDate_MY if lgaped==2 | lednow==0
gen LH_NO_MY=IntDate_MY if lednow==1

prog_makevars LH_IN LH_FIN LH_NO
prog_sort
drop ledendm ledendy ledeny4 lgaped lednow XX YY UKHLS_LH_FIN_MY

// CROSS-WAVE (10)
gen S_10_FIN_MY=ym(year(dofm(Birth_MY))+scend_dv,6) /*
	*/ if month(dofm(Birth_MY))<9 & scend_dv>0
replace S_10_FIN_MY=ym(year(dofm(Birth_MY))+scend+1,6) /*
	*/ if month(dofm(Birth_MY))>=9 & scend_dv>0
gen F_10_FIN_MY=ym(year(dofm(Birth_MY))+feend_dv,6) /*
	*/ if month(dofm(Birth_MY))<9 & feend_dv>0
replace F_10_FIN_MY=ym(year(dofm(Birth_MY))+feend_dv+1,6) /*
	*/ if month(dofm(Birth_MY))>=9 & feend_dv>0
	
prog_makevars S_10_FIN F_10_FIN
prog_sort
drop scend_dv feend_dv school_dv

// MISCELLANEOUS QUESTIONS
gen M_IN_MY=IntDate_MY if j1none==1
prog_sort
drop j1none

drop edlyr sctype qfhas edtype_bh jbstat_bh *edtype
compress

* 	NEED TO AMEND THIS SO DOESN'T END AFTER INTERVIEW DATE.
*	THINK ABOUT HOW TO TREAT THOSE WITH NO SCHOOLING.
	
save "${dta_fld}/Education Variables - Formatted" , replace
*/
