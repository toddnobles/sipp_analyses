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

log using "./_logs/job_change_earnings_comparisons_imputed`today'.txt", text replace 


/*
* Author: Nobles, Todd
* Email: tnobles@gmail.com
* Date: 2023_05-18
* File: job_change_earnings_comparisons_imputed.do

Goals of Script: 
	- breaking earnings work into new file now that we're working with imputed/non-imputed job_id datasets. The old version of this code was as part of the job_change_investigation.do script 
	

Changelog
-2023-05-18 creation 

*/

cd "`datapath'"

// this dataset contains person-wave-month-job level rows for all years of data we have. 
// file produced in initial_data_prep.do

use sipp_reshaped_work_comb_imputed, clear  
merge m:1 ssuid_spanel_pnum_id using unique_individuals, keep(1 3) // bringing in demographic info. Age here is a snapshot from one of our records, someone could have aged out towards the later years, but shouldn't mess with results too much 


/*------------------------------------------------------------------------------
**# 1.1 Recoding demographics and filtering to population of interest
------------------------------------------------------------------------------*/
//working with the black-white sample
codebook erace

// recode race

label define race_labels 1 "white" 2 "black" 3 "asian" 4 "other"
gen race = erace
label values race race_labels
label variable race "race"
codebook race


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

**# Earnings by change
// bringing in tpearn which is month level (not job level but appears to be our most reliable earnings measure to capture both self employed income and/or wage income accurately)
frame copy precollapse temp, replace 
frame change temp
sort ssuid_spanel_pnum_id swave monthcode
list  swave monthcode change  selfemp *status ever_changed  if ssuid_spanel_pnum_id == 199771, sepby(swave)
drop _merge
merge 1:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined, keep(1 3)

list  swave monthcode change  selfemp *status ever_changed tpearn  if ssuid_spanel_pnum_id == 199771, sepby(swave)
// for simplicity we'll only look at the folks who changed job types once and see what happened to their incomes
keep if ever_changed == 1
bysort ssuid_spanel_pnum_id (swave monthcode): carryforward first_status, replace
collapse (mean) mean_tpearn = tpearn (median) med_tpearn = tpearn (sd) sd_tpearn =tpearn, by(ssuid_spanel_pnum_id selfemp tage sex educ3 immigrant race first_status)
reshape wide *_tpearn, i(ssuid_spanel_pnum_id) j(selfemp)
rename *0 *WS
rename *1 *SE

list in 1/10

count if mean_tpearnWS > mean_tpearnSE // 1506 obs total 

gen group = "WS to higher SE" if first_status== 0 & mean_tpearnWS < mean_tpearnSE
replace group = "WS to lower SE" if first_status ==0 & mean_tpearnWS > mean_tpearnSE
replace group = "SE to lower WS" if first_status == 1 & mean_tpearnSE > mean_tpearnWS
replace group = "SE to higher WS" if first_status == 1 & mean_tpearnSE < mean_tpearnWS 

tab group race, missing
table group race, statistic(percent, across(group)) // interpretation is that 28% of black respondents who switched job types once in our data, started as Self-employed and shifted to a higher paying WS job.
table group educ3
table group educ3, statistic(percent, across(group))

table  ( race educ3) group // n-sizes get quite small here 




**# Examining business profits and earnings

** those who start as self employed and never switch versus those who switch what happens to their earnings? 

frame copy precollapse temp2, replace 
frame change temp2
sort ssuid_spanel_pnum_id swave monthcode
list  swave monthcode change  selfemp *status ever_changed  if ssuid_spanel_pnum_id == 199771, sepby(swave)
drop _merge
merge 1:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined, keep(1 3)
tab jb_main // only looking at main jobs, just confirming


keep if ever_changed == 1 | ever_changed == 0 
bysort ssuid_spanel_pnum_id (swave monthcode): carryforward first_status, replace


keep if first_status == 1 
// here tpearn will vary by month while tjb_prftb will be constant accross the wave.
collapse (mean) mean_tpearn = tpearn  mean_prft = tjb_prftb  mean_msum = tjb_msum (median) med_tpearn = tpearn med_prftb = tjb_prftb med_msum = tjb_msum (sd) sd_tpearn =tpearn sd_prftb = tjb_prftb sd_msum = tjb_msum (count) months=monthcode, by(ssuid_spanel_pnum_id selfemp tage sex educ3 immigrant race ever_changed)

list ssuid_span~d  selfemp  ever_changed  mean* med* sd* months in 1/15  // missings here are expected structural missing due to WS employment periods not having any business profit reported 

// now have a dataset with one row per person per job type and the earnings/profitability during the period they had that job category


// Comparing incomes during self-emp period between those who stayed self-employed versus those who switched
ttest mean_tpearn if selfemp ==1, by(ever_changed)
preserve
version 16.1: table (ever_changed) (race ) if selfemp == 1,  contents(mean mean_tpearn) replace
bysort race (ever_changed): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest mean_tpearn if selfemp == 1 & race == 1, by(ever_changed) // white
ttest mean_tpearn if selfemp ==1 & race ==2, by(ever_changed) // black 
ttest mean_tpearn if selfemp == 1 & race == 3, by(ever_changed) // asian 
// not significant differences here 

/// what if we use tjb_msum
ttest mean_msum if selfemp == 1, by(ever_changed) // significant
preserve
version 16.1: table (ever_changed) (race ) if selfemp == 1,  contents(mean mean_msum) replace
bysort race (ever_changed): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest mean_msum if selfemp ==1 & race ==1, by(ever_changed) // not significant
ttest mean_msum if selfemp ==1 & race ==2, by(ever_changed) // significant 
ttest mean_msum if selfemp ==1 & race == 3, by(ever_changed)


// medians (here the median is the medain monthly earnings for an individual, so here we can compare the means of these distributions (of medians) using ttests still )
ttest med_msum if selfemp==1, by(ever_changed)
preserve
version 16.1: table (ever_changed) (race ) if selfemp == 1,  contents(mean med_msum) replace
bysort race (ever_changed): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest med_msum if selfemp ==1 & race ==1, by(ever_changed)
ttest med_msum if selfemp ==1 & race ==2, by(ever_changed)
ttest med_msum if selfemp ==1 & race ==3, by(ever_changed)


ttest med_tpearn if selfemp ==1, by(ever_changed)
preserve
version 16.1: table (ever_changed) (race ) if selfemp == 1,  contents(mean med_tpearn) replace
bysort race (ever_changed): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest med_tpearn if selfemp ==1 & race ==1, by(ever_changed)
ttest med_tpearn if selfemp ==1 & race ==2, by(ever_changed)
ttest med_tpearn if selfemp ==1 & race ==3, by(ever_changed)

// comparing profitabilty during self-emp period between those who stayed self-employed versus those who switched to WS 
ttest mean_prft if selfemp == 1, by(ever_changed) 
preserve
version 16.1: table (ever_changed) (race ) if selfemp == 1,  contents(mean mean_prft) replace
bysort race (ever_changed): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
table (ever_changed) (race) if selfemp ==1 , statistic(frequency) // gaind 44 black self employed folks here compared compared to previous version 
ttest mean_prft if selfemp == 1 & race == 1, by(ever_changed)
ttest mean_prft if selfemp ==1 & race ==2, by(ever_changed)

ttest med_prft if selfemp==1, by(ever_changed)
preserve
version 16.1: table (ever_changed) (race ) if selfemp == 1,  contents(mean med_prft) replace
bysort race (ever_changed): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest med_prft if selfemp == 1 & race == 1, by(ever_changed)
ttest med_prft if selfemp ==1 & race ==2, by(ever_changed)


// copmaring income and prftb over educ 
table (ever_changed) (educ3 ) if selfemp == 1,  statistic(mean mean_tpearn) 
table (ever_changed) (educ3) if selfemp == 1, statistic(mean mean_msum) 
table (ever_changed) (educ3) if selfemp == 1, statistic(mean mean_prft)

pwmean mean_tpearn if selfemp ==1, over(educ3 ever_changed) mcompare(tukey) pveffects   

table ( race ever_changed) (educ3) if selfemp == 1, statistic(mean mean_tpearn)

table (ever_changed) (educ3) if selfemp ==1 & race == 1, statistic(mean mean_tpearn) 
table (ever_changed) (educ3) if selfemp ==1 & race == 1, statistic(frequency)

table (ever_changed) (educ3) if selfemp ==1 & race == 2, statistic(mean mean_tpearn)
table (ever_changed) (educ3) if selfemp ==1 & race == 2, statistic(frequency)

table (ever_changed) (educ3) if selfemp ==1 & race == 3, statistic(mean mean_tpearn)
table (ever_changed) (educ3) if selfemp ==1 & race == 3, statistic(frequency)



pwmean mean_tpearn if selfemp ==1 & race ==1, over(educ3 ever_changed) mcompare(tukey) pveffects   
pwmean mean_tpearn if selfemp ==1 & race ==2, over(educ3 ever_changed) mcompare(tukey) pveffects   





**# Less restrictive filters 
// here we are no longer looking at only those who started as self-employed and/or those who switched once or never as we did above. Now we are including those who changed multiple times and those who never changed. 

frame copy precollapse temp2, replace 
frame change temp2
drop _merge
merge 1:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined, keep(1 3)
codebook jb_main // only looking at main jobs, just confirming

// still some small n-sizes but better than the earlier analysis
unique ssuid_spanel_pnum_id if first_status ==1 & ever_changed > 0, by(race educ3) 
unique ssuid_spanel_pnum_id if first_status ==1 & ever_changed == 0, by(race educ3)

gen changegt0= 1 if ever_changed >0
replace changegt0 = 0 if ever_changed == 0 

bysort ssuid_spanel_pnum_id (swave monthcode): carryforward first_status, replace


keep if first_status == 1 
// here tpearn will vary by month while tjb_prftb will be constant accross the wave.
collapse (mean) mean_tpearn = tpearn  mean_prft = tjb_prftb  mean_msum = tjb_msum (median) med_tpearn = tpearn med_prftb = tjb_prftb med_msum = tjb_msum (sd) sd_tpearn =tpearn sd_prftb = tjb_prftb sd_msum = tjb_msum (count) months=monthcode, by(ssuid_spanel_pnum_id selfemp tage sex educ3 immigrant race changegt0)


// Comparing incomes during self-emp period between those who stayed self-employed versus those who switched
ttest mean_tpearn if selfemp ==1, by(changegt0)
preserve
version 16.1: table (changegt0) (race ) if selfemp == 1,  contents(mean mean_tpearn) replace
bysort race (changegt0): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest mean_tpearn if selfemp == 1 & race == 1, by(changegt0) // white
ttest mean_tpearn if selfemp ==1 & race ==2, by(changegt0) // black 
ttest mean_tpearn if selfemp == 1 & race == 3, by(changegt0) // asian 

/// what if we use tjb_msum
ttest mean_msum if selfemp == 1, by(changegt0) // significant
preserve
version 16.1: table (changegt0) (race ) if selfemp == 1,  contents(mean mean_msum) replace
bysort race (changegt0): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest mean_msum if selfemp ==1 & race ==1, by(changegt0) // not significant
ttest mean_msum if selfemp ==1 & race ==2, by(changegt0) // significant 
ttest mean_msum if selfemp ==1 & race == 3, by(changegt0)


// medians (here the median is the medain monthly earnings for an individual, so here we can compare the means of these distributions (of medians) using ttests still )
ttest med_msum if selfemp==1, by(changegt0)
preserve
version 16.1: table (changegt0) (race ) if selfemp == 1,  contents(mean med_msum) replace
bysort race (changegt0): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest med_msum if selfemp ==1 & race ==1, by(changegt0)
ttest med_msum if selfemp ==1 & race ==2, by(changegt0)
ttest med_msum if selfemp ==1 & race ==3, by(changegt0)


ttest med_tpearn if selfemp ==1, by(changegt0)
preserve
version 16.1: table (changegt0) (race ) if selfemp == 1,  contents(mean med_tpearn) replace
bysort race (changegt0): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest med_tpearn if selfemp ==1 & race ==1, by(changegt0)
ttest med_tpearn if selfemp ==1 & race ==2, by(changegt0)
ttest med_tpearn if selfemp ==1 & race ==3, by(changegt0)

// comparing profitabilty during self-emp period between those who stayed self-employed versus those who switched to WS 
ttest mean_prft if selfemp == 1, by(changegt0) 
preserve
version 16.1: table (changegt0) (race ) if selfemp == 1,  contents(mean mean_prft) replace
bysort race (changegt0): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
table (changegt0) (race) if selfemp ==1 , statistic(frequency)  
ttest mean_prft if selfemp == 1 & race == 1, by(changegt0)
ttest mean_prft if selfemp ==1 & race ==2, by(changegt0)

ttest med_prft if selfemp==1, by(changegt0)
preserve
version 16.1: table (changegt0) (race ) if selfemp == 1,  contents(mean med_prft) replace
bysort race (changegt0): gen pct_diff = (table1[_n] - table1[_n-1])/table1[_n]
list
restore
ttest med_prft if selfemp == 1 & race == 1, by(changegt0)
ttest med_prft if selfemp ==1 & race ==2, by(changegt0)


// copmaring income and prftb over educ 
table (changegt0) (educ3 ) if selfemp == 1,  statistic(mean mean_tpearn) 
table (changegt0) (educ3) if selfemp == 1, statistic(mean mean_msum) 
table (changegt0) (educ3) if selfemp == 1, statistic(mean mean_prft)

pwmean mean_tpearn if selfemp ==1, over(educ3 changegt0) mcompare(tukey) pveffects   

table ( race changegt0) (educ3) if selfemp == 1, statistic(mean mean_tpearn)

table (changegt0) (educ3) if selfemp ==1 & race == 1, statistic(mean mean_tpearn) 
table (changegt0) (educ3) if selfemp ==1 & race == 1, statistic(frequency)

table (changegt0) (educ3) if selfemp ==1 & race == 2, statistic(mean mean_tpearn)
table (changegt0) (educ3) if selfemp ==1 & race == 2, statistic(frequency)

table (changegt0) (educ3) if selfemp ==1 & race == 3, statistic(mean mean_tpearn)
table (changegt0) (educ3) if selfemp ==1 & race == 3, statistic(frequency)



pwmean mean_tpearn if selfemp ==1 & race ==1, over(educ3 changegt0) mcompare(tukey) pveffects   
pwmean mean_tpearn if selfemp ==1 & race ==2, over(educ3 changegt0) mcompare(tukey) pveffects   






capture log close  

