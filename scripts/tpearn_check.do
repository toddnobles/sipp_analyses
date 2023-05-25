capture log close

clear all
set more off
set trace off
pause on
macro drop _all

local homepath "/Volumes/Extreme SSD/SIPP Data Files/"

local datapath "`homepath'/dtas"

cd "`homepath'"


local c_time = c(current_time)
local today : display %tdCYND date(c(current_date), "DMY")

log using "./_logs/tpearn_check_`today'.txt", text replace 


/*
* Author: Nobles, Todd
* Email: tnobles@gmail.com
* Date: 2023_05-25
* File: tpearn_check.do

Goals of Script: 
- double checking that we don't see negative numbers for tpearn wage and salary if they've never had SE, basically making sure the var is correct 	

Changelog
-2023-05-25 creation 

*/

cd "`datapath'"

// this dataset contains person-wave-month-job level rows for all years of data we have. 
// file produced in initial_data_prep.do

use sipp_reshaped_work_comb_imputed, clear  
merge m:1 ssuid_spanel_pnum_id using unique_individuals, keep(1 3) // bringing in demographic info. Age here is a snapshot from one of our records, someone could have aged out towards the later years, but shouldn't mess with results too much 
drop _merge

// filtering to population of interest
keep if tage>=18 & tage<=64
drop if ejb_jborse == 3 


// first keeping in all SE and WS jobs, those less than 15 and secondary jobs 
gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

recode ejb_jborse (2=1 SE) (1=0 WS), into(selfemp)
table ejb_jborse selfemp

egen tag = tag(ssuid_spanel_pnum_id swave monthcode selfemp)
keep if tag ==1 
keep ssuid_spanel_pnum_id swave monthcode selfemp sex educ3 race

bysort ssuid_spanel_pnum_id swave monthcode selfemp: gen any_SE_month = 1 if selfemp[_N] == 1

bysort ssuid_spanel_pnum_id swave monthcode (any_SE_month): carryforward any_SE_month, replace 

list ssuid_spanel_pnum_id swave monthcode selfemp any_SE_month  if ssuid_spanel_pnum_id ==28558

replace any_SE_month = 0 if any_SE_month == . 

egen tag = tag(ssuid_spanel_pnum_id swave monthcode any_SE_month)
keep if tag 

merge 1:1 ssuid_spanel_pnum_id  swave monthcode using sipp_monthly_combined, keep(1 3)
keep ssuid_spanel_pnum_id swave monthcode any_SE_month tpearn

count if any_SE_month == 0 & tpearn <0 



**# What about if we use only our main_job method of capturing monthly employment? Any tradeoffs?







**# marking when their job status changes
bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen change = ejb_jborse != ejb_jborse[_n-1] & _n >1 
list ssuid_spanel_pnum_id spanel swave monthcode ejb_jborse  change if ssuid_spanel_pnum_id == 28558, sepby(swave) 

bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen first_status = selfemp if _n==1

by ssuid_spanel_pnum_id: egen ever_changed = total(change)
table ever_changed
bysort ever_changed: distinct ssuid_spanel_pnum_id  

gsort ssuid_spanel_pnum_id -change spanel swave monthcode

list ssuid_spanel_pnum_id spanel swave monthcode selfemp first_status change *status if ssuid_spanel_pnum_id == 199771
by ssuid_spanel_pnum_id: gen second_status = selfemp if change ==1 & _n ==1
by ssuid_spanel_pnum_id: gen third_status = selfemp if change ==1 & _n ==2
by ssuid_spanel_pnum_id: gen fourth_status = selfemp if change ==1 & _n ==3
by ssuid_spanel_pnum_id: gen fifth_status = selfemp if change ==1 & _n ==4
by ssuid_spanel_pnum_id: gen sixth_status = selfemp if change ==1 & _n ==5
by ssuid_spanel_pnum_id: gen seventh_status = selfemp if change ==1 & _n ==6
by ssuid_spanel_pnum_id: gen eighth_status = selfemp if change ==1 & _n ==7

foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status {
	label values `x' selfemp
	//bysort ssuid_spanel_pnum_id (`x'): carryforward `x', replace 

}

list ssuid_spanel_pnum_id spanel swave monthcode selfemp  change *status if ssuid_spanel_pnum_id == 199771
list ssuid_spanel_pnum_id spanel swave monthcode selfemp  change *status if ssuid_spanel_pnum_id == 68775

frame copy default precollapse, replace 
