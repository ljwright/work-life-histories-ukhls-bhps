capture program drop prog_recodemissing
program prog_recodemissing
	syntax varlist
	qui{
	foreach var of varlist `varlist'{
		if strpos("`var'","_MY")==0 {
			local lbl: value label `var'
			if "`lbl'"!=""{
				capture numlabel `lbl', add
				capture label define `lbl' .m ".m. Missing/Refused/Don't Know" /*
					*/ .i ".i. IEMB/Innapplicable/Proxy", add
				}
			capture confirm string variable `var'
			if _rc>0{
				replace `var'=.m if inlist(`var',-20,-9,-2,-1)
				replace `var'=.i if inlist(`var',-10,-8,-7)
				}
			}
		}
	}
end

capture program drop prog_reopenfile
program prog_reopenfile
	args filename
	if "`c(filename)'"!="`filename'" | `c(changed)'==1{
		use "`filename'", clear
		}
end

capture program drop prog_labels
program prog_labels
	qui do "${do_fld}/Labels.do"
	qui do "${do_fld}/Apply Labels.do"
end

capture program drop prog_missingdate
program prog_missingdate
	syntax namelist
	foreach var in `namelist'{
		if "`var'"!="Start" & "`var'"!="End"{
			di in red "Invalid: possible parameters 'Start' or 'End'"
			continue, break
			}
		
		capture drop Missing_`var'Date
		gen Missing_`var'Date=0 if !missing(`var'_MY)		
		capture confirm variable `var'_SY
		if _rc==0{
			replace Missing_`var'Date=1 if /*
				*/ !missing(`var'_Y) & !missing(`var'_SY) & missing(`var'_MY)
			replace Missing_`var'Date=2 if /*
				*/ !missing(`var'_Y) & missing(`var'_SY) & missing(`var'_MY)
			replace Missing_`var'Date=3 if /*
				*/ missing(`var'_Y) & missing(`var'_SY) & missing(`var'_MY)
			}
		else{
			replace Missing_`var'Date=2 if /*
				*/ !missing(`var'_Y) & missing(`var'_MY)
			replace Missing_`var'Date=3 if /*
				*/ missing(`var'_Y) & missing(`var'_MY)
			}			
		}
end

capture program drop prog_statusspells
program prog_statusspells
	syntax varlist
	local i ""
	foreach var of varlist `varlist' {
		local i "`i' | `var'!=`var'[_n-1]"
		}
	local i=subinstr("`i'"," | ","",1)
	capture drop Status_Spell*
	by pidp Wave (Spell), sort: gen XX=(`i')
	by pidp Wave (Spell), sort: gen YY=sum(XX)
	by pidp Wave (YY Spell), sort: gen ZZ=1 if /*
			*/ YY!=YY[_n-1] | !missing(Start_Y)
	by pidp Wave (Spell), sort: gen Status_Spell=sum(ZZ)
	by pidp Wave Status_Spell (Spell), sort: gen Status_Spells=_N
	drop XX YY ZZ
end

capture program drop prog_afterint
program prog_afterint
	args xx
	gen XX=.
	foreach i in Y SY MY{
		replace XX=Spell if IntDate_`i'<`xx'_`i' & !missing(IntDate_`i', `xx'_`i')
		}
	by pidp Wave (Spell), sort: egen YY=min(XX)
	drop if Spell>=YY & !missing(YY)
	by pidp Wave (Spell), sort: replace End_Ind=End_Type if _n==_N
	drop XX YY
end

capture program drop prog_assignwinter
program prog_assignwinter
	gen Reverse=-Spell
	by pidp Wave Start_Y (Spell), sort: gen XX=Start_SY[_n-1]
	by pidp Wave Start_Y (Spell), sort: replace XX=XX[_n-1] if missing(XX)
	by pidp Wave Start_Y (Reverse), sort: gen YY=Start_SY[_n-1]
	by pidp Wave Start_Y (Reverse), sort: replace YY=YY[_n-1] if missing(YY)
	replace YY=month(dofm(IntDate_SY)) if Start_Y==IntDate_Y & missing(YY)
	replace Start_SY=ym(Start_Y,5) if Winter==1 & /*
		*/ !missing(XX) & missing(YY)
	replace Start_SY=ym(Start_Y,1) if Winter==1 & /*
		*/ missing(XX) & !missing(YY)
	drop XX YY Winter Reverse
end

capture program drop prog_implausibledates
program prog_implausibledates
	args xx
	gen XX=cond(`xx'_Y-Birth_Y<0 & !missing(`xx'_Y, Birth_Y),1,0)
	replace XX=1 if `xx'_Y-Birth_Y<12 & !missing(`xx'_Y, Birth_Y) & Status!=7
	count if XX==1
	di in red "`r(N)' cases of implausible start dates (earlier than birth or none education statuses before 12th year). Drop history where implausible"
	by pidp Wave (Spell), sort: egen YY=max(XX)
	drop if YY==1
	drop XX YY	
end

capture program drop prog_nonchron
program prog_nonchron
	syntax namelist
	local i: word 1 of `namelist'
	local namelist: list namelist - i
	if strpos("`namelist'","SY")>0{
		local k="`i'_S" 
		}
	else{
		local k ""
		}
	
	if "`i'"!="Start" & "`i'"!="End"{
		di in red "Need to specify Start or End dates on which to base NonChron"
		STOP
		}
	
	capture drop XX
	gen XX=0
	foreach j in `namelist'{
		gen YY=cond(missing(`i'_`j'),1,0)
		by pidp Wave YY (Spell), sort: replace XX=1 if /*
			*/ `i'_`j'>`i'_`j'[_n+1] & !missing(`i'_`j', `i'_`j'[_n+1])
		drop YY
		}
	by pidp Wave (Spell), sort: egen NonChron_Wave=max(XX)
	drop XX	
	
	by pidp Wave (Spell), sort: egen XX=max(missing(`i'_Y))
	drop if NonChron_Wave==1 & XX==1
	drop XX
	
	if strpos("`namelist'","SY")>0{
		gen XX=(missing(`i'_SY))
		by pidp Wave `i'_Y (`i'_SY `i'_MY), sort: egen YY=total(XX)
		by pidp Wave `i'_Y (`i'_SY `i'_MY), sort: gen ZZ=_N
		by pidp Wave (`i'_Y `i'_SY `i'_MY), sort: egen AA=max(NonChron_Wave==1 & YY>=1 & ZZ>=2)
		drop if AA==1
		drop XX YY ZZ AA 
		
		gen XX=(missing(`i'_MY))
		by pidp Wave `i'_Y `i'_SY (`i'_MY), sort: egen YY=total(XX)
		by pidp Wave `i'_Y `i'_SY (`i'_MY), sort: gen ZZ=_N
		by pidp Wave (`i'_Y `i'_SY `i'_MY), sort: egen AA=max(NonChron_Wave==1 & YY>=1 & ZZ>=2)
		drop if AA==1
		drop XX YY ZZ AA 
		}
	else{
		gen XX=(missing(`i'_MY))
		by pidp Wave `i'_Y (`i'_MY), sort: egen YY=total(XX)
		by pidp Wave `i'_Y(`i'_MY), sort: gen ZZ=_N
		by pidp Wave (`i'_Y `i'_MY), sort: egen AA=max(NonChron_Wave==1 & YY>=1 & ZZ>=2)
		drop if AA==1
		drop XX YY ZZ AA
		}
	
	drop if NonChron==1 & End_Type==.m
end

// capture program drop prog_daterange_OLD
// program prog_daterange_OLD
// 	syntax namelist
// 	qui{
// 	by pidp Wave (Spell), sort: gen N=_N
// 	sum N
// 	local i=`r(max)'-1
// 	drop N
// 	capture drop MaxBelow MinAbove
// 	foreach j in `namelist'{
// 		capture gen MaxBelow=Start_`j'
// 		capture gen MaxBelow=End_`j'
// 		capture gen MinAbove=End_`j'
// 		capture gen MinAbove=Start_`j'
// 		forval k=1/`i'{
// 			capture by pidp Wave (Spell) , sort: replace MaxBelow=End_`j'[_n-`k'] /*
// 				*/ if missing(MaxBelow)	 & !missing(End_`j'[_n-`k'])	
// 			capture by pidp Wave (Spell) , sort: replace MaxBelow=Start_`j'[_n-`k'] /*
// 				*/ if missing(MaxBelow) & !missing(Start_`j'[_n-`k'])
// 			capture by pidp Wave (Spell) , sort: replace MinAbove=Start_`j'[_n+`k'] /*
// 				*/ if missing(MinAbove) & !missing(Start_`j'[_n+`k'])
// 			capture by pidp Wave (Spell) , sort: replace MinAbove=End_`j'[_n+`k'] /*
// 				*/ if missing(MinAbove) & !missing(End_`j'[_n+`k'])
// 			}		
// 		capture replace MinAbove=IntDate_`j' if missing(MinAbove)				
// 		}
// 	}
// end

capture program drop prog_daterange
program prog_daterange
	args j
	qui{
	gen Reverse=-Spell
	foreach i in Start End{	
		tempvar `i'
		capture confirm variable `i'_`j'
		if _rc==0 	gen ``i''=`i'_`j'
		else		gen ``i''=.
		}
	foreach i in MaxBelow MinAbove{
		if "`i'"=="MaxBelow"{
			local sort "Spell"
			local function "max"
			capture gen `i'=Start_`j'
			capture gen `i'=End_`j'
			}
		else{
			local sort "Reverse"
			local function "min"
			capture gen `i'=End_`j'
			capture gen `i'=Start_`j'
			}
		tempvar XX
		gen `XX'=`function'(`Start',`End')
		by pidp Wave (`sort'), sort: replace `i'=`XX'[_n-1] /*
			*/ if missing(`i')
		by pidp Wave (`sort'), sort: replace `i'=`i'[_n-1] /*
			*/ if missing(`i')
		drop `XX'
		}
	drop `Start' `End' Reverse
	capture replace MinAbove=IntDate_`j' if missing(MinAbove)
	sort pidp Wave Spell
	}
end

capture program drop prog_imputeequaldates
program prog_imputeequaldates
	syntax namelist
	foreach n in `namelist'{
		prog_daterange `n'
		capture replace Start_`n'=MaxBelow if /*
			*/ MaxBelow==MinAbove & missing(Start_`n') & !missing(MaxBelow,MinAbove)
		capture replace End_`n'=MinAbove if /*
			*/ MaxBelow==MinAbove & missing(End_`n') & !missing(MaxBelow,MinAbove)
		drop MaxBelow MinAbove
		}
end

capture program drop prog_mytosytoy
program prog_mytosytoy
	syntax namelist
	qui{
		foreach n in `namelist'{
			replace `n'_Y=year(dofm(`n'_MY)) if missing(`n'_Y) & !missing(`n'_MY)
			capture confirm variable `n'_SY
			if _rc==0{
				replace `n'_SY=ym(year(dofm(`n'_MY)),		cond(inrange(month(dofm(`n'_MY)),1,2),1, /*
													*/		cond(inrange(month(dofm(`n'_MY)),3,5),2, /*
													*/		cond(inrange(month(dofm(`n'_MY)),6,8),3, /*
													*/		cond(inrange(month(dofm(`n'_MY)),9,11),4,5))))) /*
						*/ if missing(`n'_SY) & !missing(`n'_MY)
				replace `n'_Y=year(dofm(`n'_SY)) if missing(`n'_Y) & !missing(`n'_SY)
				replace `n'_MY=ym(`n'_Y,12) if !missing(`n'_Y) & missing(`n'_MY) & month(dofm(`n'_SY))==5
				}
			}
		}
end		

capture program drop prog_lastspellmissing 
program prog_lastspellmissing
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogen keep(match master) keepusing(jbstat Next_ff_jbstat Job_Hours_IG)
	by pidp Wave (Spell), sort: gen XX=1 if _n==_N & End_Type==.m & End_MY<IntDate_MY
	expand 2 if XX==1 & !missing(jbstat), gen(YY)
	replace Spell=Spell+1 if YY==1
	by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY-1 if /*
		*/ YY==1 & End_MY[_n-1]<IntDate_MY
	by pidp Wave (Spell), sort: replace Start_MY=IntDate_MY if /*
		*/ YY==1 & End_MY[_n-1]==IntDate_MY
	replace End_MY=IntDate_MY if YY==1
	replace Start_Flag=5 if YY==1
	replace End_Flag=1 if YY==1
	replace Status=Next_ff_jbstat if YY==1 & !missing(Next_ff_jbstat)
	replace Status=jbstat if YY==1 & missing(Next_ff_jbstat) & !missing(jbstat)
	replace Status=.m if YY==1 & missing(Next_ff_jbstat) & missing(jbstat)
	replace Job_Hours=Job_Hours_IG if YY==1 & !missing(Job_Hours_IG) & inlist(Status,1,2)
	replace Job_Hours=.m if YY==1 & missing(Job_Hours_IG) & inlist(Status,1,2)
	replace Job_Hours=.i if YY==1 & !inlist(Status,1,2,100)
	replace Job_Change=.i if YY==1 & !inlist(Status,1,2,100)
	replace Job_Change=.m if YY==1 & inlist(Status,1,2,100)
	replace Status_Spells=1 if YY==1
	capture replace Job_Attraction=.m if YY==1
	capture confirm variable End_Reasons_1
	if _rc==0{
		replace End_Reasons_1="0 0 0 0 0 0 0 0 0 0 0 0" if YY==1 
		replace End_Reasons_i="1 1 1 1 1 1 1 1 1 1 1 1" if YY==1
		replace End_Reasons_m="0 0 0 0 0 0 0 0 0 0 0 0" if YY==1
		}
	capture replace Source_Variable="jbstat_w"+strofreal(Wave) if YY==1
	drop if YY==1 & Status==.m
	drop jbstat Job_Hours_IG Next_ff_jbstat XX YY
end

capture program drop prog_imputemissingspells 	
program prog_imputemissingspells
	capture confirm variable Wave
	if _rc==0{
		local i="Wave"
		capture by pidp `i' (Spell), sort: gen XX=cond(_n==_N & End_MY<IntDate_MY,1,0)
		}
	else{
		local i=""
		gen XX=.
		}
	by pidp (`i' Spell), sort: gen YY=cond(End_MY<Start_MY[_n+1] & _n<_N,1,0)
	
	expand 2 if XX==1 | YY==1, gen(ZZ)
	by pidp (`i' Spell ZZ), sort: replace Spell=_n
	capture by pidp (`i' Spell ZZ), sort: replace IntDate_MY=IntDate_MY[_n+1] if ZZ==1 & _n<_N
	capture by pidp (`i' Spell ZZ), sort: replace Wave=Wave[_n+1] if ZZ==1 & _n<_N
	replace Status=.m if ZZ==1
	replace Job_Hours=.m if ZZ==1

	capture confirm variable End_Reason1
	if _rc==0{
		foreach var of varlist End_Reason* Job_Attraction* {
			replace `var'=.i if ZZ==1
			}
		}
	capture replace Source_Variable=".m" if ZZ==1
	capture replace Source="Gap" if ZZ==1
	replace Start_MY=End_MY if ZZ==1
	by pidp (`i' Spell), sort: replace End_MY=Start_MY[_n+1] if ZZ==1 & _n<_N
	capture by pidp (`i' Spell), sort: replace End_MY=IntDate_MY if ZZ==1 & _n==_N
	by pidp (`i' Spell), sort: replace Start_Flag=End_Flag[_n-1] if ZZ==1 & _n>1
	by pidp (`i' Spell), sort: replace End_Flag=Start_Flag[_n+1] if ZZ==1 & _n<_N
	by pidp (`i' Spell), sort: replace End_Flag=1 if ZZ==1 & _n==_N
	drop XX YY ZZ
end	

capture program drop prog_checkoverlap 											
program prog_checkoverlap
	prog_daterange MY
	count if Start_MY>End_MY & !missing(Start_MY,End_MY)
	local i=`r(N)'
	count if floor(End_MY)>IntDate_MY & !missing(End_MY)
	local j=`r(N)'
	count if End_MY>MinAbove & !missing(MinAbove) & !missing(End_MY)
	local k=`r(N)'
	count if Start_MY<MaxBelow & !missing(MaxBelow) & !missing(Start_MY)
	local l=`r(N)'
	if `i'!=0 | `j'!=0 | `k'!=0 | `l'!=0{
		di in red "There are multiple cases of overlap. This should not be the case."
		STOP
		}
	drop MaxBelow MinAbove
end

capture program drop prog_overlap
program prog_overlap
	capture drop F_* 
	capture drop L_*
	qui{
		gen F_Overlap=0
		by pidp (Spell), sort: replace F_Overlap=1 if _n<_N & Start_MY>=Start_MY[_n+1] & End_MY<=End_MY[_n+1]
		by pidp (Spell), sort: replace F_Overlap=2 if _n<_N & Start_MY<Start_MY[_n+1] & End_MY>End_MY[_n+1]
		by pidp (Spell), sort: replace F_Overlap=3 if _n<_N & Start_MY<Start_MY[_n+1] & End_MY<=End_MY[_n+1] & End_MY>Start_MY[_n+1]
		by pidp (Spell), sort: replace F_Overlap=4 if _n<_N & Start_MY>=Start_MY[_n+1] & End_MY>End_MY[_n+1] & Start_MY<End_MY[_n+1]
		noisily tab1 F_Overlap, missing
		by pidp (Spell), sort: gen F_Start_MY=cond(_n<_N,Start_MY[_n+1],.i)
		by pidp (Spell), sort: gen F_End_MY=cond(_n<_N,End_MY[_n+1],.i)
		by pidp (Spell), sort: gen F_Dataset=cond(_n<_N,Dataset[_n+1],.i)
		label values Dataset dataset
		noisily by F_Overlap, sort: tab2 Dataset F_Dataset, missing
		
		gen L_Overlap=0
		by pidp (Spell), sort: replace L_Overlap=1 if _n>1 & Start_MY>=Start_MY[_n-1] & End_MY<=End_MY[_n-1]
		by pidp (Spell), sort: replace L_Overlap=2 if _n>1 & Start_MY<Start_MY[_n-1] & End_MY>End_MY[_n-1]
		by pidp (Spell), sort: replace L_Overlap=3 if _n>1 & Start_MY<Start_MY[_n-1] & End_MY<=End_MY[_n-1] & End_MY>Start_MY[_n-1]
		by pidp (Spell), sort: replace L_Overlap=4 if _n>1 & Start_MY>=Start_MY[_n-1] & End_MY>End_MY[_n-1] & Start_MY<End_MY[_n-1]
		noisily tab1 L_Overlap, missing
		by pidp (Spell), sort: gen L_Start_MY=cond(_n>1,Start_MY[_n-1],.i)
		by pidp (Spell), sort: gen L_End_MY=cond(_n>1,End_MY[_n-1],.i)
		by pidp (Spell), sort: gen L_Dataset=cond(_n>1,Dataset[_n-1],.i)
		label values Dataset dataset
		noisily by L_Overlap, sort: tab2 Dataset L_Dataset, missing
		
		count if (inrange(F_Overlap,1,4) & Dataset==F_Dataset) | (inrange(L_Overlap,1,4) & Dataset==L_Dataset)
		if `r(N)'>0{
			di in red "`r(N)' case where overlaps between spells are from same datasets. Should be zero"
			STOP
			}
		}
end

// capture program drop prog_eduoverlap
// program prog_eduoverlap
// 	by pidp Wave (Start_MY End_MY), sort: replace Spell=_n
// 	by pidp (Start_MY End_MY Wave Spell), sort: gen YY=_N
// 	sum YY
// 	local j=`r(max)'
// 	forval i=1/`j'{
// 		by pidp (Start_MY End_MY Wave Spell), sort: gen XX=1 /*
// 			*/ if End_MY>=Start_MY[_n+1] & _n<_N
// 		foreach var of varlist Source*{
// 		di "`var'"
// 			by pidp (Start_MY End_MY Wave Spell), sort: /*
// 				*/ replace `var'=`var'+"; "+`var'[_n+1] /*
// 				*/ if XX==1 & End_MY<=End_MY[_n+1] & strpos(`var'[_n+1],`var')==0
// 			}
// 		by pidp (Start_MY End_MY Wave Spell), sort: replace End_Flag=End_Flag[_n+1] /*
// 			*/ if XX==1 & End_MY<=End_MY[_n+1] 
// 		by pidp (Start_MY End_MY Wave Spell), sort: replace End_MY=End_MY[_n+1] /*
// 			*/ if XX==1 & End_MY<=End_MY[_n+1] 
// 		by pidp (Start_MY End_MY Wave Spell), sort: replace IntDate_MY=IntDate_MY[_n+1] /*
// 			*/ if XX==1 & End_MY<=End_MY[_n+1] &  IntDate_MY<IntDate_MY[_n+1]
// 		by pidp (Start_MY End_MY Wave Spell), sort: gen ZZ=1 /*
// 			*/ if XX[_n-1]==1
// 		by pidp (Start_MY End_MY Wave Spell), sort: replace ZZ=2 /*
// 			*/ if XX[_n-1]==1 & End_MY<End_MY[_n-1]
// 		drop if ZZ==2
// 		if `i'==`j'{
// 			drop if ZZ==1
// 			}
// 		drop XX ZZ
// 		}
// 	drop YY	
// 	by pidp (Start_MY End_MY Wave Spell), sort: replace Spell=_n
//	
// end

capture program drop prog_getvars
program define prog_getvars
	args macro prefix file
	quietly describe using "`file'", varlist
	local varlist `r(varlist)'
	foreach v of global `macro'{
		local prefixlist "`prefixlist' `prefix'_`v' "
		}
	foreach v1 of local prefixlist{
		foreach v2 of local varlist{
			if "`v1'"=="`v2'"{
				local inlist "`inlist' `v1'"	
				}
			}
		}
	use pidp `inlist' using "`file'", clear
end

// capture program drop prog_waveoverlap
// program define prog_waveoverlap
// 	drop if Status==.m
// 	by pidp (Wave Spell), sort: gen XX=_n
// 	gen YY=.
// 	qui sum XX
// 	forval i=1/`r(max)'{
// 		by pidp (Wave Spell), sort: replace Start_Flag=1 if Start_MY<End_MY[_n-1] & _n>1
// 		by pidp (Wave Spell), sort: replace Start_MY=End_MY[_n-1] if Start_MY<End_MY[_n-1] & _n>1
// 		drop if Start_MY>=End_MY
// 		if `r(N_drop)'==0{
// 			continue, break
// 			}
// 		}		
// 	drop if Start_MY==End_MY
// 	by pidp (Wave Spell), sort: replace Spell=_n
// 	drop XX YY
// end

capture program drop prog_waveoverlap
program define prog_waveoverlap
	drop if Status==.m
	capture gen Wave=1
	if _rc==0 local drop "Wave"
	capture drop Spell
	by pidp (Start_MY End_MY), sort: gen Spell=_n
	by pidp (Wave Spell), sort: gen XX=max(Start_MY,End_MY[_n-1])
	by pidp (Wave Spell), sort: replace XX=XX[_n-1] if XX<XX[_n-1] & _n>1
	replace Start_MY=XX if XX>Start_MY
	drop if Start_MY>=End_MY
	by pidp (Start_MY End_MY), sort: replace Spell=_n
	drop XX `drop'
end

capture program drop prog_collapsespells
program prog_collapsespells
	by pidp (Spell), sort: replace Job_Change=3 /*
		*/ if _n>1 & inlist(Status,1,2,100) & !inlist(Status[_n-1],1,2,100) /*
		*/ & Start_MY==End_MY[_n-1]
	by pidp (Spell), sort: replace Job_Change=3 /*
		*/ if inlist(Status[_n+1],1,2) & inlist(Status,1,2) & Status!=Status[_n+1]
	by pidp (Spell), sort: replace Status=Status[_n+1] /*
		*/ if Status==100 & inlist(Status[_n+1],1,2) & inlist(Job_Change[_n+1],0,2)
	by pidp (Spell), sort: replace Status=Status[_n-1] /*
		*/ if Status==100 & inlist(Status[_n-1],1,2) & inlist(Job_Change,0,2)

	gen Reverse=-Spell
	by pidp (Spell), sort: gen XX=1 /*
		*/ if Status==Status[_n+1] & Job_Hours==Job_Hours[_n+1] /*
		*/ & End_MY>=Start_MY[_n+1] & (inlist(Job_Change[_n+1],.i,0) | /*
		*/ (Job_Change==Job_Change[_n+1] & inlist(Job_Change,.m,4)) | /*
		*/ (Job_Change[_n+1]==.m & End_Ind==0)) 
	by pidp (Reverse), sort: replace XX=0 if XX[_n+1]==1
	replace XX=1 if XX==.

	by pidp (Spell), sort: gen YY=sum(XX)
	capture gen Wave=1
	if _rc==0 local Wave "Wave"
	foreach var of varlist End_Ind End_Flag End_MY `Wave' IntDate_MY{
		by pidp YY (Spell), sort: replace `var'=`var'[_N]
		}
	foreach var of varlist Source*{
		by pidp YY (Reverse), sort: /*
			*/ replace `var'=`var'+"; "+`var'[_n-1] /*
			*/ if _n>1 & strpos(`var'[_n-1],`var')==0
			}
	by pidp YY (Spell), sort: keep if _n==1
	
	sort pidp Spell
	order Source*, last
	format Source* %10s
	drop XX YY Reverse `Wave'
	by pidp (Spell), sort: replace Spell=_n
end

capture program drop prog_sort
program define prog_sort
	order pidp Wave *MY
	format *MY %tm
end

capture program drop prog_makeage
program define prog_makeage
	syntax varlist
	foreach var of varlist `varlist'{			
		capture drop `var'_Age
		gen `var'_Age=floor((`var'-Birth_MY)/12)
		label variable `var'_Age "Age(`var')"
		di char(10) "`var'_Age"
		tab `var'_Age
		}
end

capture program drop prog_sumedu
program define prog_sumedu
	qui{
	cls
	args var
	count if tag==1
	local N=`r(N)'
	
	gen AA=`var' if inlist(ivfio,1,3) 
	gen BB=floor((AA-Birth_MY)/12)
	gen CC=(!missing(BB))
	by pidp (Wave), sort: egen DD=sum(CC)
	by pidp CC (Wave), sort: gen EE=AA if CC==1 & _n==1
	by pidp CC (Wave), sort: gen FF=BB if CC==1 & _n==1
	by pidp (Wave), sort: egen GG=max(EE)
	by pidp (Wave), sort: egen HH=max(FF)
	gen II=floor((AA-GG)/12)
	by pidp (Wave), sort: egen JJ=max(abs(II))
	gen KK=`var' if inlist(ivfio,2) 
	gen LL=floor((KK-Birth_MY)/12)
	gen MM=(!missing(LL))
	by pidp (Wave), sort: egen NN=sum(MM)
	by pidp MM (Wave), sort: gen OO=KK if MM==1 & _n==1
	by pidp MM (Wave), sort: gen PP=LL if MM==1 & _n==1
	by pidp (Wave), sort: egen QQ=max(OO)
	by pidp (Wave), sort: egen RR=max(PP)
	gen SS=floor((KK-GG)/12)
	gen TT=floor((KK-QQ)/12)
	
	di in red ""
	di in red "Question 1: "
	count if DD==0 & NN==0  & tag==1
	local no1 `r(N)'
	di in red "`no1' of `N' pidps with 0 full interview or proxy observation for `var' (`=round(`no1'*100/`N',.01)'%)"
	di in red "Question 2: "
	count if DD==1 & tag==1
	local has1 `r(N)'
	di in red "`has1' of `N' pidps with 1 full interview observation for `var' (`=round(`has1'*100/`N',.01)'%)"
	di in red "Question 3: "
	count if DD>1 & tag==1
	local over1 `r(N)'
	di in red "`over1' of `N' pidps with 2+ full interview observation for `var' (`=round(`over1'*100/`N',.01)'%)"
	di in red "Question 4: "
	count if JJ>0 & !missing(JJ) & tag==1
	local diffans `r(N)'
	di in red "`diffans' of `over1' pidps with different answers for `var' (`=round(`diffans'*100/`over1',.01)'%)"
	di in red "HH: Age(`var') in first spell. II: Years difference from this in other waves."
	capture noisily tab HH II if DD>1  & II!=0
	if _rc!=0{
		noisily table HH II if DD>1  & II!=0
		}
	histogram II if II!=0, width(1)
	di in red "Question 5: "
	count if DD>=1 & NN>=1 & tag==1
	di in red "`r(N)' of `N' pidps have proxy and full-interview (`=round(`r(N)'*100/`N',.01)'%)"
	di in red "Question 6: "
	count if  DD>=1 & SS!=0
	local incon `r(N)'
	count if  DD>=1
	di in red "`incon' of `r(N)' observations with difference from original full-interview (`=round(`incon'*100/`r(N)',.01)'%)."
	di in red "HH: Age(`var') in first spell. OO: Years difference from this in proxy responses."
	capture noisily tab HH SS if DD>=1 & SS!=0
	if _rc!=0{
		noisily table HH SS if DD>=1 & SS!=0
		}
	di in red "Question 7: "
	count if DD==0 & NN>=1 & tag==1
	di in red "`r(N)' of `N' pidps have proxy only (`=round(`r(N)'*100/`N',.01)'%)"
	capture noisily tab RR SS if NN>=1 & DD==0 & SS!=0
	if _rc!=0{
		noisily table RR SS if NN>=1 & DD==0 & SS!=0
		}	
	
	drop AA-TT
	}
end

capture program drop prog_countsf
program define prog_countsf
	qui{
	
	foreach i in FTE F S{
		global `i'_Missing /*
			*/ "missing(`i'_IN_MY) & missing(`i'_FIN_MY) & missing(`i'_NO_MY)"
		}	
		
	count if $FTE_Missing
	local N=`r(N)'
	di in red "FTE Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"	
	count if $FTE_Missing & $F_Missing & $S_Missing
	di in red "     S and F Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
	di in red ""
	
	foreach i in IN FIN NO{
		count if !missing(S_`i'_MY) & $FTE_Missing & $F_Missing
		di in red "     S_`i'_MY with F Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)')%"
		count if !missing(F_`i'_MY) & $FTE_Missing & $S_Missing
		di in red "     F_`i'_MY with S Missing: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
		}
	di in red ""
		
	foreach i in IN FIN NO{		
		foreach j in IN FIN NO{
			count if !missing(S_`i'_MY,F_`j'_MY) & $FTE_Missing
			di in red "     S_`i'_MY & F_`j'_MY: `r(N)' (`=round(100*`r(N)'/`N',.01)'%)"
			}
		}
	}
end

capture program drop prog_makecombos
program define prog_makecombos
	args i j
	global i "`i'"
	global j "`j'"
	global if "!missing($i,$j) & (missing(FTE_IN_MY) & missing(FTE_FIN_MY) & missing(FTE_NO_MY))"
	quietly prog_makeage $i $j
	capture noisily tab ${i}_Age ${j}_Age if $if
	if _rc>0{
		table  ${i}_Age ${j}_Age if $if
		}
	count if $if
	capture drop XX
	gen XX=($if)
end

capture program drop prog_lhcombos
program define prog_lhcombos
	args i j
	global i "`i'"
	global j "`j'"
	global if "!missing(LH_${i}_MY) & !missing(FTE_${j}_MY)"	
	
	capture drop YY
	capture drop *Age
	quietly prog_makeage LH_${i}_MY FTE_${j}_MY
	quietly gen YY=LH_${i}_MY_Age-FTE_${j}_MY_Age
	label variable YY "Difference between LH_${i} & FTE_${j}"
	capture drop XX
	gen XX=($if)
	
	table LH_${i}_MY_Age FTE_${j}_MY_Age if $if & strpos(FTE_${j}_Source,"LH")==0
	table LH_${i}_MY_Age YY
	count if $if
end

capture program drop prog_ageremain
program define prog_ageremain
	args i
	local j=substr("`i'",1,1)
	if "`j'"=="S"	local j "F"
	else local j "S"
	global i "`i'"
	global if "$FTE_Missing & ${`j'_Missing}"
	quietly prog_makeage $i
	capture noisily tab ${i}_Age if $if
	capture drop XX
	gen XX=($if)
end

capture program drop prog_addprefix
program define prog_addprefix
	args macro prefix file
	local prelist: subinstr global `macro' " " " `prefix'_", all
	qui des using "`file'", varlist
	local vlist `r(varlist)'
	local inlist: list prelist & vlist
	use pidp `inlist' using "`file'", clear
end

capture program drop prog_monthsafterint
program define prog_monthsafterint
	args var
	tempvar XX
	quietly gen `XX'=`var'-IntDate_MY
	label variable `XX' "Months After Interview"
	di in red ""
	di in red "`var':"
	noisily tab `XX' if `XX'>0
	global if "`var'>IntDate_MY & !missing(`var',IntDate_MY)"	
	macro list if
end

capture program drop prog_chooseob
program define prog_chooseob
	args stub
	qui{
	tempfile Temp
	
	foreach i in FIN IN NO{
	
	capture confirm variable `stub'_`i'_MY
	if _rc==0{
	preserve
		keep if !missing(`stub'_`i'_MY)		
		capture drop `stub'_`i'_MY_Age
		
		gen `i'=.
		tempvar Wave
		gen `Wave'=`stub'_`i'_Wave
		
		if "`i'"=="FIN"{
			local function "min"
			local if "& inrange(BB-CC,0,12)==1"
			local drop "AA BB CC"
			}
		else{
			local function "max"
			local if ""
			local drop ""
			}
			
		forval j=1/2{
		
			if `j'==1 & "`i'"=="FIN"{		
				local source "Full Interview"
				}
			else if `j'==2 & "`i'"=="FIN"{
				local source "Proxy Interview"
				}
			else if `j'==1 & "`i'"!="FIN"{
				local source "Interview"
				}
			else if `j'==2 & "`i'"!="FIN"{
				continue
				}
				
			by pidp (`Wave'), sort: gen XX=_n /*
				*/ if !missing(`stub'_`i'_MY) /*
				*/ & strpos(`stub'_`i'_Source,"`source'")>0
			by pidp (`Wave'), sort: egen YY=`function'(XX)
			by pidp (`Wave'), sort: gen ZZ=`stub'_`i'_MY[YY]
			
			if "`i'"=="FIN"{
				
				gen AA=`stub'_`i'_MY if strpos(`stub'_`i'_Source,"`source'")>0
				by pidp (`Wave'), sort: egen BB=max(AA)
				by pidp (`Wave'), sort: egen CC=min(AA)
				
				count if tag==1
				local N=`r(N)'
				count if tag==1 & inrange(BB-CC,0,12)!=1 & !missing(ZZ)
				local n=`r(N)'
				local p=round((`n'*100)/`N',.01)
				di in red "`source': `r(N)' pidps with varying FIN dates (`p'%)"				
				}
			
			replace `stub'_`i'_Source="`source'" /*
				*/ if missing(`i') & !missing(ZZ) `if'
			by pidp (`Wave'), sort: replace `stub'_`i'_Wave=`stub'_`i'_Wave[YY] /*
				*/ if missing(`i') & !missing(ZZ) `if'
			by pidp (`Wave'), sort: replace `stub'_`i'_Qual=`stub'_`i'_Qual[YY] /*
				*/ if missing(`i') & !missing(ZZ) `if'
			replace `i'=ZZ if missing(`i') & !missing(ZZ) `if'
			
			drop XX YY ZZ `drop'
			}
			
		replace `stub'_`i'_MY=`i'
		prog_scrubvars `stub'_`i'
		
		keep pidp `stub'_`i'_*
		duplicates drop
		save "`Temp'", replace
		
	restore
	drop `stub'_`i'_*
	merge m:1 pidp using "`Temp'", nogen
	
		}
		}
		}
end

capture program drop prog_scrubvars
program define prog_scrubvars
	args stub
	ds `stub'*MY
	local vlist `r(varlist)'
	foreach i of local vlist{
		local j=subinstr("`i'","_MY","",.)
		capture replace `j'_Source="" if missing(`i')
		capture replace `j'_Wave=. if missing(`i')
		capture replace `j'_Qual=. if missing(`i')
		}
end

capture program drop prog_makevars
program define prog_makevars
	while "`*'"!=""{
		local stub "`1'"
		macro shift 1	
		local if "if !missing(`stub'_MY)"
		gen `stub'_Source=/*
				*/ cond(inlist(ivfio,1,3),"Full Interview","Proxy Interview") `if' 
		gen `stub'_Wave=Wave `if'
		gen `stub'_Qual=hiqual_dv `if'
		local lab: value label hiqual_dv
		label values `stub'_Qual `lab'
		}
end

capture program drop prog_ftetables
program define prog_ftetables
	args stub
	quietly{
	foreach j in S F{		
		local k="`j'`stub'"		
		capture confirm variable `k'_FIN_MY
		if _rc>0{
			continue
			}
		
		if "`j'"=="S"{
			local if "& missing(F`stub'_FIN_MY_Age)"
			}
		else{
			local if ""
			}	
		
		gen PropWithinYear=inrange(LH_FIN_MY_Age-`k'_FIN_MY_Age,-1,1) /*
			*/ if !missing(LH_FIN_MY_Age,`k'_FIN_MY_Age) `if'
		gen MeanAbsDiff=abs(LH_FIN_MY_Age-`k'_FIN_MY_Age) /*
			*/ if !missing(LH_FIN_MY_Age,`k'_FIN_MY_Age) `if'
		noisily table `k'_FIN_MY_Age if `k'_FIN_MY_Age<30 `if', /*
			*/ contents(n PropWithinYear mean PropWithinYear mean MeanAbsDiff) /*
			*/ center format(%9.2f)
		foreach l in "n PropWithinYear" "mean PropWithinYear" /*
			*/ "mean MeanAbsDiff"{
			capture noisily table `k'_FIN_Qual `k'_FIN_MY_Age /*
				*/ if `k'_FIN_MY_Age<30 & `k'_FIN_Qual>0 `if', /*
				*/ contents(`l') /*
				*/ center format(%9.2f)
//		 DRAW BOX AND WHISKER PLOT BY _MY_AGE
			}
		drop PropWithinYear MeanAbsDiff
		}
	}
end

capture program drop prog_spellbounds
program define prog_spellbounds
	args LB UB Start End
	capture drop Start End Interval FullPeriod
	gen Start=max(`Start',`LB') if !missing(`Start') & !missing(`LB')
	gen End=min(`End',`UB') if !missing(`End') & !missing(`UB')
	tempvar v1 v2 v3
	by pidp (Spell), sort: egen `v1'=min(Start)
	by pidp (Spell), sort: egen `v2'=max(End)
	gen `v3'=1 if Start>=End | `v1'>`LB' | `v2'<`UB'
	replace Start=. if `v3'==1
	replace End=. if `v3'==1
	gen Interval=End-Start
	gen FullPeriod=(`v1'<=`LB' & `v2'>=`UB' & !missing(`LB',`UB'))
end

capture program drop prog_cleaneduhist
program define prog_cleaneduhist
	gen Status=7
	gen Source="eduhist_w"+strofreal(Wave)
	gen Job_Hours=.i
	gen Job_Change=.i
	capture drop Spell
	by pidp (Start_MY End_MY), sort: gen Spell=_n
	gen Dataset=Spell
	prog_overlap
	drop if L_Overlap==1
	drop F_* L_* Dataset
	prog_collapsespells
	
	foreach var in Start End{
		gen `var'_Y=year(dofm(`var'_MY))
		}
	merge m:1 pidp Wave using "${dta_fld}/Interview Grid", /*
		*/ nogenerate keep(match master) keepusing(Birth_Y)
	prog_implausibledates Start
	by pidp Wave (Spell), sort: replace Spell=_n
	gen Status_Spells=1
	drop *_Y
	
	prog_attrend
end

capture program drop prog_overwritespell
program define prog_overwritespell
	args if Spell Start_MY End_MY Start_Flag End_Flag Source Status
	
	replace Source_Variable="N/A" if `if'
	replace Job_Hours=.i if `if'
	replace Job_Change=.i if `if'
	replace Status_Spells=1 if `if'	
	replace IntDate_MY=.i if `if'
	foreach i of varlist End_Reason* Job_Attraction*{
		replace `i'=.i if `if'
		}
	
	foreach i of varlist Spell Start_MY End_MY Start_Flag End_Flag Source Status{
		replace `i'=``i'' if `if'
		}
	
end

capture program drop prog_sytomy
program define prog_sytomy
	args MY SY Bound
	if "`Bound'"=="Lower"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,1, /*
			*/ cond(month(dofm(`SY'))==2,3, /*
			*/ cond(month(dofm(`SY'))==3,6, /*
			*/ cond(month(dofm(`SY'))==4,9,12)))))
			}
	if "`Bound'"=="Middle"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,1, /*
			*/ cond(month(dofm(`SY'))==2,4, /*
			*/ cond(month(dofm(`SY'))==3,7, /*
			*/ cond(month(dofm(`SY'))==4,10,12)))))
			}
	if "`Bound'"=="Upper"{
		replace `MY'=ym(year(dofm(`SY')), /*
			*/ cond(month(dofm(`SY'))==1,2, /*
			*/ cond(month(dofm(`SY'))==2,5, /*
			*/ cond(month(dofm(`SY'))==3,8, /*
			*/ cond(month(dofm(`SY'))==4,11,12)))))
			}
end

capture program drop prog_range
program define prog_range
	capture drop Gap
	capture drop Reverse
	capture drop MaxBelow* MinAbove*
	gen Reverse=-Spell
	foreach i in Y MY{
		foreach j in MaxBelow_`i' MinAbove_`i'{
			local sort=cond("`j'"=="MaxBelow_`i'","Spell","Reverse")
		
			gen `j'=Start_`i'
			by pidp Wave (`sort'), sort: replace `j'=`j'[_n-1] /*
				*/ if missing(`j')
			}
		
		replace MinAbove_`i'=IntDate_`i' if missing(MinAbove_`i')
		if "`i'"=="MY"{
			replace MaxBelow_MY=max(MaxBelow_MY,ym(MaxBelow_Y,1))
			replace MinAbove_MY=min(MinAbove_MY,ym(MinAbove_Y,12))
			}
		
		if "`i'"=="Y"	local missingdates=1
		if "`i'"=="MY"	local missingdates=0
		gen XX=1 if MinAbove_`i'==MaxBelow_`i' & missing(Start_`i')
		replace Start_`i'=MinAbove_`i' if XX==1
		replace MissingDates=`missingdates' if XX==1
		drop XX	
		}	
	gen Gap=MinAbove_MY-MaxBelow_MY
	format *MY %tm
	sort pidp Wave Spell
	drop Reverse
end

capture program drop prog_missingdates
program define prog_missingdates
	capture drop MissingDates
	gen MissingDates=0
	replace MissingDates=1 if missing(Start_MY)
	replace MissingDates=2 if missing(Start_Y)
end

capture program drop prog_format
	program define prog_format
	
	labelbook
	if "`r(names)'"!=""	label drop `r(names)'
	compress

	#delimit ;
	local vlist "pidp Wave Spell Status Start_MY End_MY Job_Hours
				Job_Change *Flag IntDate_MY End_Ind Status_Spells End_Reason*
				Job_Attraction* Source*";
	#delimit cr
	keep `vlist'
	order `vlist'

	do "${do_fld}/Labels.do"
	do "${do_fld}/Apply Labels"
	foreach var of varlist Status *Flag Job_Hours Job_Change{
		label values `var' `=lower("`var'")'
		}
	ds pidp Source*, not
	format `r(varlist)' %9.0g
	format *MY %tm
	format Source* %10s

	foreach var of varlist Job_* End_Reason*{
		replace `var'=.i if !inlist(Status,1,2,100)
		replace `var'=.m if inlist(Status,1,2,100) & missing(Status)
		}
	label data ""
end

capture program drop prog_attrend
program define prog_attrend
	foreach i of numlist 1/15 97{
		if !inrange(`i',12,15){
			gen End_Reason`i'=cond(inlist(Status,1,2,100),.m,.i)
			}
		gen Job_Attraction`i'=cond(inlist(Status,1,2,100),.m,.i)
		}
end

capture program drop prog_monthfromseason
program define prog_monthfromseason
	prog_imputeequaldates Y SY MY

	gen Reverse=-Spell

	foreach i in MinAbove MaxBelow{
		local sort=cond("`i'"=="MinAbove","Reverse","Spell")
		local bound=cond("`i'"=="MinAbove","Upper","Lower")
		local function=cond("`i'"=="MinAbove","min","max")
		local list=cond("`i'"=="MinAbove",",IntDate_MY","")

		gen `i'=Start_MY
		by pidp Wave (`sort'), sort: replace `i'=`i'[_n-1] if missing(`i')
		gen XX=.
		prog_sytomy XX Start_SY `bound'
		replace `i'=`function'(`i',XX`list')
		drop XX
		}

	by pidp Wave MaxBelow MinAbove (Spell), sort: /*
		*/ gen XX=floor(MaxBelow+((MinAbove-MaxBelow)*_n/(_N+1)))
	replace Start_Flag=6 if missing(Start_MY) & !missing(Start_SY) & !missing(XX)	
	replace Start_MY=XX if missing(Start_MY) & !missing(Start_SY) & !missing(XX)	
	drop XX	Reverse
end
