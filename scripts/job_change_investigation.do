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

log using "./_logs/job_change_investigation_`today'.txt", text replace 


/*
* Author: Nobles, Todd
* Email: tnobles@gmail.com
* Date: 2023_04_08
* File: job_change_investigation.do

Goals of Script: 
	- Examine demographics and wealth characteristics of those who change jobs 
	  (both from paid to self-employed and the reverse) and those who never change jobs  

	- Of those who move from self-employment to wage and salary, what happens to their income? 
	  What are the demographic characteristics of this group? 
	  Do different groups see different trajectories after this switch? 

	- Identifying what we can tell about home equity loans taken out for business purposes in the SIPP data.
		from the online codebook and the excel doc with variable descriptions, I do not see a variable that shows debts on any other assets that are labeled as explicitly for business purposes. 


Changelog

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

// getting down to one row per person so we can get basic demographics
collapse (firstnm) *status (max) change, by(ssuid_spanel_pnum_id black sex educ3 immigrant tage) 

foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status {
	label values `x' selfemp
	//bysort ssuid_spanel_pnum_id (`x'): carryforward `x', replace 

}
list in 1/10 
frame copy default collapsed


**# Age comparisons

tabstat tage, stat(n, mean, sd, min, median, max)
ttest tage, by(change)
ttest tage if first_status == 0, by(change)
ttest tage if first_status == 1, by(change)


**# Gender Comparisons
table sex, statistic(frequency) statistic(percent)
table (sex) (change), statistic(frequency) statistic(percent, across(sex)) // greater share of men who switch between WS and SE
table (sex) (first_status), statistic(frequency) statistic(percent, across(sex))
table (sex) (first_status) (change), statistic(frequency) statistic(percent, across(sex)) // first table is those who never changed, second table is those who switched at some point, so of the 1160 who started as WS and switched, 58.45% of them were men. 




**# Race
// note direction of table calculations shifts here
table black, statistic(frequency) statistic(percent) 
table (black) (change), statistic(frequency) statistic(percent, across(change)) // 
table (black) (first_status), statistic(frequency) statistic(percent, across(first_status)) // 9.9 % of white respondents started as SE, 5.86% of black respondents started as SE
table (black) (first_status) (change), statistic(frequency) statistic(percent, across(first_status))
// example interpretation
// looking at those who changed (second table), 61.5 of black respondents shifted from WS to SE at some point. 38.5% 


**# Education
table educ3, statistic(frequency) statistic(percent) 
table (educ3) (change), statistic(frequency) statistic(percent, across(change)) // 
table (educ3) (first_status), statistic(frequency) statistic(percent, across(first_status)) // 
table (educ3) (first_status) (change), statistic(frequency) statistic(percent, across(first_status))
// example interpretation


**# Race/Education 
table (educ3) (black first_status)
table (educ3) (black first_status), statistic(percent, across(first_status))
table (educ3) (black) if first_status == 0, statistic(frequency) statistic(percent, across(educ3)) // WS 
table (educ3) (black) if first_status == 1, statistic(frequency) statistic(percent, across(educ3)) // SE



**# Merge Wealth Data
merge 1:m ssuid_spanel_pnum_id using sipp_monthly_combined, keep(1 3) // bringing in wealth data. This is at person-month level


*# Home debt (person-wave)
tabstat tdebt_home if monthcode == 12, stat(n, mean, sd, min, median, max)
tabstat tdebt_home if monthcode == 12, by(black) stat(n, mean, sd, min, median, max)
ttest tdebt_home if monthcode == 12, by(black )
ttest tdebt_home if monthcode == 12 & first_status == 0, by(black ) // WS
ttest tdebt_home if monthcode == 12 & first_status == 1, by(black)  // SE
ttest tdebt_home if monthcode ==12 & black == 0, by(first_status )
ttest tdebt_home if monthcode ==12 & black == 1, by(first_status)

table (black) (first_status change) if monthcode == 12, statistic(mean tdebt_home) statistic(sd tdebt_home) statistic(median tdebt_home)

tabstat tdebt_home if monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat tdebt_home if black == 1 & monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat tdebt_home if black == 0 & monthcode ==12, by(educ3) stat(n, mean, sd, min, median, max)
table (educ3) (black first_status) if monthcode == 12, statistic(frequency) statistic(mean tdebt_home)
table (educ3) (black first_status) if monthcode == 12 & change ==0 ,  statistic(mean tdebt_home) statistic(median tdebt_home)
table (educ3) (black first_status) if monthcode == 12& change == 1,  statistic(mean tdebt_home) statistic(median tdebt_home)



**# Home Equity (person-wave)

tabstat teq_home if monthcode == 12, stat(n, mean, sd, min, median, max)
ttest teq_home if monthcode == 12, by(black )
ttest teq_home if monthcode == 12 & first_status == 0, by(black ) // WS
ttest teq_home if monthcode == 12 & first_status == 1, by(black)  // SE
ttest teq_home if monthcode ==12 & black == 0, by(first_status )
ttest teq_home if monthcode ==12 & black == 1, by(first_status)

table (black) (first_status change) if monthcode == 12, statistic(mean teq_home) statistic(sd teq_home) statistic(median teq_home)

tabstat teq_home if monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat teq_home if black == 1 & monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat teq_home if black == 0 & monthcode ==12, by(educ3) stat(n, mean, sd, min, median, max)
table (educ3) (black first_status) if monthcode == 12, statistic(frequency) statistic(mean teq_home)
table (educ3) (black first_status) if monthcode == 12 & change ==0 , statistic(mean teq_home) statistic(median teq_home)
table (educ3) (black first_status) if monthcode == 12& change == 1,  statistic(mean teq_home) statistic(median teq_home)



**# Total Debt (person-wave)
tabstat tdebt_ast if monthcode == 12, stat(n, mean, sd, min, median, max)
ttest tdebt_ast if monthcode == 12, by(black )
ttest tdebt_ast if monthcode == 12 & first_status == 0, by(black ) // WS
ttest tdebt_ast if monthcode == 12 & first_status == 1, by(black)  // SE
ttest tdebt_ast if monthcode ==12 & black == 0, by(first_status )
ttest tdebt_ast if monthcode ==12 & black == 1, by(first_status)

table (black) (first_status change) if monthcode == 12, statistic(mean tdebt_ast) statistic(sd tdebt_ast) statistic(median tdebt_ast)

tabstat tdebt_ast if monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat tdebt_ast if black == 1 & monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat tdebt_ast if black == 0 & monthcode ==12, by(educ3) stat(n, mean, sd, min, median, max)
table (educ3) (black first_status) if monthcode == 12, statistic(frequency) statistic(mean tdebt_ast)
table (educ3) (black first_status) if monthcode == 12 & change ==0 , statistic(mean tdebt_ast) statistic(median tdebt_ast)
table (educ3) (black first_status) if monthcode == 12& change == 1,  statistic(mean tdebt_ast) statistic(median tdebt_ast)

**# Net-worth (person-wave)
tabstat tnetworth if monthcode == 12, stat(n, mean, sd, min, median, max)
ttest tnetworth if monthcode == 12, by(black )
ttest tnetworth if monthcode == 12 & first_status == 0, by(black ) // WS
ttest tnetworth if monthcode == 12 & first_status == 1, by(black)  // SE
ttest tnetworth if monthcode ==12 & black == 0, by(first_status )
ttest tnetworth if monthcode ==12 & black == 1, by(first_status)

table (black) (first_status change) if monthcode == 12, statistic(mean tnetworth) statistic(sd tnetworth) statistic(median tnetworth)

tabstat tnetworth if monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat tnetworth if black == 1 & monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat tnetworth if black == 0 & monthcode ==12, by(educ3) stat(n, mean, sd, min, median, max)
table (educ3) (black first_status) if monthcode == 12, statistic(frequency) statistic(mean tnetworth)
table (educ3) (black first_status) if monthcode == 12 & change ==0 , statistic(mean tnetworth) statistic(median tnetworth) 
table (educ3) (black first_status) if monthcode == 12& change == 1,  statistic(mean tnetworth) statistic(median tnetworth) 



capture log close 

log using "../_logs/job_change_earnings_`today'.txt", text replace 


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
collapse (mean) mean_tpearn = tpearn (median) med_tpearn = tpearn (sd) sd_tpearn =tpearn, by(ssuid_spanel_pnum_id selfemp tage sex educ3 immigrant black first_status)
reshape wide *_tpearn, i(ssuid_spanel_pnum_id) j(selfemp)
rename *0 *WS
rename *1 *SE

list in 1/10

count if mean_tpearnWS > mean_tpearnSE // 1506 obs total 

gen group = "WS to higher SE" if first_status== 0 & mean_tpearnWS < mean_tpearnSE
replace group = "WS to lower SE" if first_status ==0 & mean_tpearnWS > mean_tpearnSE
replace group = "SE to lower WS" if first_status == 1 & mean_tpearnSE > mean_tpearnWS
replace group = "SE to higher WS" if first_status == 1 & mean_tpearnSE < mean_tpearnWS 

tab group black, missing
table group black, statistic(percent, across(group)) // interpretation is that 28% of black respondents who switched job types once in our data, started as Self-employed and shifted to a higher paying WS job.
table group educ3
table group educ3, statistic(percent, across(group))

table group (educ3 black) // n-sizes get quite small here 




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


keep if first_status  ==1 
// here tpearn will vary by month while tjb_prftb will be constant accross the wave.
collapse (mean) mean_tpearn = tpearn  mean_prft = tjb_prftb  mean_msum = tjb_msum (median) med_tpearn = tpearn med_prftb = tjb_prftb med_msum = tjb_msum (sd) sd_tpearn =tpearn sd_prftb = tjb_prftb sd_msum = tjb_msum (count) months=monthcode, by(ssuid_spanel_pnum_id selfemp tage sex educ3 immigrant black ever_changed)

list ssuid_span~d  selfemp  ever_changed  mean* med* sd* months in 1/15  // missings here are expected structural missing due to WS employment periods not having any business profit reported 

// now have a dataset with one row per person per job type and the earnings/profitability during the period they had that job category


// Comparing incomes during self-emp period between those who stayed self-employed versus those who switched
tabstat mean_tpearn if selfemp == 1, by(ever_changed) 
ttest mean_tpearn if selfemp == 1 & black == 1, by(ever_changed)
ttest mean_tpearn if selfemp ==1 & black ==0, by(ever_changed)


tabstat med_tpearn if selfemp==1, by(ever_changed)
table (ever_changed) (black ) if selfemp ==1 ,  statistic(mean med_tpearn) // as expected for both of these

/// what if we use tjb_msum
tabstat mean_msum if selfemp == 1, by(ever_changed) 
table (ever_changed) (black ) if selfemp == 1,  statistic(mean mean_msum) 

tabstat med_msum if selfemp==1, by(ever_changed)
table (ever_changed) (black ) if selfemp ==1 ,  statistic(mean med_msum) // as expected for both of these

// comparing profitabilty during self-emp period between those who stayed self-employed versus those who switched to WS 
tabstat mean_prft if selfemp == 1, by(ever_changed) 
table (ever_changed) (black ) if selfemp == 1,  statistic(mean mean_prft) 
table (ever_changed) (black) if selfemp ==1 , statistic(frequency) // gaind 44 black self employed folks here compared compared to previous version 

ttest mean_prft if selfemp == 1 & black == 1, by(ever_changed)
ttest mean_prft if selfemp ==1 & black ==0, by(ever_changed)

tabstat med_prft if selfemp==1, by(ever_changed)
table (ever_changed) (black ) if selfemp ==1 ,  statistic(mean med_prft) // as expected those who switch were less profitable beforehand

// copmaring income and prftb over educ 
table (ever_changed) (educ3 ) if selfemp == 1,  statistic(mean mean_tpearn) 
table (ever_changed) (educ3) if selfemp == 1, statistic(mean mean_msum) 
table (ever_changed) (educ3) if selfemp == 1, statistic(mean mean_prft)

pwmean mean_tpearn if selfemp ==1, over(educ3 ever_changed) mcompare(tukey) pveffects   

table (ever_changed) (educ3) if selfemp == 1 & black ==1 // cell sizes get fairly small here
// out of curiosity, what do we see though

table (ever_changed) (educ3) if selfemp ==1 & black == 1, statistic(mean mean_tpearn) 
table (ever_changed) (educ3) if selfemp ==1 & black == 0, statistic(mean mean_tpearn)

pwmean mean_tpearn if selfemp ==1 & black ==1, over(educ3 ever_changed) mcompare(tukey) pveffects   
pwmean mean_tpearn if selfemp ==1 & black ==0, over(educ3 ever_changed) mcompare(tukey) pveffects   





**# Less restrictive filters 
// here we are no longer looking at only those who started as self-employed and/or those who switched once or never as we did above. Now we are including those who changed multiple times and those who never changed. 

frame copy precollapse temp2, replace 
frame change temp2
sort ssuid_spanel_pnum_id swave monthcode
list  swave monthcode change  selfemp *status ever_changed  if ssuid_spanel_pnum_id == 199771, sepby(swave)
drop _merge
merge 1:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined, keep(1 3)
codebook jb_main // only looking at main jobs, just confirming

// still some small n-sizes but better than the earlier analysis
unique ssuid_spanel_pnum_id if first_status ==1 & ever_changed > 0, by(black educ3) 
unique ssuid_spanel_pnum_id if first_status ==1 & ever_changed == 0, by(black educ3)



capture log close  







/*

foreach x in second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status {
	gsort ssuid_spanel_pnum_id -`x' 
	by ssuid_spanel_pnum_id: carryforward `x', replace 
}

list ssuid_spanel_pnum_id selfemp ever_changed *status if ssuid_spanel_pnum_id == 113


// here tpearn will vary by month while tjb_prftb will be constant accross the wave.
collapse (mean) mean_tpearn = tpearn  mean_prft = tjb_prftb  mean_msum = tjb_msum (median) med_tpearn = tpearn med_prftb = tjb_prftb med_msum = tjb_msum (sd) sd_tpearn =tpearn sd_prftb = tjb_prftb sd_msum = tjb_msum (count) months=monthcode, by(ssuid_spanel_pnum_id selfemp tage sex educ3 immigrant black ever_changed *status)

list ssuid_span~d  selfemp  ever_changed  mean* med* sd* months in 1/15  // missings here are expected structural missing due to WS employment periods not having any business profit reported 
list ssuid_span~d  selfemp  ever_changed  mean* med* sd* months if ssuid_spanel_pnum_id==113 

// now have a dataset with one row per person per job type and the earnings/profitability during the period they had that job category
gen changed = 0 if ever_changed ==0 
replace changed = 1 if ever_changed >0

// Comparing incomes during self-emp period between those who stayed self-employed versus those who switched
ttest mean_tpearn if selfemp == 1, by(changed) 
table (changed) (black) if selfemp ==1 , statistic(frequency)
table (changed) (black ) if selfemp == 1,  statistic(mean mean_tpearn) 

// need to add in t-tests here for the various group differences. 


*/


































**# Looking at our main_job flag versus earnings information 

use sipp_reshaped_work_comb, clear  
merge m:1 ssuid_spanel_pnum_id using unique_individuals, keep(1 3) // bringing in demographic info. Age here is a snapshot from one of our records, someone could have aged out towards the later years, but shouldn't mess with results too much 


//working with the black-white sample
keep if erace==1|erace==2 //this keeps the black and white sample only.
codebook erace

// recode race
recode erace (2=1 Black) (nonmiss=0 White), into(black)
label variable black "race"


// filtering to population of interest
keep if tage>=18 & tage<=64
drop _merge
merge m:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined, keep(1 3)

drop if ejb_jborse == 3 
keep if tjb_mwkhrs >= 15

gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 
list  swave monthcode ejb_jobid ejb_jborse tjb_msum tjb_mwkhrs jb_main tjb_prftb tpearn if ssuid_spanel_pnum_id == 199771, sepby(swave monthcode)
// need to look into how common this is and if it changes how we need to mark main job



