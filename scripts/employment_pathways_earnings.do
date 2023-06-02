webdoc init Employment_pathways_earnings, replace logall
webdoc toc

/***
<html>
<head><title>Employment Pathways Earnings </title></head>
***/

local homepath "/Volumes/Extreme SSD/SIPP Data Files/"

local datapath "`homepath'/dtas"

cd "`datapath'"
set linesize 255

/***
<html>
<body>
<h1>Bringing in data</h1>
***/

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
/*
by ssuid_spanel_pnum_id: gen sixth_status = employment_type if change ==1 & _n ==5
by ssuid_spanel_pnum_id: gen seventh_status = employment_type if change ==1 & _n ==6
by ssuid_spanel_pnum_id: gen eighth_status = employment_type if change ==1 & _n ==7
by ssuid_spanel_pnum_id: gen ninth_status = employment_type if change ==1 & _n ==8
by ssuid_spanel_pnum_id: gen tenth_status = employment_type if change ==1 & _n ==9
by ssuid_spanel_pnum_id: gen eleventh_status = employment_type if change ==1 & _n ==10
by ssuid_spanel_pnum_id: gen twelfth_status = employment_type if change ==1 & _n ==11
*/

foreach x in first_status ever_changed second_status third_status fourth_status fifth_status {
	label values `x' employment_types
	//bysort ssuid_spanel_pnum_id (`x'): carryforward `x', replace 

}

sort ssuid_spanel_pnum_id spanel swave monthcode 
list ssuid_spanel_pnum_id spanel swave monthcode employment_type  change *status if ssuid_spanel_pnum_id == 199771

list ssuid_spanel_pnum_id spanel swave monthcode employment_type  change *status if ssuid_spanel_pnum_id == 28558	


local i = 0
foreach x in first_status second_status third_status fourth_status fifth_status {
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


* frame copy default precollapse, replace 



bysort ssuid_spanel_pnum_id status_1_lim: egen tpearn_s1 = mean(tpearn) if status_1_lim == employment_type
bysort ssuid_spanel_pnum_id: carryforward tpearn_s1, replace 
bysort ssuid_spanel_pnum_id status_2_lim: egen tpearn_s2 = mean(tpearn) if status_2_lim == employment_type
bysort ssuid_spanel_pnum_id: carryforward tpearn_s2, replace 

bysort ssuid_spanel_pnum_id status_3_lim: egen tpearn_s3 = mean(tpearn) if status_3_lim == employment_type
bysort ssuid_spanel_pnum_id: carryforward tpearn_s3, replace 

/***
<html>
<body>
<h1>Analysis/h1>
***/

table erace if unique_tag ==1 
table erace status_2 if unique_tag ==1 & status_1 == 4 
table erace status_2 if unique_tag ==1 & status_1 == 4, statistic(mean tpearn_s2)
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2), by(status_2)
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2) & erace ==1 , by(status_2)
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2) & erace ==2 , by(status_2)



// use this method and a reshape if we decide to track more statuses 
// collapse (mean) tpearn, by(ssuid_spanel_pnum_id status_1 status_2 status_3 status_1_lim status_2_lim status_3_lim erace) cw


