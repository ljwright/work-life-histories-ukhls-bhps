/*
********************************************************************************
MERGE DATASETS.DO
	
	MERGES THE VARIOUS CLEANED FILS TOGETHER. PRECEDENCE IS EDUCATION>ANNUAL>
	LIFE, WITH BHPS TAKING PRECEDENCE OVER UKHLS AS COLLECTED MORE PROXIMATELY
	TO SPELL.	

********************************************************************************
*/

/*
1. Merge datasets together.
*/
/**/
qui{
local j=0
foreach i in Education Annual Life{
	local j=`j'+1
	local files: dir "${dta_fld}" files "*`i' History.dta", respectcase
	local k=0
	foreach file of local files{
		local k=`k'+1
		if `k'==1	use "${dta_fld}/`file'", clear
		else		append using "${dta_fld}/`file'"
		}
	prog_waveoverlap
	prog_collapsespells
	tempfile Merge`j'
	save "`Merge`j''", replace
	}
forval mrg=4/5{
	local tmp=0

	if `mrg'==4{
		use "`Merge1'", clear
		append using "`Merge2'", gen(Dataset)
		di in red ""
		di in red "Merging Education and Annual Histories"
		}
	if `mrg'==5{
		use "`Merge4'", clear
		append using "`Merge3'", gen(Dataset)
		di in red ""
		di in red "Merging with Life Histories"
		}		
	
	local l=cond(`mrg'==0,9,7+`mrg')
	
	drop if Status==.m
	capture drop Wave
	by pidp (Start_MY End_MY Dataset Spell), sort: replace Spell=_n	
	
	local overlap "(inrange(F_Overlap,1,4) & Dataset==1 & F_Dataset==0) | (inrange(L_Overlap,1,4) & Dataset==1 & L_Dataset==0)"

	prog_overlap
	count if `overlap'
	local i=`r(N)'
	if `i'>0{					
		by pidp (Spell), sort: egen Overlap=max(`overlap')
		preserve
			drop if Overlap==1
			drop Overlap F_* L_*
			local tmp=`tmp'+1
			tempfile Temp`tmp'
			save "`Temp`tmp''", replace
		restore		
		keep if Overlap==1
		drop Overlap
		}
	local j=0
	di in red "     Iteration `j'"
	di in red "          `i' spells with overlaps remaining"
	drop F_* L_*
	
	while `i'>0{
		local j=`j'+1
		di in red "     Iteration `j'"
		foreach k in F L{
			prog_overlap
			
			drop if `k'_Overlap==1 & Dataset==1 & `k'_Dataset==0

			expand 2 if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0, gen(XX)
			replace End_MY=`k'_Start_MY if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==0
			replace End_Flag=`l' if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==0
			replace Start_MY=`k'_End_MY if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==1
			replace Start_Flag=`l' if `k'_Overlap==2 & Dataset==1 & `k'_Dataset==0 & XX==1
			drop XX

			replace End_MY=`k'_Start_MY if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0
			replace End_Flag=`l' if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0
			
			replace Start_MY=`k'_End_MY if `k'_Overlap==4 & Dataset==1 & `k'_Dataset==0
			replace Start_Flag=`l' if `k'_Overlap==3 & Dataset==1 & `k'_Dataset==0

			by pidp (Start_MY End_MY Dataset Spell), sort: replace Spell=_n
			drop F_* L_*
			}			
		
		prog_overlap
		count if `overlap'
		local i=`r(N)'
		if `i'>0{					
			by pidp (Spell), sort: egen Overlap=max(`overlap')
			preserve
				drop if Overlap==1
				drop Overlap F_* L_*
				local tmp=`tmp'+1
				tempfile Temp`tmp'
				save "`Temp`tmp''", replace
			restore		
			keep if Overlap==1
			drop Overlap
			}
		di in red "          `i' spells with overlaps remaining"
		drop F_* L_*
		}
	
	forval i=1/`tmp'{
		append using "`Temp`i''"
		}
	drop Dataset
	tempfile Merge`mrg'
	save "`Merge`mrg''", replace
	}
	

replace Job_Hours=.m if Job_Hours==. & inlist(Status,1,2,100)
replace Job_Hours=.i if Job_Hours==. & !inlist(Status,1,2,100)
sort pidp Spell
compress
save "${dta_fld}/Merged Dataset - Raw", replace
}
*/


/**/
qui{
prog_reopenfile "${dta_fld}/Merged Dataset - Raw"
merge m:1 pidp using "${dta_fld}/Left Full Time Education", gen(fte_merge)	
preserve
	use "${dta_fld}/Interview Grid", clear
	gen XX=IntDate_MY if ivfio!=2
	by pidp (Wave), sort: egen Last_IntDate_MY=max(XX)
	keep pidp Last_IntDate_MY
	duplicates drop
	drop if missing(Last_IntDate_MY)
	tempfile Temp
	save "`Temp'", replace
restore	
merge m:1 pidp using "`Temp'", keep(match using) gen(int_merge)
format *MY %tm	
order pidp Spell Start_MY End_MY Status Start_Flag End_Flag Source
noisily table Start_Flag End_Flag, missing	

prog_overwritespell /*
	*/ "fte_merge==2 | int_merge==2" 1 Birth_MY Last_IntDate_MY 0 1 `""Gap""' .m
drop fte_merge int_merge

by pidp (Spell), sort: gen XX=1 if _n==_N & End_MY<Last_IntDate_MY
expand 2 if XX==1, gen(YY)
prog_overwritespell /*
	*/ "YY==1" Spell+1 End_MY Last_IntDate_MY End_Flag 1 `""Gap""' .m
drop XX YY

prog_imputemissingspells
gen XX=(Birth_MY<Start_MY & Spell==1)
expand 2 if XX==1, gen(YY)
prog_overwritespell /*
	*/ "YY==1" 0 Birth_MY Start_MY 0 Start_Flag  `""Gap""' .m
drop XX YY

by pidp (Start_MY End_MY Spell), sort: replace Spell=_n
drop FTE_Source
gen FTE_MY=	cond(!missing(FTE_FIN_MY),FTE_FIN_MY, FTE_IN_MY)
gen FTE_Source=	cond(!missing(FTE_FIN_MY),"FTE_FIN: "+FTE_FIN_Source, /*
			*/	cond(!missing(FTE_IN_MY),"FTE_IN: "+FTE_IN_Source,""))

expand 2 if Spell==1 & !missing(FTE_MY), gen(XX)
prog_overwritespell /*
	*/ "XX==1" 0 Birth_MY FTE_MY 0 13  FTE_Source 7
drop if Start_MY==End_MY
by pidp (Spell), sort: egen YY=max(XX)
replace Start_MY=FTE_MY if Start_MY<FTE_MY & YY==1 & XX!=1
drop if Start_MY>=End_MY
by pidp (Start_MY End_MY), sort: replace Spell=_n
drop XX YY FTE*

by pidp (Spell), sort: gen XX=1 if Status==7 & Spell==2 /*
	*/ & floor((Start_MY-Birth_MY)/12)<=19 & Status[_n-1]==.m
replace Start_MY=Birth_MY if XX==1
replace Start_Flag=0 if XX==1
by pidp (Spell), sort: drop if XX[_n+1]==1
drop XX	

by pidp (Spell), sort: gen XX=1 if Spell==1 & End_MY-Start_MY==1 /*
*/ & Start_MY==Birth_MY & Status[_n+1]==.m
by pidp (Spell), sort: replace Start_MY=Start_MY-1 if XX[_n-1]==1
drop if XX==1
drop XX

prog_imputemissingspells

gen Source_Type=0
replace Source_Type=1 if strpos(Source,"indresp")>0 | strpos(Source,"jobhist")>0
replace Source_Type=2 if strpos(Source,"eduhist")>0
replace Source_Type=3 if strpos(Source,"LH")>0
replace Source_Type=3 if strpos(Source,"lifehist")>0
replace Source_Type=4 if strpos(Source,"FTE_")>0 & strpos(Source,"LH")==0
label values Source_Type source_type

do "${do_fld}/Labels.do"
ds pidp Source*, not
format `r(varlist)' %9.0g
format *MY %tm
format Source Source_Variable %10s
order pidp Spell Start_MY End_MY Status *Flag Birth_MY IntDate_MY /*
	*/ Job_Hours Job_Change End_Ind Status_Spells Last_IntDate_MY /*
	*/ End_Reason* Job_Attraction* Source*
// END_IND & STATUS SPELLS NEEDS SORTING!!

compress
label data "Activity Histories, BHPS and UKHLS"
save "${dta_fld}/Merged Dataset", replace
// rm "${dta_fld}/Merged Dataset - Raw.dta"
}
*/
