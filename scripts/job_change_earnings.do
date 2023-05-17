capture log close

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

log using "./_logs/job_change_earnings_unemployment.txt", text replace 


/*
* Author: Nobles, Todd
* Email: tnobles@uw.edu
* File: job_change_earnings.do

Goals of Script: 
	- Tracking those who have spells of unemployment and their earnings

Changelog
20230504 Initial creation
20230505 Branching from previous job_change_investigation script 
20230511 revisiting after resolving issues with missing job_ids in initial_data_prep 
*/

cd "`datapath'"

// this dataset contains person-wave-month-job level rows for all years of data we have. 
// file produced in initial_data_prep.do

use sipp_reshaped_work_comb, clear  
// bringing in monthly level data 
merge m:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined 
sort ssuid_spanel_pnum_id spanel swave monthcode 
bysort ssuid_spanel_pnum_id: egen _merge_avg = mean(_merge)

list ssuid_spanel_pnum_id if _merge_avg >2 & _merge_avg <3 in 1/100
list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tjb_mwkhrs tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==5
// by bringing in the monthly data we get the full 12 months for this person. previously missing months 9 and 10 in the job only data set 


// examining how our job variables overlap with unemployment flag that we brought in reingesting data for sipp_monthly_combined

sort ssuid_spanel_pnum_id spanel swave monthcode ejb_startwk
list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==200841

list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==200842
list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==200852
list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==200850
list ssuid_spanel_pnum_id  swave monthcode job ejb_jborse ejb_startwk ejb_endwk enjflag  tjb_mwkhrs if ssuid_spanel_pnum_id ==199771 // Wave 4 month 7 here we see that you can be marked as a jobless spell even if you get recorded as a job during the month given there can be gaps in start/end weeks that don't stretch a full month-job


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

codebook ejb_jborse

// note here we're not filtering to only records with tjb_mwkhrs > 15 hours of employment 



**# main job
gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 

duplicates report ssuid_spanel_pnum_id swave monthcode tjb_mwkhrs ejb_jobid  // no ties actually broken 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

sort ssuid_spanel_pnum_id swave monthcode 
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5


**# Switches based on job type (self-emp or paid)
keep if jb_main == 1 // this keeps main jobs and one record for months where they are fully unemployed
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5

replace tpearn = 0 if tpearn == .

list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5

// creating lenient employment type flag. job trumps unemployment flag  (must be unemployed for at least one month to count as unemployed)
gen employment_type = 1 if ejb_jborse == 1 // W&S
replace employment_type = 2 if ejb_jborse == 2 // SE
replace employment_type = 3 if ejb_jborse == 3 // other 
replace employment_type = 4 if ejb_jborse == . & enjflag == 1
codebook employment_type 


list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type if ssuid_spanel_pnum_id==272
list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type if ssuid_spanel_pnum_id==937
list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type if ssuid_spanel_pnum_id==193993 

 // will ignore these few edge cases for now as they just seem to be data entry issues 

unique ssuid_spanel_pnum_id swave monthcode // person month level file here. So we only have one job per month and it's their main job 
unique ssuid_spanel_pnum_id swave // person years
isid ssuid_spanel_pnum_id swave monthcode // double checking 


// at this point we have a person-month level file with an employment status for them for each period captured in employment_type 


egen tag = tag(ssuid_spanel_pnum_id employment_type)
su tag
bysort ssuid_spanel_pnum_id: egen tag_sum = sum(tag)
unique ssuid_spanel_pnum_id if tag_sum >1 // gives us count of people who changed at some point 

label define employment_types 1 "W&S" 2 "SE" 3 "Other" 4 "Unemployed"
label values employment_type employment_types

**# marking when their job status changes
bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen change = employment_type != employment_type[_n-1] & _n >1 
list ssuid_spanel_pnum_id spanel swave monthcode employment_type  change if ssuid_spanel_pnum_id == 28558, sepby(swave) 

bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen first_status = employment_type if _n==1

by ssuid_spanel_pnum_id: egen ever_changed = total(change)
table ever_changed
bysort ever_changed: distinct ssuid_spanel_pnum_id  // counts of people falling into each job change category. ~73k never changed between statuses, ~1500 changed once,

gsort ssuid_spanel_pnum_id -change spanel swave monthcode

list ssuid_spanel_pnum_id spanel swave monthcode employment_type change *status if ssuid_spanel_pnum_id == 199771
by ssuid_spanel_pnum_id: gen second_status = employment_type if change ==1 & _n ==1
by ssuid_spanel_pnum_id: gen third_status = employment_type if change ==1 & _n ==2
by ssuid_spanel_pnum_id: gen fourth_status = employment_type if change ==1 & _n ==3
by ssuid_spanel_pnum_id: gen fifth_status = employment_type if change ==1 & _n ==4
by ssuid_spanel_pnum_id: gen sixth_status = employment_type if change ==1 & _n ==5
by ssuid_spanel_pnum_id: gen seventh_status = employment_type if change ==1 & _n ==6
by ssuid_spanel_pnum_id: gen eighth_status = employment_type if change ==1 & _n ==7
by ssuid_spanel_pnum_id: gen ninth_status = employment_type if change ==1 & _n ==8
by ssuid_spanel_pnum_id: gen tenth_status = employment_type if change ==1 & _n ==9
by ssuid_spanel_pnum_id: gen eleventh_status = employment_type if change ==1 & _n ==10
by ssuid_spanel_pnum_id: gen twelfth_status = employment_type if change ==1 & _n ==11


foreach x in first_status ever_changed second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status {
	label values `x' employment_types
	//bysort ssuid_spanel_pnum_id (`x'): carryforward `x', replace 

}

sort ssuid_spanel_pnum_id spanel swave monthcode 
list ssuid_spanel_pnum_id spanel swave monthcode employment_type  change *status if ssuid_spanel_pnum_id == 199771

list ssuid_spanel_pnum_id spanel swave monthcode employment_type  change *status if ssuid_spanel_pnum_id == 28558	


local i = 0
foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status {
	gsort ssuid_spanel_pnum_id -`x' 
	local i = `i' + 1
	by ssuid_spanel_pnum_id: carryforward `x', gen(status_`i') 
	
}


sort ssuid_spanel_pnum_id swave monthcode employment_type

local i = 0
foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status {
	local i = `i' + 1
	bysort ssuid_spanel_pnum_id (swave monthcode) employment_type: carryforward `x', gen(status_`i'_lim)  dynamic_condition(employment_type[_n-1]==employment_type[_n])

}

list ssuid_spanel_pnum_id swave monthcode employment_type status_*_lim if ssuid_spanel_pnum_id ==  178409 
list ssuid_spanel_pnum_id swave monthcode employment_type status_*_lim if ssuid_spanel_pnum_id ==  199771 
list ssuid_spanel_pnum_id swave monthcode employment_type status_*_lim if ssuid_spanel_pnum_id ==  28558 

list ssuid_spanel_pnum_id swave monthcode employment_type first_status status_1 status_1_lim if ssuid_spanel_pnum_id ==  28558

frame copy default precollapse, replace 


**# Unemployed to SE 
/*
gen flip_unemp_SE =1  if (status_1 == 4 & status_2 == 2) | ///
		(status_2 == 4 & status_3 == 2) | ///
		(status_3 == 4 & status_4 == 2) | ///
		(status_4 == 4 & status_5 == 2) `| ///
		(status_5 == 4 & status_6 == 2) | ///
		(status_6 == 4 & status_7 == 2) | ///
		(status_7 == 4 & status_8 == 2) | ///
		(status_8 == 4 & status_9 == 2) | ///
		(status_9 == 4 & status_10 == 2) | ///
		(status_10 == 4 & status_11 == 2) | ///
		(status_11 == 4 & status_12 == 2) 
*/

list ssuid_spanel_pnum_id swave monthcode employment_type if status_1 ==.
drop if status_1 == . 

egen unique_ind = tag(ssuid_spanel_pnum_id)
tab status_1 status_2 if unique_ind, miss
tab status_2 status_3 if unique_ind, miss
tab status_3 status_4 if unique_ind, miss

preserve
collapse (mean) mean_tpearn = tpearn mean_tjbmsum = tjb_msum, by(ssuid_spanel_pnum_id  sex educ3 immigrant black status_1_lim status_2_lim status_3_lim)

drop if employment_type ==.
decode employment_type, gen(emp_type_factor)
drop employment_type
replace emp_type_factor = "WS" if emp_type_factor == "W&S"
replace emp_type_factor = "Unemp" if emp_type_factor == "Unemployed"
reshape wide mean*, i(ssuid_spanel_pnum_id sex educ3 immigrant black) j(emp_type_factor) string









egen wave_month = group(swave monthcode), label //used for attempting some graphs to get a sense of groupings 

preserve	
		
collapse (mean) mean_tpearn = tpearn mean_tjbmsum = tjb_msum, by(ssuid_spanel_pnum_id employment_type sex educ3 immigrant black)

bysort ssuid_spanel_pnum_id: gen status = _n 
reshape wide mean*, i(ssuid_spanel_pnum_id sex educ3 immigrant black employment_type) j(status)
drop if employment_type ==.
decode employment_type, gen(emp_type_factor)
drop employment_type
replace emp_type_factor = "WS" if emp_type_factor == "W&S"
replace emp_type_factor = "Unemp" if emp_type_factor == "Unemployed"
//reshape wide mean*, i(ssuid_spanel_pnum_id sex educ3 immigrant black) j(emp_type_factor) string

reshape wide *_tpearn, i(ssuid_spanel_pnum_id) j(selfemp)
rename *0 *WS
rename *1 *SE

		
