ture log close

clear all
set more off
set trace off
pause on
macro drop _all

//local homepath "/Users/toddnobles/Documents/SIPP Data Files/"
local homepath "/Volumes/Extreme SSD/SIPP Data Files/"

local datapath "`homepath'/dtas"

cd "`homepath'"


local c_time = c(current_time)
local today : display %tdCYND date(c(current_date), "DMY")

log using "./_logs/job_change_earnings_comparisons_imputed_non_`today'.txt", text replace 


/*
* Author: Nobles, Todd
* Email: tnobles@gmail.com
* Date: 2023_04_08
* File: job_change_earnings_comparisons_imputed_non.do

Goals of Script: 
	- breaking earnings work into new file now that we're working with imputed/non-imputed job_id datasets. The old version of this code was as part of the job_change_investigation.do script 
	

Changelog
-2023-05-18 creation 

*/

cd "`datapath'"

// this dataset contains person-wave-month-job level rows for all years of data we have. 
// file produced in initial_data_prep.do

use sipp_reshaped_work_comb, clear  
merge m:1 ssuid_spanel_pnum_id using unique_individuals, keep(1 3) // bringing in demographic info. Age here is a snapshot from one of our records, someone could have aged out towards the later years, but shouldn't mess with results too much 


/*------------------------------------------------------------------------------
**# 1.1 Recoding demographics and filtering to population of interest
------------------------------------------------------------------------------*/
//working with the black-white sample
keep if erace==1|erace==2 //this keeps the black and white sample only.
codebook erace

// recode race
recode erace (2=1 Black) (nonmiss=0 White), into(black)
label variable black "race"


// filtering to population of interest
keep if tage>=18 & tage<=64
drop if ejb_jborse == 3 

// for this analysis we'll filter to only examine jobs that are at least 15 hours per week
keep if tjb_mwkhrs >= 15


**# Flip flop main job

gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

// how many cases of flip-flopping are there (where a jobid is main, then it isn't, then it is again)
sort ssuid_spanel_pnum_id ejb_jobid swave monthcode
qby ssuid_spanel_pnum_id ejb_jobid: gen jb_main_m1=jb_main[_n-1]
qby ssuid_spanel_pnum_id ejb_jobid: gen jb_main_p1=jb_main[_n+1]
gen flip=jb_main_m1==1 & jb_main==0 & jb_main_p1==1
replace flip=1 if jb_main_m1==0 & jb_main==1 & jb_main_p1==0

order ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main* flip ejb_jborse

// example id where they go from ejob 101 as main job to one month of job 201 as main job then flip back 
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main* flip ejb_jborse if ssuid_spanel_pnum_id ==199 

count if flip != 0  // not that many instances of main job changing back and forth 


**# Switches based on job type (self-emp or paid)
keep if jb_main == 1
unique ssuid_spanel_pnum_id swave monthcode // person month level file here. So we only have one job per month and it's their main job 
unique ssuid_spanel_pnum_id swave // person years
isid ssuid_spanel_pnum_id swave monthcode // double checking 

egen tag = tag(ssuid_spanel_pnum_id ejb_jborse)
su tag
bysort ssuid_spanel_pnum_id: egen tag_sum = sum(tag)
unique ssuid_spanel_pnum_id if tag_sum >1 // gives us count of people who changed at some point 



drop tag tag_sum
recode ejb_jborse (2=1 SE) (1=0 WS), into(selfemp)
table ejb_jborse selfemp

sort ssuid_spanel_pnum_id spanel swave monthcode 

**# marking when their job status changes
bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen change = ejb_jborse != ejb_jborse[_n-1] & _n >1 
list ssuid_spanel_pnum_id spanel swave monthcode ejb_jborse  change if ssuid_spanel_pnum_id == 28558, sepby(swave) 

bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen first_status = selfemp if _n==1

by ssuid_spanel_pnum_id: egen ever_changed = total(change)
table ever_changed
bysort ever_changed: distinct ssuid_spanel_pnum_id  // counts of people falling into each job change category. ~73k never changed between statuses, ~1500 changed once,

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
