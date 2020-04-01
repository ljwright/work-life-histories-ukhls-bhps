clear
cd "E:\UKHLS 1-9 and BHPS 1-18, Standard Licence\stata\stata11_se"
set linesize 180
set more off

global ukhls_stub	ukhls
global ukhls_waves	9
global ukhls_life	1 5


	* BHPS Main Activity and Current Employment Questions
tempfile Temp
forval i=1/18{
	local j: word `i' of `c(alpha)'
	use pidp b`j'_jbstat* b`j'_jbhas b`j'_jboff b`j'_jbsemp ///
		using "bhps_w`i'/b`j'_indresp_protect", clear
	gen Wave=`i'
	rename b`j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
}
replace jbstat=8 if jbstat_bh==7 & Wave==1
recode * (min/-1=.)
drop *_bh
numlabel, add
gen Employed=jbsemp
replace Employed=3 if jboff==2
replace Employed=4 if jboff==3
label define Employed 1 "Employee" 2 "Self-Employed" 3 "Not Employed" 4 "Waiting for Job"
label values Employed Employed

table jbstat Employed, missing


	* Main Activity and Current Education
tempfile Temp
forval i=1/18{
	local j: word `i' of `c(alpha)'
	if `i'>1	local eden b`j'_eden*
	use pidp b`j'_jbstat* b`j'_scnow b`j'_fenow_bh `eden' ///
		using "bhps_w`i'/b`j'_indresp_protect", clear
	gen Wave=`i'
	rename b`j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
}
replace jbstat=8 if jbstat_bh==7 & Wave==1
recode * (min/-1=.)
drop edenm* edeny* jbstatl jbstatt
numlabel, add

egen edenne=rowmax(edenne*)
gen edend=inlist(-3,edendm, edendy, edendy4)

table jbstat if scnow==1
table jbstat if fenow_bh==1
table jbstat if edend==1
table jbstat if edenne==1

	* bw_jbstat & bw_nemst
tempfile Temp
forval i=2/15{
	local j: word `i' of `c(alpha)'
	use pidp b`j'_jbstat b`j'_nemst ///
		using "bhps_w`i'/b`j'_indresp_protect", clear
	gen Wave=`i'
	rename b`j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
}
recode * (min/-1=.)
table jbstat nemst

	* bw_jbstat & bj_csstly
tempfile Temp
forval i=16/18{
	local j: word `i' of `c(alpha)'
	use pidp b`j'_jbstat b`j'_cjsstly b`j'_cjscjs ///
		using "bhps_w`i'/b`j'_indresp_protect", clear
	gen Wave=`i'
	rename b`j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
}
recode * (min/-1=.)
table jbstat cjsstly if cjscjs==1

	* bw_jbstat & bw_jhstat // NOT COMPLETE! NEED TO CHANGE CATEGORIES.
tempfile Temp
forval i=16/18{
	local j: word `i' of `c(alpha)'
	use pidp b`j'_jhstat b`j'_jhcjs b`j'_jspno ///
		using "bhps_w`i'/b`j'_jobhstd_protect" ///
		if b`j'_jhcjs==1, clear
	by pidp (b`j'_jspno), sort: keep if _n==1 	// MULTIPLE ENDED FOR SOME REASON - PICK FIRST ONE
	merge 1:1 pidp using "bhps_w`i'/b`j'_indresp_protect", ///
		keep(match) keepusing(b`j'_jbstat b`j'_jbsemp) nogen
	gen Wave=`i'
	rename b`j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
}
recode * (min/-1=.)
replace jhstat=1 if jbsemp==2 & inlist(jhstat,1,2) // NOT CORRECT!
replace jhstat=2 if jbsemp==1 & inlist(jhstat,1,2)
table jbstat jhstat, missing


	* bw_jbstat & bw_leshst
tempfile Temp
foreach i in 2 11 12 {
	local j: word `i' of `c(alpha)'
	use pidp b`j'_leshst b`j'_leshne ///
		using "bhps_w`i'/b`j'_lifemst_protect" ///
		if b`j'_leshne==1, clear
	merge 1:1 pidp using "bhps_w`i'/b`j'_indresp_protect", ///
		keep(match) keepusing(b`j'_jbstat) nogen
	gen Wave=`i'
	rename b`j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
}
recode * (min/-1=.)
table jbstat leshst

	* UKHLS Main Activity and Current Employment Questions
tempfile Temp
forval i=1/$ukhls_waves{
	local j: word `i' of `c(alpha)'
	use pidp `j'_jbstat `j'_jbhas `j'_jboff `j'_jbsemp ///
		using "${ukhls_stub}_w`i'/`j'_indresp", clear
	gen Wave=`i'
	rename `j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
}
recode * (min/-1=.)
numlabel, add
gen Employed=jbsemp
replace Employed=3 if jboff==2
replace Employed=4 if jboff==3
label define Employed 1 "Employee" 2 "Self-Employed" 3 "Not Employed" 4 "Waiting for Job"
label values Employed Employed

table jbstat Employed, missing

	* Main Activity and Current Education
tempfile Temp
forval i=1/$ukhls_waves{
	local j: word `i' of `c(alpha)'
	if `i'>1	local edhist `j'_contft `j'_ftedend*
	use pidp `j'_jbstat* `j'_school `j'_fenow `edhist' ///
		using "${ukhls_stub}_w`i'/`j'_indresp", clear
	gen Wave=`i'
	rename `j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
}
recode * (min/-1=.)
numlabel, add

table jbstat if school==3
table jbstat if fenow==3
table jbstat if inlist(1,contft,ftedend1, ftedend2, ftedend3, ftedend4)

	* jbstat and Annual History
tempfile Temp
forval i=2/$ukhls_waves{
	local j: word `i' of `c(alpha)'
	use pidp *jbstat `j'_ff_emplw `j'_*empchk `j'_nxtst `j'_nxtstelse ///
		`j'_cstat `j'_cjob `j'_*jbsemp `j'_nextstat* `j'_nextjob* ///
		`j'_currjob* `j'_nextelse* `j'_currstat* using ///
		"${ukhls_stub}_w`i'/`j'_indresp", clear
	gen Wave=`i'
	rename `j'_* *
	capture append using "`Temp'"
	save "`Temp'", replace
	}
recode * (min/-1 = .)
gen Current = .
forval i=1/10{
	replace Current = 1 if currjob`i'==1 & nextjob`i'==3
	replace Current = 2 if currjob`i'==1 & inlist(nextjob`i', 1, 2, 4)
	replace Current = nextelse`i'+2 if currstat`i'==2 & inrange(nextelse`i', 1, 7)
	replace Current = 97 if currstat`i'==2 & nextelse`i'==8
}	
replace Current = ff_jbstat if notempchk==1 & inrange(ff_jbstat, 1, 97)
replace Current = ff_jbstat if empchk==1 & inlist(ff_jbstat, 1, 2)
replace Current = 3-ff_jbsemp if empchk==1 & inrange(ff_jbstat, 3, 97) & inlist(ff_jbsemp, 1, 2)
replace Current = nxtstelse+2 if cstat==2 & inrange(nxtstelse, 1, 7)
replace Current = 97 if cstat==2 & nxtstelse==8
replace Current = 3-jbsemp if cjob==1 & inrange(jbsemp, 1, 2)

gen jbstat_no = jbstat
table jbstat_no Current, missing

	* Employment Status History
tempfile Temp Temp2
foreach i in $ukhls_life {
	local j: word `i' of `c(alpha)'
	use pidp `j'_leshst `j'_spellno ///
		using "${ukhls_stub}_w`i'/`j'_empstat", clear
	by pidp (`j'_spellno), sort: keep if `j'_leshst[_n+1]==0
	save "`Temp'", replace
	use pidp `j'_jbstat ///
		using "${ukhls_stub}_w`i'/`j'_indresp", clear
	merge 1:1 pidp using "`Temp'", nogen keep(match)
	gen Wave=`i'
	rename `j'_* *
	capture append using "`Temp2'"
	save "`Temp2'", replace
}
recode * (min/-1=.)
table jbstat leshst, missing