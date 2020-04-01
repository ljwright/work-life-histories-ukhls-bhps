/**/
//	1. GATHER PIDPS.
tempfile Temp
local vlist " hidp school fenow jbstat edtype lgaped month sampst ivfio intdatm_dv intdaty_dv hhorig memorig"
foreach i of numlist 1 5{
	local j: word `i' of `c(alpha)'
	local prefixlist: subinstr local vlist " " " `j'_", all
	
	use pidp `prefixlist' using /*
		*/ "${fld}/${ukhls_path}_w`i'/`j'_indresp${file_type}", clear
	gen `j'_IntDate_MY=ym(`j'_intdaty_dv,`j'_intdatm_dv) /*
		*/ if `j'_intdatm_dv>0 & `j'_intdaty_dv>0
	drop *intdat*
	preserve
		use pidp using /*
			*/ "${fld}/${ukhls_path}_w`i'/`j'_empstat${file_type}", clear
		duplicates drop
		tempfile Temp2
		save "`Temp2'", replace
	restore
	merge 1:1 pidp using "`Temp2'", gen(`j'_empstat) 
	capture merge 1:1 pidp using "`Temp'", nogen
	save "`Temp'", replace
	}
numlabel, add
order pidp a_* e_*
keep if a_sampst==1 & a_ivfio==1 & e_ivfio==1 & a_hhorig==1
keep if (a_school==2 | inlist(a_fenow,1,2,3)) & (e_jbstat!=7 | inlist(e_edtype,3,5))
drop if (a_empstat==3 & e_empstat==3) | (a_lgaped!=-8 & e_lgaped!=-8)
drop *sampst *ivfio *empstat *lgaped
merge m:1 pidp using "${dta_fld}/Left Full Time Education", /*
	*/ nogen keep(match master) keepusing(Birth_MY)
gen LifeHist_Wave=cond(a_month<=6,1,5)
egen Min_IntDate_MY=min(a_IntDate_MY)
gen Treated=cond(LifeHist_Wave==5,1,0)
gen Age_Y=floor((Min_IntDate_MY-Birth_MY)/12)
format *MY %tm
save "Working Paper", replace
*/

/**/
//	2. CHECK DIFFERENCE IN RECALL PERIOD.
prog_reopenfile "Working Paper"
gen RecallPeriod=cond(LifeHist_Wave==1,a_IntDate_MY,e_IntDate_MY)-Min_IntDate_MY
ttest RecallPeriod, by(LifeHist_Wave) // TEST 1.
*/

/**/
//	3. GET VARIABLES TO CREATE AND TEST PROPENSITY SCORES
prog_reopenfile "Working Paper"
#delim ;
global mergelist 	"a_ukborn a_scend a_feend a_paju a_maju
					a_lvag14 a_ynlp14 a_racel a_nmar a_sf1
					a_jbhas a_sclfsato a_sex_dv a_ethn_dv
					a_doby_dv a_country a_gor_dv a_urban_dv
					a_scghq1_dv a_sf12pcs_dv a_sf12mcs_dv
					a_swemwbs_dv a_bmi_dv a_hiqual_dv" ;
global mergelist2 	"a_tenure_dv";
#delim cr
merge 1:1 pidp using "${fld}/${ukhls_path}_w1/a_indresp${file_type}", /*
	*/ keep(match) keepusing($mergelist) nogen
merge m:1 a_hidp using "${fld}/${ukhls_path}_w1/a_hhresp${file_type}", /*
	*/ keep(match) keepusing($mergelist2) nogen
merge m:1 a_hidp using "stata/LSOA Codes/${ukhls_path}/a_lsoa01${file_type}", /*
	*/ keep(match) nogen
preserve
	insheet using /*
		*/ "Data/Data Linkage/CDRC - LSOA 2001 to English IMD 2010.csv", /*
		*/ comma clear
	rename lsoacode a_lsoa01
	tempfile Temp
	save "`Temp'", replace
restore
merge m:m a_lsoa01 using "`Temp'", gen(HasIMD) keep(match master)

prog_recodemissing a_*
local i=0
gen Variable=""
gen PVal=.
foreach var of global mergelist{
	local i=`i'+1
	qui ttest `var', by(LifeHist_Wave)
	replace Variable="`var'" in `i'
	replace PVal=r(p) in `i'
	}
tab a_gor_dv LifeHist_Wave if a_gor_dv!=12, m chi2 expected
drop Variable PVal

// ssc install psmatch2
gen Sex=cond(a_sex_dv==2,1,0) if inlist(a_sex_dv,1,2)
global vlist ""
foreach var of varlist a_ukborn a_gor_dv a_urban_dv a_tenure_dv{
	qui tab `var', gen(`var'_)
	global vlist "$vlist `var'_*"
	}
macro list vlist
dprobit Treated $vlist Age_Y Sex imd_score
capture drop Score
predict Score
psmatch2 Treated, pscore(Score)
pstest $vlist Age_Y imd_score, both scatter
preserve
	keep pidp Score
	merge 1:1 pidp using "Working Paper", nogen
	save "Working Paper", replace
restore
*/

//	4. MAKE PREDICTIONS:
	//	A. CURRENT UNEMPLOYMENT STATUS
	//	B. CURRENT UNEMPLOYMENT LENGTH
	//	C. KERNAL DENSITY ESTIMATE OF UNEMPLOYMENT LENGTH - FRACTION OF TOTAL OBSERVATIONS (TREATED OR NOT)
	// 	D. MISSING STATUS
	// 	E. MISSING STATUS LENGTH
	// 	F. CHANGE IN DIFFERENCE OF EACH THROUGH TIME.
use "Working Paper", clear
merge 1:m pidp using "${dta_fld}/UKHLS Life History", nogen keep(match master)
replace End_MY=Min_IntDate_MY if End_MY>Min_IntDate_MY
drop if End_MY<=Start_MY & !missing(Start_MY)
tab Status LifeHist_Wave if End_MY==Min_IntDate_MY, m chi2 expected V

gen Unem_Months=(End_MY-Start_MY)/12
gen Unem_Is=(Status==3)
psmatch2 Treated if End_MY==Min_IntDate_MY & Status==3, /*
	*/ pscore(Score) outcome(Unem_Months)
psmatch2 Treated if End_MY==Min_IntDate_MY, /*
	*/ pscore(Score) outcome(Unem_Is)
ttest Unem_Is if End_MY==Min_IntDate_MY & !missing(_treated), by(Treated)
	
ttest XX if End_MY==Min_IntDate_MY & Status==3, by(LifeHist_Wave)
graph twoway 	(kdensity XX if LifeHist_Wave==1) /*
	*/			(kdensity XX if LifeHist_Wave==5) /*
	*/ if End_MY==Min_IntDate_MY & Status==3 
drop XX

prog_imputemissingspells
table Status Spell, m 
tab Status LifeHist_Wave, m expected chi2 V

gen XX=Birth_MY+18*12
gen YY=Birth_MY+21*12
gen AA=Start_MY
gen BB=End_MY
replace AA=XX if XX>AA
replace BB=YY if YY<BB
replace AA=. if AA>BB | AA==BB | missing(BB)
replace BB=. if AA>BB | AA==BB | missing(AA)
gen CC=BB-AA
tab Status LifeHist_Wave /*
	*/ if CC>0 & Min_IntDate_MY>=YY /*
	*/ , m expected chi2 V // NEED TO DO ONLY IF AGED OVER 21.
by pidp (Wave Spell), sort: egen DD=sum(CC) if Status==3
by pidp (Wave Spell), sort: egen EE=max(DD)
replace EE=0 if EE==.
ttest EE if Spell==1 & EE>0 & Min_IntDate_MY>=YY, by(LifeHist_Wave)
gen FF=cond(EE>0 & !missing(EE),1,0)
ttest FF if Min_IntDate_MY>=YY, by(LifeHist_Wave)
graph twoway 	(kdensity EE if LifeHist_Wave==1) /*
	*/			(kdensity EE if LifeHist_Wave==5) /*
	*/ if Spell==1 & EE>0 & Min_IntDate_MY>=YY
*/

use pidp *IntDate_MY LifeHist_Wave using "Working Paper", clear
merge 1:m pidp using "${dta_fld}/UKHLS Life History", nogen keep(match master)
merge m:1 pidp using "${dta_fld}/Left Full Time Education", /*
	*/ nogen keep(match) keepusing(Birth_MY)
prog_imputemissingspells
gen Age_Y=floor((Min_IntDate_MY-Birth_MY)/12)
ttest Age_Y if Spell==1 | Spell==., by(LifeHist_Wave)

gen Test=""
gen Lag=.
gen Mean_1=.
gen Mean_5=.
gen Diff=.
gen PVal=.
local j=0
forval i=0/10{	
	capture drop AA-JJ
	gen AA=Min_IntDate_MY-((`i'*2)*12)-24
	gen BB=Min_IntDate_MY-((`i'*2)*12)
	gen CC=Start_MY
	gen DD=End_MY
	replace CC=AA if CC<AA
	replace DD=BB if DD>BB
	replace CC=. if CC>DD | CC==DD | missing(DD)
	replace DD=. if CC>DD | CC==DD | missing(CC)
	gen EE=DD-CC
	by pidp (Wave Spell), sort: egen FF=sum(EE) if Status==3
	by pidp (Wave Spell), sort: egen GG=sum(FF)
	gen HH=cond(GG>0 & !missing(GG),1,0)
	by pidp (Wave Spell), sort: egen II=sum(EE) if Status==.m
	by pidp (Wave Spell), sort: egen JJ=sum(II)
	
	foreach k in GG HH{
		local j=`j'+1
		if "`k'"=="GG" local if "& GG>0"
		else local if ""
		ttest `k' if Spell==1 & inrange(Age_Y,35,55) `if', by(LifeHist_Wave)
		replace Test="`k'" in `j'
		replace Lag=`i' in `j'
		replace Mean_1=r(mu_1) in `j'
		replace Mean_5=r(mu_2) in `j'
		replace Diff=Mean_1-Mean_5 in `j'
		replace PVal=r(p) in `j'
		}
	}
drop AA-JJ
sort Test Lag
keep if !missing(Test)

//	SCARRING
use "${dta_fld}/UKHLS Life History", clear
merge m:1 pidp using "Working Paper", /*
	*/ nogen keep(match) keepusing(pidp Min_IntDate_MY Birth_MY)

drop if Birth_MY+(22*12)>Min_IntDate_MY

prog_spellbounds Birth_MY+(18*12) Birth_MY+(22*12) Start_MY End_MY

levelsof Status, local(status) clean
foreach i of local status{
	gen XX=Interval if Status==`i'
	by pidp (Spell), sort: egen Status`i'_M=sum(XX)
	drop XX
	}
egen StatusM_M=rowtotal(Status*_M)
replace StatusM_M=48-StatusM_M

keep pidp Status*_M
duplicates drop
merge 1:1 pidp using "Working Paper", nogen keep(match)

ttest Age_Y, by(Treated)
ttest Status3_M, by(Treated)
ttest StatusM_M, by(Treated)	

merge 1:1 pidp using "${fld}/${ukhls_path}_w6/f_indresp${file_type}", /*
	*/ nogen keep(match) keepusing(f_sclfsato* f_scghq*dv f_ivfio)
keep if f_ivfio==1
gen Wave=24
merge 1:1 pidp Wave using "${dta_fld}/Interview Grid", /*
	*/ nogen keep(match) keepusing(IntDate_M IntDate_Y IntDate_MY)
rename IntDate* f_IntDate*

tab1 f_sclfsato f_scghq1_dv
replace f_sclfsato=.m if f_sclfsato<0
replace f_scghq1_dv=.m if f_scghq1_dv<0

reg f_scghq1_dv c.Status3_M##i.Treated
reg f_sclfsato c.Status3_M##i.Treated 

//	RECALL BIAS TESTS
	*	0. DESCRIPTIVE OF EXTRA RECALL TIME
	*	0. DESCRIPTIVES OF BALANCE IN COVARIANCE
	*	0. DESCRIPTIVES OF DIRECTION OF BIAS
	*	1. EMPLOYMENT STATUS AT MIN_INTDATE_MY
	*	2. LENGTH OF UNEMPLOYMENT AT MIN_INTDATE_MY
	*	4. TOTAL TIME UNEMPLOYED (COULD USE REGRESSION)
	*	5. TIME UNEMPLOYED DURING YOUTH
	* 	6. UNEMPLOYMENT AFTER LEAVING FULL TIME EDUCATION
	* 	7. UNEMPLOYMENT SPELL LENGTH AFTER LEAVING FTE
	*	8. RECALL BIAS AND TIME - SEE DIFFERENCE IN UNEMPLOYMENT LENGTH IN LAST THREE YEARS, INCREMENTING IN +1 YEARS.
	
//	EDUCATION TESTS
	* 	1. SHOW UNEMPLOYMENT NOT AS CORRELATED WITH WELLBEING WHEN IN FTE
	*	2. EXTENT OF OVERLAP BETWEEN JBSTAT AND EDUCATION HISTORY VARIABLES.
	
//	GENERAL DATA QUALITY
	*	0. CONCURRENCE BETWEEN DIFFERENT ELICITATION
	* 	1. SEAM EFFECTS IN THE UKHLS
	*	2. AMOUNT OF MISSING DATA PER PERSON AND AVERAGE LENGTH.
	*	3. CONCURRENCE BETWEEN S_ & F_ AND LH_ VARIABLES.
