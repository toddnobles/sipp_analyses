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
* File: job_change_earnings_unemployment.do

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

use sipp_reshaped_work_comb_imputed, clear  
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



// filtering to population of interest
keep if tage>=18 & tage<=64

codebook ejb_jborse

// note here we're not filtering to only records with tjb_mwkhrs > 15 hours of employment. We'll do that later for describing earnings 

**# main job
gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 

duplicates report ssuid_spanel_pnum_id swave monthcode tjb_mwkhrs ejb_jobid  // no ties actually broken 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

sort ssuid_spanel_pnum_id swave monthcode 
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5


**# Switches based on job type (self-emp or paid)
keep if jb_main == 1 // this keeps main jobs and one record for months where they are fully unemployed
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==6 // need to handle people who were never employed

recode enjflag (1=1 unemployed) (2=0 no), into(unemployed_flag)
codebook enjflag 
codebook unemployed_flag

// dropping those who never worked in our dataset
bysort ssuid_spanel_pnum_id: egen sum_enjflag = sum(unemployed_flag)
bysort ssuid_spanel_pnum_id: gen num_records = _N
drop if sum_enjflag == num_records


replace tpearn = 0 if tpearn == .
replace tjb_msum = 0 if tjb_msum == .

list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn tjb_msum tjb_mwkhrs sum_enjflag if ssuid_spanel_pnum_id==5


/// now we can use sum_enjflag as our measure of if it is ever greater than zero then that person experienced unemployment at some point in our dataset
drop if (ejb_jborse == . | ejb_jborse == 3) // dropping employment types we're not interested in 
recode ejb_jborse (2=1 SE) (1=0 WS), into(selfemp)

list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse selfemp enjflag tpearn tjb_msum tjb_mwkhrs sum_enjflag if ssuid_spanel_pnum_id==5

**# Generating our earnings measures and flags
// comparing those who experienced unemployment versus those who didn't and their earnings 
gen ever_unemployed = 1 if sum_enjflag >0
replace ever_unemployed = 0 if sum_enjflag == 0
codebook ever_unemployed

bysort ssuid_spanel_pnum_id: egen mean_tpearn = mean(tpearn) 
bysort ssuid_spanel_pnum_id: egen mean_tpearn_se = mean(tpearn) if selfemp == 1
bysort ssuid_spanel_pnum_id: egen mean_tpearn_ws = mean(tpearn) if selfemp == 0 
egen unique_tag = tag(ssuid_spanel_pnum_id) // unique id

egen tag2 = tag(ssuid_spanel_pnum_id selfemp)
su tag2
bysort ssuid_spanel_pnum_id: egen tag2_sum = sum(tag2) // lets us quickly see who had multiple employment types in our data 

list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main selfemp tpearn tjb_msum ever_unemployed mean* unique_tag tag2_sum if ssuid_spanel_pnum_id==  195816
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main selfemp tpearn tjb_msum ever_unemployed mean* unique_tag tag2_sum if ssuid_spanel_pnum_id==  6
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main selfemp tpearn tjb_msum ever_unemployed mean* unique_tag tag2_sum if ssuid_spanel_pnum_id==  200730
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main selfemp tpearn tjb_msum ever_unemployed mean* unique_tag tag2_sum if ssuid_spanel_pnum_id==  200574


unique ssuid_spanel_pnum_id, by(sum_enjflag) // gives us a picture of how many people experienced unemployment and how many months they experienced it. So here ~4000 people were unemployed for one month or less, ~2100 experienced two "months" of unemployment (here someone is marked as unemployed for the month if they experienced as little as a week of unemployment that month)

**# Tables of earnings 

ttest mean_tpearn if unique_tag ==1, by(ever_unemployed)
table (erace) (ever_unemployed) if unique_tag ==1, statistic(mean mean_tpearn)
ttest mean_tpearn if unique_tag ==1 & erace ==1, by(ever_unemployed)
ttest mean_tpearn if unique_tag ==1 & erace ==2, by(ever_unemployed)

// what about wage and salary earnings
ttest mean_tpearn_ws if unique_tag ==1, by(ever_unemployed)
ttest mean_tpearn_ws if unique_tag ==1 & erace ==1, by(ever_unemployed)
ttest mean_tpearn_ws if unique_tag ==1 & erace ==2, by(ever_unemployed)

// what about self-employment earnings
ttest mean_tpearn_se if unique_tag ==1 ,by(ever_unemployed)
ttest mean_tpearn_se if unique_tag ==1 & erace ==1, by(ever_unemployed)
ttest mean_tpearn_se if unique_tag ==1 & erace ==2, by(ever_unemployed)



// those who ever experience unemployment in our dataset earn less per month on average than those who do not 





capture log close 











**# Looking at the various pathways that people take through employment statuses 


use sipp_reshaped_work_comb_imputed, clear  
// bringing in monthly level data 
merge m:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined 
sort ssuid_spanel_pnum_id spanel swave monthcode 
bysort ssuid_spanel_pnum_id: egen _merge_avg = mean(_merge)

list ssuid_spanel_pnum_id if _merge_avg >2 & _merge_avg <3 in 1/100
list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tjb_mwkhrs tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==5
// by bringing in the monthly data we get the full 12 months for this person. previously missing months 9 and 10 in the job only data set 


// examining how our job variables overlap with unemployment flag that we brought in reingesting data for sipp_monthly_combined

sort ssuid_spanel_pnum_id spanel swave monthcode ejb_startwk
list ssuid_spanel_pnum_id  swave monthcode job ejb_jborse ejb_startwk ejb_endwk enjflag  tjb_mwkhrs if ssuid_spanel_pnum_id ==199771 // Wave 4 month 7 here we see that you can be marked as a jobless spell even if you get recorded as a job during the month given there can be gaps in start/end weeks that don't stretch a full month-job


// filtering to population of interest
keep if tage>=18 & tage<=64

codebook ejb_jborse


**# main job
gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 

duplicates report ssuid_spanel_pnum_id swave monthcode tjb_mwkhrs ejb_jobid  // no ties actually broken 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

sort ssuid_spanel_pnum_id swave monthcode 
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5
list ssuid_spanel_pnum_id ejb_jobid swave monthcode ejb_jobid tjb_mwkhrs jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==199771

keep if jb_main ==1 // gets us one record for each month with their main job or that they were unemployed 
recode enjflag (1=1 unemployed) (2=0 no), into(unemployed_flag)
codebook enjflag 
codebook unemployed_flag

// dropping those who never worked in our dataset
bysort ssuid_spanel_pnum_id: egen sum_enjflag = sum(unemployed_flag)
bysort ssuid_spanel_pnum_id: gen num_records = _N
drop if sum_enjflag == num_records


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
unique ssuid_spanel_pnum_id, by(ever_changed)  // counts of people falling into each job change category. ~73k never changed between statuses, ~1500 changed once,

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


egen unique_tag = tag(ssuid_spanel_pnum_id) // unique id

preserve
keep if unique_tag 
contract status_*
gsort -_freq
list in 1/15
restore 


preserve
keep if unique_tag
contract status_1 status_2 status_3 
gsort -_freq
list
restore 


preserve
keep if unique_tag
contract status_1 status_2 erace 
gsort erace -_freq
list 
restore 


sort ssuid_spanel_pnum_id swave monthcode employment_type

local i = 0
//fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status
foreach x in first_status second_status third_status  {
	local i = `i' + 1
	bysort ssuid_spanel_pnum_id (swave monthcode) employment_type: carryforward `x', gen(status_`i'_lim)  dynamic_condition(employment_type[_n-1]==employment_type[_n])

}

list ssuid_spanel_pnum_id swave monthcode employment_type status_*_lim if ssuid_spanel_pnum_id ==  178409 
list ssuid_spanel_pnum_id swave monthcode employment_type status_*_lim if ssuid_spanel_pnum_id ==  199771 
list ssuid_spanel_pnum_id swave monthcode employment_type status_*_lim if ssuid_spanel_pnum_id ==  28558 


frame copy default precollapse, replace 

collapse (mean) tpearn, by(ssuid_spanel_pnum_id status_1 status_2 status_3 status_1_lim status_2_lim status_3_lim erace) cw















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

		
