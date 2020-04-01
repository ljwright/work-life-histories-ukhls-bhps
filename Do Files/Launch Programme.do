/*
********************************************************************************
LAUNCH PROGRAMME.DO
	
	THIS DO FILE SETS GLOBAL MACRO VALUES USED ACROSS THE DO FILES.
	PLEASE CHANGE THE GLOBAL MACRO VALUES IN SECTION 1 TO FIT WITH YOUR FOLDERS.
	THE FULL CODE CAN BE RUN WITHIN THIS DO FILE BY CHANGING run_full TO YES.
	TO CHANGE THE MAXIMUM LENGTH TO IMPUTE BY SPLITTING GAPS, CHANGE LINE 49.



********************************************************************************
*/
qui{
clear all
macro drop _all
set more off

/*
1. Change the following parameters.
*/
* Top-level directory which original and constructed data files will be located under
cd "E:/"
* Directory in which UKHLS and BHPS files are kept.
global fld					"UKHLS 1-9 and BHPS 1-18, Standard Licence/stata/stata11_se"
* Folder activity histories will be saved in.
global dta_fld				"Projects/UKHLS Work-Life Histories/Data"
* Folder do files are kept in.
global do_fld				"Projects/UKHLS Work-Life Histories/Do Files"
* Set Personal ado folder
sysdir set PLUS 			"${do_fld}/ado/"

* BHPS Folder Prefix for Stata Files
global bhps_path			bhps
* UKHLS Folder Prefix for Stata Files
global ukhls_path			ukhls
* Common stub which is affixed on end of original stata files (e.g. "_protect" where using Special Licence files; blank for End User Licence files)
global file_type			_protect		

* Number of BHPS Waves to be collected
global bhps_waves			18
* Number of Understanding Society Waves to be collected
global ukhls_waves			9		
* List BHPS Life History Waves (lifemst files)
global bhps_lifehistwaves 	2 11 12
* Waves Employment Status History collected in (empstat files)
global ukhls_lifehistwaves 	1 5

* Set maximum length of gap imputed by halving space between two adjacent spells.
global gap_length			6

* Decide whether to run full code (set equal to YES, if so)
global run_full				"YES"

/*
2. Macros to be used across do files.
*/
global total_waves=${ukhls_waves}+${bhps_waves}
global max_waves=max(${bhps_waves},${ukhls_waves})
global first_bhps_eh_wave=8
global last_bhps_eh_wave=18

/*
3. Create Reusable Programs.
*/
do "${do_fld}/Create Programs.do"
}
											
/*
4. Run Do Files
*/
if "$run_full"=="YES"{
	cls
	global start_time "$S_TIME"
	di in red "Program Started: $start_time"
	
	*i. Prepare basis data.
	qui do "${do_fld}/Interview Grid.do"	
	
	*ii. Education data
	qui do "${do_fld}/UKHLS Education History.do"
	qui do "${do_fld}/BHPS Education History.do"
	qui do "${do_fld}/FTE Variables - Collect.do"
	qui do "${do_fld}/FTE Variables - Clean.do"
	
	*ii. Work Histories
	qui do "${do_fld}/UKHLS Annual History.do"
	qui do "${do_fld}/UKHLS Life History.do"
	
	qui do "${do_fld}/BHPS Annual History - Waves 1-15.do"
	qui do "${do_fld}/BHPS Annual History - Waves 16-18.do"
	qui do "${do_fld}/BHPS Life History.do"
		
	*ii. Merge datasets
	qui do "${do_fld}/Merge Datasets.do"
	
	di in red "Program Started: $start_time"
	di in red "Program Completed: $S_TIME"
	}
