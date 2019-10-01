/*
********************************************************************************
LAUNCH PROGRAMME.DO
	
	THIS DO FILE SETS GLOBAL MACRO VALUES USED ACROSS THE DO FILE.
	PLEASE CHANGE THE GLOBAL MACRO VALUES IN SECTION 1 TO FIT WITH YOUR FOLDERS
	THE FULL CODE CAN BE RUN WITHIN THIS DO FILE BY CHANGING run_full TO YES.
	TO CHANGE THE LENGTH TO IMPUTE BY HALVING GAPS, CHANGE LINE 49.



********************************************************************************
*/
qui{
clear all
macro drop _all
set more off

/*
1. Change the following parameters.
*/
*i. Top-level directory which original and constructed data files will be located under
cd "E:\UKHLS 1-8 & BHPS 1-18, Special Licence\"
*i. Number of BHPS Waves to be collected
global bhps_waves			18
*ii. Number of Understanding Society Waves to be collected
global ukhls_waves			8
*iii. BHPS Folder Prefix for Stata Files
global bhps_path			bhps
*iv. UKHLS Folder Prefix for Stata Files
global ukhls_path			ukhls
*v. Common stub which is affixed on end of original stata files (e.g. *_protect where using Special Licence files)
global file_type			_protect
*vi. List BHPS Life History Waves (lifemst files)
global bhps_lifehistwaves 	2 11 12
*vii. Waves Employment Status History collected in (empstat files)
global ukhls_lifehistwaves 	1 5
*viii. Directory in which UKHLS and BHPS files are kept.
global fld					"stata/stata13_se"
*ix. Folder activity histories will be saved in.
global dta_fld				"Data/Activity Histories/"
*x. Folder do files are kept in.
global do_fld				"Do Files/Activity Histories/"
*xi. Set Personal ado folder
sysdir set PLUS 			"${do_fld}/ado/"
*xii. Decide whether to run full code (set equal to YES, if so)
global run_full				"YES"
*xiii. Set maximum length of gap imputed by halving space between two adjacent spells.
global gap_length			6

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
	///XX: Need to add in Seam Effect check code to all.
	cls
	di in red "Program Started: $S_TIME  $S_DATE"
	
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
	
	di in red "Program Completed: $S_TIME"
	}
