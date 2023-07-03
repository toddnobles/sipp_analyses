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

frame copy default temp, replace 
frame change temp
// first keeping in all SE and WS jobs, those less than 15 and secondary jobs 
gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

recode ejb_jborse (2=1 SE) (1=0 WS), into(selfemp)
table ejb_jborse selfemp

egen tag = tag(ssuid_spanel_pnum_id swave monthcode selfemp)
keep if tag ==1 
keep ssuid_spanel_pnum_id swave monthcode selfemp sex educ3 

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
frame copy default temp, replace 
frame change temp 
keep if tjb_mwkhrs >= 15

gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 
keep if jb_main ==1 // this gets us down to one record per month 

recode ejb_jborse (2=1 SE) (1=0 WS), into(selfemp)
table ejb_jborse selfemp


keep ssuid_spanel_pnum_id swave monthcode selfemp sex educ3

list ssuid_spanel_pnum_id swave monthcode selfemp  if ssuid_spanel_pnum_id == 28558

capture drop _merge
merge 1:1 ssuid_spanel_pnum_id  swave monthcode using sipp_monthly_combined, keep(1 3)
keep ssuid_spanel_pnum_id swave monthcode selfemp tpearn

count if selfemp == 0 & tpearn <0 
unique ssuid_spanel_pnum_id if selfemp == 0 & tpearn <0
gen tag =1 if selfemp == 0 & tpearn <0 
replace tag = 2 if tag ==.
sort tag ssuid_spanel_pnum_id swave monthcode 
list in 1/50


levelsof ssuid_spanel_pnum_id if tag == 1

// some ids to look into here 
/*
1039 2392 4674 17299 21883 32887 36356 39257 40664 43039 44485 45889 48287 48421 50592 52911 58781 65042 67865 69206 70133 72049 74680 79113 82022 85146 86562
>  87495 88633 89613 93494 105618 109045 109358 114555 117895 121473 122624 122931 123533 129445 131415 139536 139607 140282 142073 144551 146676 150371 15142
> 9 151430 152198 153823 155775 156208 159946 162369 164154 164534 169421 171746 173034 173158 175289 179312 179780 180626 186305 188666 189476 192350 193139 
> 196220 199667
*/

frame change default
sort ssuid_spanel_pnum_id swave monthcode 
merge m:1 ssuid_spanel_pnum_id  swave monthcode using sipp_monthly_combined, keep(1 3)
list ssuid_spanel_pnum_id swave monthcode job tjb_msum tjb_mwkhrs tjb_prftb ejb_jborse tpearn if ssuid_spanel_pnum_id == 2392
list ssuid_spanel_pnum_id swave monthcode job tjb_msum tjb_mwkhrs tjb_prftb ejb_jborse tpearn if ssuid_spanel_pnum_id == 17299

capture log close
