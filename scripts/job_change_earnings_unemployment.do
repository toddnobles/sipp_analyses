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

// flag for ever self-employed 
bysort ssuid_spanel_pnum_id: egen sum_se_flag = sum(selfemp) // selfemp coded as 0 for W&S and 1 for SE 
gen ever_se = 1 if sum_se_flag >0
replace ever_se = 0 if sum_se_flag == 0 
codebook ever_se

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








**# Self-employed sample only 
// based on the analyses below, we know that the most common employment paths are as follows
/*
   |   status_1     status_2     status_3     status_4     status_5   status_6  _freq |
     |----------------------------------------------------------------------------------|
  1. |        W&S            .            .            .            .          .  58372 |
  2. | Unemployed          W&S            .            .            .          .   7858 |
  3. |         SE            .            .            .            .          .   6095 |
  4. |        W&S   Unemployed            .            .            .          .   5403 |
  5. |        W&S   Unemployed          W&S            .            .          .   4659 |
     |----------------------------------------------------------------------------------|
  6. | Unemployed          W&S   Unemployed            .            .          .   2325 |
  7. | Unemployed          W&S   Unemployed          W&S            .          .   1634 |
  8. |        W&S           SE            .            .            .          .    883 |
  9. |        W&S   Unemployed          W&S   Unemployed            .          .    735 |
 10. |         SE          W&S            .            .            .          .    715 |
     |----------------------------------------------------------------------------------|
 11. | Unemployed           SE            .            .            .          .    597 |
 12. |        W&S   Unemployed          W&S   Unemployed          W&S          .    533 |
 13. |      Other            .            .            .            .          .    529 |
 14. |         SE   Unemployed            .            .            .          .    493 |
 15. | Unemployed          W&S   Unemployed          W&S   Unemployed          .    459 |
     |----------------------------------------------------------------------------------|
 16. | Unemployed          W&S   Unemployed          W&S   Unemployed        W&S    311 |
 17. |        W&S           SE          W&S            .            .          .    290 |
 18. |        W&S   Unemployed           SE            .            .          .    202 |
 19. |      Other          W&S            .            .            .          .    188 |
 20. | Unemployed        Other            .            .            .          .    178 |
     |----------------------------------------------------------------------------------|
 21. |        W&S        Other            .            .            .          .    155 |
 22. | Unemployed           SE   Unemployed            .            .          .    150 |
 23. |         SE          W&S           SE            .            .          .    126 |
 24. |      Other   Unemployed            .            .            .          .    123 |
 25. |         SE   Unemployed           SE            .            .          .    121 |
     +----------------------------------------------------------------------------------+

*/

// Because of this complexity in when someone is self-employed versus unemployed, we'll look at those who were ever self-employed and their profit, business size, earnings etc 

**# Profitability 

bysort ssuid_spanel_pnum_id: egen mean_tjb_prftb = mean(tjb_prftb) 

list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main selfemp tpearn tjb_msum tjb_prftb ever_unemployed mean* unique_tag tag2_sum if ssuid_spanel_pnum_id==  32
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main selfemp tpearn tjb_msum tjb_prftb ever_unemployed mean* unique_tag tag2_sum if ssuid_spanel_pnum_id==  74

table (ever_unemployed) (ever_se) if unique_tag ==1, statistic(mean mean_tjb_prftb)
ttest mean_tjb_prftb if unique_tag ==1 & ever_se == 1, by(ever_unemployed)
table (ever_unemployed) (erace) if ever_se == 1 & unique_tag == 1


**# Business Size 
// Note that this doesn't capture instances where switched businesses as their main job, so if someone started a small business and then started another larger business that became their main job, we would only capture their first business size. Likely not a meaningful issue for the purposes of these descriptives 
/*
Response Code
1. 1 (Only self)
2. 2 to 9 employees
3. 10 to 25 employees
4. Greater than 25 employees
*/

tabchi ever_unemployed tjb_empb if unique_tag ==1 & ever_se == 1
// seems those who experienced unemployment are more likely to work as sole-proprietor or own smaller business 
tab tjb_empb if unique_tag ==1 & ever_se ==1
tab ever_unemployed tjb_empb if unique_tag ==1 & ever_se ==1, row



**# Earnings
ttest mean_tpearn_se if unique_tag == 1 & ever_se ==1, by(ever_unemployed)



**# SE who never experienced unemployment 
// Looking only at SE who have never experienced unemployment, see distribution of those three variables for full SE never unemployed sample and then within races, between races (depending on sample sizes)

su mean_tpearn if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, detail // average monthly earnings
hist mean_tpearn if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0

su mean_tpearn_se if unique_tag == 1 & ever_se == 1 & ever_unemployed == 0, detail // average monthly earnings when self-employed
hist mean_tpearn_se if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0

su mean_tjb_prftb if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0, detail // average monthly profit 
hist mean_tjb_prftb if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0

tab tjb_empb if unique_tag ==1 & ever_se ==1 & ever_unemployed ==0 
hist tjb_empb if unique_tag == 1 & ever_se == 1 & ever_unemployed ==0


table (erace) (ever_unemployed) if unique_tag ==1 & ever_se == 1 
table (erace) if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, statistic(mean mean_tjb_prftb)



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
drop if employment_type == . 
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
list in 1/25
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

		
