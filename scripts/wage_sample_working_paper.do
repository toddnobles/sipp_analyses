clear all 
eststo clear 

/* use for running off SSD 
local homepath "/Volumes/Extreme SSD/SIPP Data Files/"
local datapath "`homepath'/dtas"


cd "`datapath'"
*/

cd "/Users/toddnobles/Documents/sipp_analyses/outputs"
set linesize 255

**# Data import
use "../sipp_reshaped_work_comb_imputed", clear  

// bringing in monthly level data 
merge m:1 ssuid_spanel_pnum_id spanel swave monthcode using "../sipp_monthly_combined"
sort ssuid_spanel_pnum_id spanel swave monthcode 

// These non-merges appear to be those that are out of the working age population, or were just never employed during the time so don't have job data. 

// filtering to population of interest
keep if tage>=18 & tage<=64

**# Creating main job flag<
gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 
keep if jb_main ==1 // gets us one record for each month with their main job or that they were unemployed 


// Unemployment flag is 0 = not unemployed and 1 = unemployed for 2014 panel. Then switches to 2 = not unemployed and 1 = unemployed for 2018 onwards. So recoding accordingly here 
recode enjflag (1=1 unemployed) (2=0 no), into(unemployed_flag)

// dropping those who never worked in our dataset
bysort ssuid_spanel_pnum_id: egen sum_enjflag = sum(unemployed_flag)
bysort ssuid_spanel_pnum_id: gen num_records = _N
drop if sum_enjflag == num_records

/*** creating lenient employment type flag ***/
**# employment type flag 
gen employment_type1 = 1 if ejb_jborse == 1 // W&S
replace employment_type1 = 2 if ejb_jborse == 2 // SE
replace employment_type1 = 3 if ejb_jborse == 3 // other 
replace employment_type1 = 4 if ejb_jborse == . & unemployed_flag == 1
codebook employment_type1


unique ssuid_spanel_pnum_id swave monthcode // person month level file here. So we only have one job per month and it's their main job 
unique ssuid_spanel_pnum_id swave // person years
isid ssuid_spanel_pnum_id swave monthcode // double checking 


/// at this point we have a person-month level file with an employment status for them for each period captured in employment_type 
egen tag = tag(ssuid_spanel_pnum_id employment_type1)
su tag
bysort ssuid_spanel_pnum_id: egen tag_sum = sum(tag)
unique ssuid_spanel_pnum_id
unique ssuid_spanel_pnum_id if tag_sum >1 // gives us count of people who changed at some point 

label define employment_types 1 "W&S" 2 "SE" 3 "Other" 4 "Unemp"
label values employment_type1 employment_types


**# Cleaning up demographic variables 
gen age = tage
gen age2=age^2
label variable age2 "Age squared"

tab ems
rename ems mari_status
label variable mari_status "Marital status"


recode tceb (1/7=1 "Parent") (0=0 "No children"), gen(parent)
tab tceb parent
label variable parent "Parent"

codebook tjb_ind
destring tjb_ind, generate(industry1)
des tjb_ind industry1

//drop if industry1 == 170 // dropping agriculture/farming
//drop if industry1 == 180 // dropping agriculture/farming

recode industry1 (0010/0560=1  "Forestry, Farming, Fishing and Hunting, and Mining") ///
(0770/1060=2  Construction) ///
(1070/4060=3 Manufacturing) ///
(4070/4660=4  "Wholesale Trade") ///
(4670/6060=5  "Retail Trade") ///
(6070/6460 0570/0760=6 "Transportation and Warehousing, and Utilities") ///
(6470/6860=7  Information) ///
(6870/7260=8  "Finance and Insurance,  and Real Estate and Rental and Leasing") ///
(7270/7790=9  "Professional, Scientific, and Management, and  Administrative and Waste Management Services") ///
(7860/8490=10  "Educational Services, and Health Care and Social Assistance") ///
(8560/8690=11  "Arts, Entertainment, and Recreation, and  Accommodation and Food Services") ///
(8770/9290=12  "Other Services (except Public Administration)") ///
(9370/9590=13  "Public Administration") ///
(9890=15 Military), gen(industry2)

label variable industry2 "Industry"
recode eorigin (1 = 1 "Hispanic") (2 = 0 "Not Hispanic"), gen(hispanic)
label variable hispanic "Hispanic"
tab hispanic eorigin


label variable erace "Race"
label define race_label	 1 "White" 2 "Black" 3 "Asian" 4 "Residual"
label values erace race_label 
tab hispanic erace 

// check of race variable 
egen race_tag = tag(ssuid_spanel_pnum_id erace)
bysort ssuid_spanel_pnum_id: egen race_tag_sum = sum(race_tag)
unique ssuid_spanel_pnum_id if race_tag_sum > 1
unique ssuid_spanel_pnum_id

// according to the above, 1109 people changed the race they considered themself sometime in our data 
sort ssuid_spanel_pnum_id swave monthcode
list ssuid_spanel_pnum_id spanel swave monthcode erace race_tag_sum if race_tag_sum >1 in 1/10000, sepby(ssuid_spanel_pnum_id)

// addressing instances where erace is not constant within individuals 
* list ssuid_spanel_pnum_id  ssuid spanel pnum shhadid swave monthcode erace initial_race if race_tag_sum >1, sepby(ssuid_spanel_pnum_id)
bysort ssuid_spanel_pnum_id (swave monthcode): gen initial_race = erace[1]
label values initial_race race_label 
label variable initial_race "Race"

egen hisp_tag = tag(ssuid_spanel_pnum_id hispanic)
bysort ssuid_spanel_pnum_id: egen hisp_tag_sum = sum(hisp_tag)
unique ssuid_spanel_pnum_id if hisp_tag_sum > 1

bysort ssuid_spanel_pnum_id (swave monthcode): gen initial_hisp = hispanic[1]
label define hisp_label 1 "Hispanic" 0 "Not Hispanic"
label values initial_hisp hisp_label
label variable initial_hisp "Hispanic"

gen combine_race_eth = 1 if initial_race == 1 & initial_hisp == 0 
replace combine_race_eth = 2 if initial_race == 2 & initial_hisp == 0
replace combine_race_eth = 3 if initial_race == 3 & initial_hisp == 0 
replace combine_race_eth = 5 if initial_race == 4 & initial_hisp == 0
replace combine_race_eth = 4 if initial_hisp == 1 

label define combine_race_eth_label 1 "White" 2 "Black" 3 "Asian" 4 "Hispanic" 5 "Other"
label values combine_race_eth combine_race_eth_label

tab combine_race_eth initial_race, missing
tab combine_race_eth initial_hisp, missing
table (initial_hisp initial_race) combine_race_eth, missing

// creating collapsed verison of race/ethnicity variable
gen race_collapsed = 1 if combine_race_eth == 1
replace race_collapsed = 2 if combine_race_eth == 2 | combine_race_eth == 3 | combine_race_eth == 4 | combine_race_eth == 5
label variable race_collapsed "Race/Ethnicity"
label define rlab 1 "White" 2 "Non-White"
label values race_collapsed rlab

// creating collapsed version of education variable 
gen educ_collapsed = 1 if educ3 ==1
replace educ_collapsed =2 if educ3 == 2 
replace educ_collapsed = 3 if educ3 == 3 
replace educ_collapsed = 3 if educ3 == 4 

label variable educ_collapsed "Education"
label define educ_lab_collapsed 1 "HS or Less" 2 "Some College or Assoc." 3 "4-year Degree or more" 
label values educ_collapsed educ_lab_collapsed


// Generating month and calendar year variables 
bysort ssuid_spanel_pnum_id (swave monthcode): gen month_individ = _n 
gen calyear = 2013 if spanel == 2014 & swave == 1
replace calyear = 2014 if spanel == 2014 & swave == 2 
replace calyear = 2015 if spanel == 2014 & swave == 3
replace calyear = 2016 if spanel == 2014 & swave == 4
replace calyear = 2017 if spanel == 2018 & swave == 1
replace calyear = 2018 if spanel == 2018 & swave == 2
replace calyear = 2019 if spanel == 2018 & swave == 3
replace calyear = 2020 if spanel == 2018 & swave == 4
replace calyear = 2018 if spanel == 2019 & swave == 1
replace calyear = 2019 if spanel == 2020 & swave == 1
replace calyear = 2020 if spanel == 2020 & swave == 2
replace calyear = 2021 if spanel == 2020 & swave == 3
replace calyear = 2022 if spanel == 2020 & swave == 4
replace calyear = 2020 if spanel == 2021 & swave == 1


egen unique_tag = tag(ssuid_spanel_pnum_id) // unique id


// oddly we are losing a number of people through parent not being consistent, 
bysort ssuid_spanel_pnum_id (month_individ): gen parent_change = parent != parent[_n-1]
bysort ssuid_spanel_pnum_id (month_individ): replace parent_change = 0 if _n == 1


bysort ssuid_spanel_pnum_id (month_individ): replace parent =1 if parent[_n-1] == 1  & parent == . // we can carryforward that they're a parent in an earlier year as this question is just whether they've had a kid not about their current dependents. 

// we can also replace it if we have their status as not a parent at the beginning and end of their observations
bysort ssuid_spanel_pnum_id (month_individ): gen first_parent = parent if _n == 1
bysort ssuid_spanel_pnum_id (month_individ): gen last_parent = parent if _n ==_N
bysort ssuid_spanel_pnum_id (month_individ): carryforward first_parent, replace 
gsort ssuid_spanel_pnum_id -month_individ	
by ssuid_spanel_pnum_id: carryforward last_parent, replace  

list swave spanel month_individ tjb_mwkhrs employment_type1  parent*  tceb first_parent last_parent  if ssuid_spanel_pnum_id  == 86076
list swave spanel month_individ tjb_mwkhrs employment_type1  parent*  tceb first_parent last_parent  if ssuid_spanel_pnum_id  == 28734
replace parent = 0 if first_parent == 0 & last_parent == 0 // now we've replaced those instances where we have confirmation someone earlier reported being a parent, then there are blanks, then we know they are 


list swave spanel month_individ tjb_mwkhrs employment_type1  parent*  tceb first_parent last_parent  if ssuid_spanel_pnum_id  == 86076
list swave spanel month_individ tjb_mwkhrs employment_type1  parent*  tceb first_parent last_parent  if ssuid_spanel_pnum_id  == 28734







**# Flags for unemployment during first 12 months 
*---------------------------------------------------------------------------|
/*
max_consec_unempf12 gives us the length of longest unemployment spell during the first 12 months. months_unempf12 gives us the total number of months unemployed during first 12 months</
*/
frame copy default earnings, replace
frame change earnings 

bysort ssuid_spanel_pnum_id: gen months_in_data = _N
drop if months_in_data < 12
bysort ssuid_spanel_pnum_id: egen months_unempf12=  count(month_individ) if (employment_type1 == 4 & month_individ <=12) // doesn't account for non-consecutive issues 
by ssuid_spanel_pnum_id: egen months_unempf12_max = max(months_unempf12)if month_individ 
drop months_unempf12
rename months_unempf12_max months_unempf12
replace months_unempf12 = 0 if months_unempf12 == . 

gen unemp_month = 1 if employment_type1 == 4  
replace unemp_month = . if month_individ >12

tsset ssuid_spanel_pnum_id month_individ
tsspell unemp_month 
replace _seq = . if month_individ > 12 
replace _seq = . if employment_type != 4
by ssuid_spanel_pnum_id: egen max_consec_unempf12= max(_seq)
replace max_consec_unempf12 = 0 if max_consec_unempf12 == . 
list month_individ employment_type months_unempf12 unemp_month _s* _end max_*  if ssuid_spanel_pnum_id  ==   199821 
tsset, clear 

count if max_consec_unempf12 >=1 & unique_tag ==1 
count if max_consec_unempf12 >=3 & unique_tag ==1
count if max_consec_unempf12 >=6 & unique_tag ==1
tab max_consec_unempf12 months_unempf12 if unique_tag ==1
  

gen unempf12_1 = 1 if max_consec_unempf12 >=1
gen unempf12_3 = 1 if max_consec_unempf12 >=3
gen unempf12_6 = 1 if max_consec_unempf12 >=6 

foreach var of varlist unempf12_1 unempf12_3 unempf12_6 {
	replace `var' = 0 if `var' == . 
}



bysort ssuid_spanel_pnum_id: egen pt_time_months = count(ssuid_spanel_pnum_id) if tjb_mwkhrs < 15 & month_individ >12

bysort ssuid_spanel_pnum_id: egen pt_time_months_max = max(pt_time_months) 
replace pt_time_months_max = 0 if pt_time_months_max == . 
tab pt_time_months_max if unique_tag == 1, miss
count if pt_time_months_max > 0 & unique_tag == 1

gen pct_pt_time_months = pt_time_months_max/months_in_data
tab pct_pt_time_months if unique_tag == 1
summ pct_pt_time_months if unique_tag == 1














// we want their most common status during first 12 months, 
bysort ssuid_spanel_pnum_id (month_individ): egen mode_status_f12v1 = mode(employment_type1) if month_individ <=12, minmode 
bysort ssuid_spanel_pnum_id (month_individ): egen mode_status_f12v2 = mode(employment_type1) if month_individ <= 12, maxmode 

bysort ssuid_spanel_pnum_id (month_individ): carryforward mode_status_f12v1 , replace
bysort ssuid_spanel_pnum_id (month_individ): carryforward mode_status_f12v2 , replace

*# there are a a handful of observations here where they don't have any valid observations of first year employment to dictate a new status here leading to the 156 missing obs. 

// what if we defined it as the modal status when employed and then override that with a flag for unemployed 3 consecutive
bysort ssuid_spanel_pnum_id: egen y1_status_v1 = mode(employment_type1) if month_individ <=12 & (employment_type1 == 1 | employment_type == 2 | employment_type == 3), maxmode
bysort ssuid_spanel_pnum_id (month_individ): carryforward y1_status_v1, replace 
replace y1_status_v1 = 4 if unempf12_3 == 1
gsort ssuid_spanel_pnum_id -month_individ
by ssuid_spanel_pnum_id: carryforward y1_status_v1, replace 
codebook y1_status_v1
unique ssuid_spanel_pnum_id if y1_status_v1 == . 
// 8 people who had no employment type during first year to base this off of 


// What if we did the same but reworked it to be 3 months unemployed but not consecutive 
bysort ssuid_spanel_pnum_id: egen y1_status_v2 = mode(employment_type1) if month_individ <= 12 & (employment_type1 == 1 | employment_type1 == 2 | employment_type1 == 3), maxmode
bysort ssuid_spanel_pnum_id (month_individ):carryforward y1_status_v2, replace
replace y1_status_v2 = 4 if months_unempf12 >= 3 
codebook y1_status_v2
gsort ssuid_spanel_pnum_id -month_individ
by ssuid_spanel_pnum_id: carryforward y1_status_v2, replace 
codebook y1_status_v2

// 8 people who had no employment type during first year to base this off of 
drop if y1_status_v2 == . 


// What does our data look like at this point? 
// At this point we still have months where people were employed < 15 hours and where they had "other" employment type. We now have two new indicator variables for their first year status. Rather than a strict modal status, we take their most common employment status of WS, SE, Other, breaking ties by max value (other =3, SE = 2, ws =1). Then we override the value for the first year status variable based on their unemployment experience. For instance, in y1_status_v1 if the person had 3 or more consecutive months of unemployment in year 1, their new value for y1_status_v1 becomes unemployed. In y1_status_v2, we relax the consecutive months requirement to mark someone as a first year status of unemployed if they experienced 3 months or more with unemployment spells, regardless of whether the months were consecutive. 
sort ssuid_spanel_pnum_id month_individ 
list ssuid_spanel_pnum_id month_individ employment_type1 y1_status_* tjb_mwkhrs tpearn in 1/100, abbrev(25)


// not a huge differenc here between the options
unique ssuid_spanel_pnum_id, by(y1_status_v1)
unique ssuid_spanel_pnum_id, by(y1_status_v2)
unique ssuid_spanel_pnum_id, by(mode_status_f12v2)


**# Quantifying self-employment after the first 12 months 
*---------------------------------------------------------------------------|
// measure of how many unemployed or employment months we observe this person after first 12 months
gen month_after12 = 1 if month_individ > 12 
bysort ssuid_spanel_pnum_id: egen months_after_12 = total(month_after12) 
drop if months_after_12 == 0 // don't care about people who we only have for 12 months 
keep if mod(months_after_12, 12) == 0 // dropping the 5.86 percent of observations that don't have full years of observations for us to track them

list ssuid_spanel_pnum_id month_individ employment_type1  if ssuid_spanel_pnum_id  ==181353

// creating a measure of how many months we observe them after 12 but full-time employment only. 
gen month_after12_ft = 1 if month_individ > 12 & tjb_mwkhrs >= 15 & employment_type != 4 & tjb_mwkhrs != .  
bysort ssuid_spanel_pnum_id (month_individ): egen months_after_12_ft = total(month_after12_ft)

// pct of Self employed months after 12 months 
gen self_emp_month = 1 if month_individ >12 & employment_type1 == 2
bysort ssuid_spanel_pnum_id: egen months_se_after_12 = total(self_emp_month)
gen pct_se_after_12 = months_se_after_12/months_after_12

// full-time only version 
gen self_emp_month_ft = 1 if month_individ > 12 & employment_type1 == 2 & tjb_mwkhrs >=15 & tjb_mwkhrs != .  
bysort ssuid_spanel_pnum_id: egen months_se_after_12_ft = total(self_emp_month_ft)
gen pct_se_after_12_ft = months_se_after_12_ft/months_after_12_ft
replace pct_se_after_12_ft = 0 if pct_se_after_12_ft == . 

// pct of wage and salary months after 12 months 
gen ws_month = 1 if month_individ >12 & employment_type1 == 1
bysort ssuid_spanel_pnum_id: egen months_ws_after_12 = total(ws_month)
gen pct_ws_after_12 = months_ws_after_12/months_after_12

// full-time only version 
gen ws_month_ft = 1 if month_individ > 12 & employment_type == 1 & tjb_mwkhrs >=15  & tjb_mwkhrs != .  
bysort ssuid_spanel_pnum_id: egen months_ws_after_12_ft = total(ws_month_ft)
gen pct_ws_after_12_ft = months_ws_after_12_ft/months_after_12_ft
replace pct_ws_after_12_ft = 0 if pct_ws_after_12_ft == . 

list ssuid_spanel_pnum_id month_individ tjb_mwkhrs employment_type1 pct_ws_after* pct_se_after* if ssuid_spanel_pnum_id  ==   200798 , abbrev(15)

list ssuid_spanel_pnum_id month_individ tjb_mwkhrs employment_type1 months_after_12 months_after_12_ft months_se_* months_ws_*  if ssuid_spanel_pnum_id  ==   200798 , abbrev(12)

list ssuid_spanel_pnum_id month_individ tjb_mwkhrs employment_type1 months_after_12 months_after_12_ft months_se_* months_ws_*  if ssuid_spanel_pnum_id  ==    200731 , abbrev(12)

// based on the above, if we filtered to those with pct_se_after_12_ft >=.5 then we would have those that were Self employed for 50% of the months that they were full-time employed. What we want instead is to get those who were full-time employed for the full period after month 12 and were SE for a particular percent of those months. So, we need to adjust the denominator of those variables (could also do with a pre-filtering of sorts to only those who were )

// We'll filter to those that are only full-time employed (in any employment) after month 12. 
unique ssuid_spanel_pnum_id
drop if months_after_12 != months_after_12_ft
drop if months_after_12 == 0 
unique ssuid_spanel_pnum_id


foreach var of varlist  mode*  y1_status_* {
	label values `var' employment_types
}
compress 


// getting rid of people who start off as "Other" employment type
drop if y1_status_v2 == 3 


count if employment_type1 == 3 // currently we still have employment records that are for "other" employment. They will get filtered out below
unique ssuid_spanel_pnum_id if employment_type1 == 3 



local logdate : di %tdCYND daily("$S_DATE", "DMY")
label variable unempf12_6 "Unemployed 6-months"
label variable calyear "Year"
label variable immigrant "Immigrant"
label define immigrant_labels 1 "Immigrant" 0 "Native Born"
label  values immigrant immigrant_labels




// cleaning up missings of key demographic variables 
foreach var of varlist unempf12_6 y1_status* educ_collapsed combine_race_eth sex age immigrant  calyear parent mari_status {
	unique ssuid_spanel_pnum_id if `var' == . 
	drop if `var' == . 
}




list month_individ employment_type1 pct_se_after_12_ft industry2 if ssuid_spanel_pnum_id == 181353, abbrev(20)

drop if industry2 == . & month_individ > 12 // Earlier we dropped those that were not full-time employed during the period from month 12 onwards. Here we need to make sure that they also have industry information for those months. If we only dropped where industry2 ==. then we'd also drop the first year for people that were unemployed during the first 12 months, which we don't want to do quite yet. 
list month_individ employment_type1 pct_se_after_12_ft industry2 if ssuid_spanel_pnum_id == 181353, abbrev(20)


// We still need to address the "other" employment records. We only want people who were full-time employed in self-employment or wage and salary employed from month 12 onwards. It can be a combination of these, since we've lowered our threshold of pct_se_after_12. 
gen sumpcts = pct_se_after_12_ft + pct_ws_after_12_ft
unique ssuid_spanel_pnum_id if sumpcts < 1
gen other_after_12 = 1 if month_individ > 12 & employment_type1 == 3 
bysort ssuid_spanel_pnum_id: egen tot_other_after_12 =total(other_after_12)
unique ssuid_spanel_pnum_id if tot_other_after_12 >0 


list month_individ employment_type1 tot_other_after_12 if ssuid_spanel_pnum_id == 200585, abbrev(20)

drop if tot_other_after_12 >0 




/*
Evaluating what we have 
 We now have a dataset with the following flags and measures:
	- Sample restricted to those who were of working age 	
	- Monthly level earnings from all sources in tpearn and and from their main job in tjb_msum) 
	- "mode_status_f12v1" is the most common that person held during the first 12 months and breaks ties by taking the min value (prioritizes employment)
	- "mode_status_f12v2" is the same as above, but takes the max mode so prioritizes unemployment in tie breaking 
	- pct_se_after_12 captures the share of months after the 12 month entry window that someone was self-employed. 
	- yr1_status vars that capture the modal employment status that is trumped by unemployment of three months 

We also have flags for unemployment during the first 12 months: 
	- months_unempf12 gives us the total number of months unemployed during first 12 months 
	- max_consec_unempf12 gives us the maximum consecutive spell of unemployment a person experienced 
	- unempf12_1, unempf12_3, unempf12_6 are flags indicating whether that person experienced at least 1, 3, or 6 months of consecutive unemployment in the first 12 month window we observe them. 

***/



**# Collapsing to yearly values for earnings 
*-------------------------------------------------------------------------------|
* switching to new dataframe for producing annual estimates for descriptive tables 
frame copy earnings annual_earnings, replace 
frame change annual_earnings 

// filtering to our WS sample. 
keep if pct_ws_after_12_ft >= 1

// For making a table at the person level we need a single industry to assign them to. 
bys ssuid_spanel_pnum_id: egen mode_industry=mode(industry2), minmode

// collapsing to person year 
collapse (sum) tpearn tjb_msum (max) educ3 educ_collapsed (first) mode_industry age (count) n_months = tpearn (mean) tjb_mwkhrs, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth race_collapsed immigrant sex pct_se_after_12* unempf12_6  unempf12_3 months_unempf12 months_after_12* pct_ws_after_12* y1_status* calyear)

// at this point have a file that is collapsed to person-per year with their total earnings in tpearn and tjb_sum per year


bysort ssuid_spanel_pnum_id (calyear): drop if _n == 1 // drop first year for each person as that's the year we're establishing status based on
bysort ssuid_spanel_pnum_id (calyear): gen year_in_data = _n

// collapsing once more to mirror the monthly earnings analysis where we can produce a table that n-counts match the individuals that fall in that group
collapse (mean) tpearn tjb_msum (max) educ3 educ_collapsed year_in_data (first) mode_industry  age (count) n_years = tpearn (mean) tjb_mwkhrs, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth  race_collapsed immigrant sex pct_se_after_12* unempf12_6 unempf12_3  months_unempf12 pct_ws_after_12* months_after* y1_status*)


label variable sex "Sex"
label variable age "Age"
label values immigrant immigrant_labels
label variable immigrant "Immigrant"


label define industry_labels ///
1  "Forestry, Farming, Fishing, and Mining" ///
2  "Construction" ///
3  "Manufacturing" ///
4  "Wholesale Trade" ///
5  "Retail Trade" ///
6  "Transportation and  Utilities" ///
7  "Information" ///
8  "Finance and Real Estate" ///
9  "Professional Services" ///
10  "Educational Health and Social Service" ///
11  "Arts, Entertainment, and Recreation" ///
12  "Other Services (except Public Administration)" ///
13  "Public Administration" ///
15  "Military"

label values mode_industry industry_labels 
label variable mode_industry "Industry"
label variable tpearn "Mean Annual Earnings"
gen tpearn_med = tpearn 
label variable tpearn_med "Median Annual Earnings"
label  values immigrant immigrant_labels
label define mode_status_labels 1 "Wage & Salary" 2 "Self-Employed" 4 "Unemployed"
label values mode_status_f12v2 mode_status_labels

label define y1_status_labs 1 "Wage & Salary" 2 "Self-Employed" 3 "Other" 4 "Unemployed"
label values y1_status_v1 y1_status_labs 
label values y1_status_v2 y1_status_labs
label variable race_collapsed "Race/Ethnicity"
label values race_collapsed rlab
label values educ_collapsed educ_lab_collapsed
label variable educ_collapsed "Education"



/* Wage-and-salary sample and prior employment status. This is to test whether prior self-employment status is associated with an earning premium.
When doing the analysis for the wage-and-salary sample, please do the following.
Use the three-category independent variable, prior status (unemployed, W&S, SE), and use W&S as the reference category. For the interactions between prior employment status and race and gender variables, you may need to create dummy variables for each prior employment status category (e.g., unemployed=1, other=0; SE=1, other=0. If you do that in Stata, W&S automatically becomes the reference category. Please double check).
Again, graph any significant interaction estimates.
*/




**# Table 1
*------------------------------------------------------------------------------|

dtable tpearn tpearn_med i.sex i.race_collapsed i.educ3 i.immigrant i.mode_industry, by(y1_status_v2) ///
sample(, statistics(freq) place(seplabels)) ///
	continuous(tpearn_med, statistics(median)) /// 
	sformat("(N=%s)" frequency) nformat(%7.0f mean sd) ///
	column(by(hide) total("Full Sample")) ///
	title(Table 1. Descriptive Statistics for Wage and Salary Sample by Initial Employment Status)
	
collect export wage_earners_`logdate'.xlsx, sheet(Table 1) replace




// setting some macros for loops below 
local educ_comparisons 2vs1.educ3 3vs1.educ3 4vs1.educ3 
local educ_list 1.educ3 2.educ3 3.educ3 4.educ3
local race_comparisons 2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth
local race_list 1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth

**# Table 2 Annual Earnings Comparisons by Race/Ethnicity and Initial Employment Status (Wage/Salary Sample)
*------------------------------------------------------------------------------|
collect clear
// Define  local macros with the status values and corresponding labels we want to loop through
local statuses "1 2 4"
local labels "salaried self_employed unemployed_start"

// Loop over the two lists 
forvalues i = 1/3 {
    // Get the status value and the corresponding label using the counter
    local status : word `i' of `statuses'
    local label : word `i' of `labels'

    local collection_name = strtoname("`label'")

    collect create `collection_name', replace
    
    quietly: pwmean tpearn if y1_status_v2 == `status', over(combine_race_eth) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[`race_list'])
    collect remap rowname[b] = values[lev2], fortags(colname[`race_comparisons'])
    collect remap rowname[se] = values[lev3], fortags(colname[`race_comparisons'])
    
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (combine_race_eth) (values)
}



// combine them into one 
collect combine newc =  salaried self_employed unemployed_start, replace 
collect label levels collection salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 2 Annual Earnings Comparisons by Race/Ethnicity, Sex, Education and Initial Employment Status (Wage/Salary Sample)"
collect notes "Note: Initial employment status is determined by individuals' most common employment status during first 12 months they are observed in the data. Wage-and-salary refers to individuals who were continuously employed in wage or salary positions from month 13th  onwards. Mean earnings are calculated as a grand mean of person-level average annual earnings. T-tests run comparing average annual earnings using Dunnett multiple comparison correction"
collect style cell values, nformat(%6.0f)
collect preview
collect export wage_earners_`logdate'.xlsx, sheet(Table 2, replace) modify

collect create Full_Sample, replace 
quietly: pwmean tpearn, over(y1_status_v2) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], ///
	fortags(colname[1.y1_status_v2 2.y1_status_v2 4.y1_status_v2])
collect remap rowname[b] = values[lev2], ///
	fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])
collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout  (values) ( y1_status_v2) ()
collect style cell values, nformat(%6.0f)
collect export wage_earners_`logdate'.xlsx, sheet(Table 2) cell(M1) modify

**# Table 2.Sex: Annual Earnings Comparisons by Sex and Initial Employment Status (Wage/Salary Sample)
*------------------------------------------------------------------------------|
collect clear
// Define  local macros with the status values and corresponding labels we want to loop through
local statuses "1 2 4"
local labels "salaried self_employed unemployed_start"

// Loop over the two lists 
forvalues i = 1/3 {
    // Get the status value and the corresponding label using the counter
    local status : word `i' of `statuses'
    local label : word `i' of `labels'

    local collection_name = strtoname("`label'")

    collect create `collection_name', replace
    
    quietly: pwmean tpearn if y1_status_v2 == `status', over(sex) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[0.sex 1.sex])
    collect remap rowname[b] = values[lev2], fortags(colname[1vs0.sex])
    collect remap rowname[se] = values[lev3], fortags(colname[1vs0.sex])
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (sex) (values)
}



// combine them into one 
collect combine newc =  salaried self_employed unemployed_start, replace 
collect label levels collection salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (sex) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 2 Annual Earnings Comparisons by Sex and Initial Employment Status (Wage/Salary Sample)"
collect style cell values, nformat(%6.0f)
collect preview
collect export wage_earners_`logdate'.xlsx, sheet(Table 2) cell(A11) modify


**# Table 2.Education: Annual Earnings Comparisons by Education and Initial Employment Status (Wage/Salary Sample)
*------------------------------------------------------------------------------|

local educ_comparisons 2vs1.educ3 3vs1.educ3 4vs1.educ3 
local educ_list 1.educ3 2.educ3 3.educ3 4.educ3 

collect clear
// Define  local macros with the status values and corresponding labels we want to loop through
local statuses "1 2 4"
local labels "salaried self_employed unemployed_start"

// Loop over the two lists 
forvalues i = 1/3 {
    // Get the status value and the corresponding label using the counter
    local status : word `i' of `statuses'
    local label : word `i' of `labels'

    local collection_name = strtoname("`label'")

    collect create `collection_name', replace
    
    quietly: pwmean tpearn if y1_status_v2 == `status', over(educ3) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[`educ_list'])
    collect remap rowname[b] = values[lev2], fortags(colname[`educ_comparisons'])
    collect remap rowname[se] = values[lev3], fortags(colname[`educ_comparisons'])
    
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (educ3) (values)
}
// combine them into one 
collect combine newc =  salaried self_employed unemployed_start, replace 
collect label levels collection salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (educ3) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 2 Annual Earnings Comparisons by Education and Initial Employment Status (Wage/Salary Sample)"
collect style cell values, nformat(%6.0f)
collect preview
collect export wage_earners_`logdate'.xlsx, sheet(Table 2) cell(A18) modify


dtable i.combine_race_eth i.sex i.educ3, by(y1_status_v2)
collect export wage_earners_`logdate'.xlsx, sheet(Table 2) cell(M8) modify




**# Running collapsed version of tables
local race_comparisons 2vs1.race_collapsed
local race_list 1.race_collapsed 2.race_collapsed
local educ_comparisons 2vs1.educ_collapsed 3vs1.educ_collapsed  
local educ_list 1.educ_collapsed 2.educ_collapsed 3.educ_collapsed


**# Table 2 Collapsed Annual Earnings Comparisons by Race/Ethnicity and Initial Employment Status (Wage/Salary Sample)
*------------------------------------------------------------------------------|
collect clear
// Define  local macros with the status values and corresponding labels we want to loop through
local statuses "1 2 4"
local labels "salaried self_employed unemployed_start"

// Loop over the two lists 
forvalues i = 1/3 {
    // Get the status value and the corresponding label using the counter
    local status : word `i' of `statuses'
    local label : word `i' of `labels'

    local collection_name = strtoname("`label'")

    collect create `collection_name', replace
    
    quietly: pwmean tpearn if y1_status_v2 == `status', over(race_collapsed) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[`race_list'])
    collect remap rowname[b] = values[lev2], fortags(colname[`race_comparisons'])
    collect remap rowname[se] = values[lev3], fortags(colname[`race_comparisons'])
    
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (race_collapsed) (values)
}



// combine them into one 
collect combine newc =  salaried self_employed unemployed_start, replace 
collect label levels collection salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (race_collapsed) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 2 Annual Earnings Comparisons by Race/Ethnicity, Sex, Education and Initial Employment Status (Wage/Salary Sample)"
collect notes "Note: Initial employment status is determined by individuals' most common employment status during first 12 months they are observed in the data. Wage-and-salary refers to individuals who were continuously employed in wage or salary positions from month 13th  onwards. Mean earnings are calculated as a grand mean of person-level average annual earnings."
collect style cell values, nformat(%6.0f)
collect preview
collect export wage_earners_`logdate'.xlsx, sheet(Table 2 Collapsed, replace) modify

collect create Full_Sample, replace 
quietly: pwmean tpearn, over(y1_status_v2) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], ///
	fortags(colname[1.y1_status_v2 2.y1_status_v2 4.y1_status_v2])
collect remap rowname[b] = values[lev2], ///
	fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])
collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout  (values) ( y1_status_v2) ()
collect style cell values, nformat(%6.0f)
collect export wage_earners_`logdate'.xlsx, sheet(Table 2 Collapsed) cell(M1) modify

**# Table 2.Sex: Annual Earnings Comparisons by Sex and Initial Employment Status (Wage/Salary Sample)
*------------------------------------------------------------------------------|
collect clear
// Define  local macros with the status values and corresponding labels we want to loop through
local statuses "1 2 4"
local labels "salaried self_employed unemployed_start"

// Loop over the two lists 
forvalues i = 1/3 {
    // Get the status value and the corresponding label using the counter
    local status : word `i' of `statuses'
    local label : word `i' of `labels'

    local collection_name = strtoname("`label'")

    collect create `collection_name', replace
    
    quietly: pwmean tpearn if y1_status_v2 == `status', over(sex) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[0.sex 1.sex])
    collect remap rowname[b] = values[lev2], fortags(colname[1vs0.sex])
    collect remap rowname[se] = values[lev3], fortags(colname[1vs0.sex])
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (sex) (values)
}



// combine them into one 
collect combine newc =  salaried self_employed unemployed_start, replace 
collect label levels collection salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (sex) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 2 Annual Earnings Comparisons by Sex and Initial Employment Status (Wage/Salary Sample)"
collect style cell values, nformat(%6.0f)
collect preview
collect export wage_earners_`logdate'.xlsx, sheet(Table 2 Collapsed) cell(A11) modify


**# Table 2.Education Collapsed: Annual Earnings Comparisons by Education and Initial Employment Status (Wage/Salary Sample)
*------------------------------------------------------------------------------|



collect clear
// Define  local macros with the status values and corresponding labels we want to loop through
local statuses "1 2 4"
local labels "salaried self_employed unemployed_start"

// Loop over the two lists 
forvalues i = 1/3 {
    // Get the status value and the corresponding label using the counter
    local status : word `i' of `statuses'
    local label : word `i' of `labels'

    local collection_name = strtoname("`label'")

    collect create `collection_name', replace
    
    quietly: pwmean tpearn if y1_status_v2 == `status', over(educ_collapsed) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[`educ_list'])
    collect remap rowname[b] = values[lev2], fortags(colname[`educ_comparisons'])
    collect remap rowname[se] = values[lev3], fortags(colname[`educ_comparisons'])
    
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (educ_collapsed) (values)
}
// combine them into one 
collect combine newc =  salaried self_employed unemployed_start, replace 
collect label levels collection salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (educ_collapsed) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 2 Annual Earnings Comparisons by Education and Initial Employment Status (Wage/Salary Sample)"
collect style cell values, nformat(%6.0f)
collect preview
collect export wage_earners_`logdate'.xlsx, sheet(Table 2 Collapsed) cell(A18) modify


dtable i.race_collapsed i.sex i.educ_collapsed, by(y1_status_v2)
collect export wage_earners_`logdate'.xlsx, sheet(Table 2 Collapsed) cell(M8) modify





**# Some Median summary stats
drop if y1_status_v2 == 4
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=.



// raw values 
table y1_status_v2, statistic(p25 tpearn) statistic(p50 tpearn) statistic(p75 tpearn) statistic(mean tpearn) statistic(sd tpearn)
collect export wage_earners_`logdate'.xlsx, sheet(Median TPEARN) cell(A1) modify


table race_collapsed y1_status_v2, statistic(p25 tpearn) statistic(p50 tpearn) statistic(p75 tpearn) statistic(mean tpearn) statistic(sd tpearn)
collect export wage_earners_`logdate'.xlsx, sheet(Median TPEARN) cell(A6) modify


table sex y1_status_v2, statistic(p25 tpearn) statistic(p50 tpearn) statistic(p75 tpearn) statistic(mean tpearn) statistic(sd tpearn)
collect export wage_earners_`logdate'.xlsx, sheet(Median TPEARN) cell(G6) modify



// logged values
table y1_status_v2, statistic(p25 ln_tpearn) statistic(p50 ln_tpearn) statistic(p75 ln_tpearn) statistic(mean ln_tpearn) statistic(sd ln_tpearn)
collect export wage_earners_`logdate'.xlsx, sheet(Median ln tpearn) cell(A1) modify


table race_collapsed y1_status_v2, statistic(p25 ln_tpearn) statistic(p50 ln_tpearn) statistic(p75 ln_tpearn) statistic(mean ln_tpearn) statistic(sd ln_tpearn)
collect export wage_earners_`logdate'.xlsx, sheet(Median ln tpearn) cell(A6) modify


table sex y1_status_v2, statistic(p25 ln_tpearn) statistic(p50 ln_tpearn) statistic(p75 ln_tpearn) statistic(mean ln_tpearn) statistic(sd ln_tpearn)
collect export wage_earners_`logdate'.xlsx, sheet(Median ln tpearn) cell(G6) modify












**# Models for initial status predicting earnings 
*------------------------------------------------------------------------------|
**# Regressions for earnings 
frame copy earnings earnings_models, replace 
frame change earnings_models

bys ssuid_spanel_pnum_id calyear: egen mode_industry_year =mode(industry2), minmode

collapse (sum) tpearn tjb_msum (max) educ3 educ_collapsed (first) mode_industry_year age (count) n_months = tpearn, by(ssuid_spanel_pnum_id y1_status_v2 combine_race_eth race_collapsed immigrant sex pct_se_after_12 unempf12_6 pct_ws_after_12_ft calyear parent mari_status)

bys ssuid_spanel_pnum_id: gen years_inc = _N
// Dropping first year for everyone as otherwise we don't have a fair comparison group for earnings. 
bysort ssuid_spanel_pnum_id (calyear): drop if _n == 1 


gen age2 = age^2
label variable age2 "Age squared"
label variable age "Age"
label values mode_industry_year industry_labels
label variable mode_industry_year "Industry"
label define educ_labs 1 "HS or Less" 2 "Some College or Assoc." 3 "4-year Degree" 4 "Graduate Degree" 
label variable educ3 "Education"
label values educ3 educ_labs
label values educ_collapsed educ_lab_collapsed
label variable educ_collapsed "Education"

/*
1. Married, spouse present
2. Married, spouse absent
3. Widowed
4. Divorced
5. Separated
6. Never married
*/
gen mari_status_collapsed = "Married" if mari_status == 1 | mari_status == 2 
replace mari_status_collapsed = "Divorced/Separated/Widowed" if mari_status == 3 | mari_status == 4 | mari_status == 5
replace mari_status_collapsed = "Never married" if mari_status == 6 



**# full ws employed after first year 
unique ssuid_spanel_pnum_id if pct_ws_after_12_ft  >= .75
unique ssuid_spanel_pnum_id if pct_ws_after_12_ft == 1 

// we don't gain many people by doing the .75 threshold at this point of filtering folks

keep if pct_ws_after_12_ft == 1 
drop if y1_status_v2 == 4

// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=.
xtset ssuid_spanel_pnum_id calyear 
global controls  = "i.sex age age2 i.immigrant  mode_industry_year calyear"
global ctrl_nosex = "age age2 i.immigrant  mode_industry_year calyear"


// ----------------------------------------------------------------------------------------
// This is the point I exported to R for analysis using linear quantile regressions. 
//----------------------------------------------------------------------------------------


// mode status regressions 
 xtreg ln_tpearn i.y1_status_v2, vce(robust) 

quietly xtreg ln_tpearn i.y1_status_v2 i.educ_collapsed $controls, vce(robust) 
eststo ws_earn_mode_m1
quietly xtreg ln_tpearn i.y1_status_v2 i.race_collapsed i.educ_collapsed $controls, vce(robust) 
eststo ws_earn_mode_m2
quietly xtreg ln_tpearn y1_status_v2##race_collapsed i.educ_collapsed $controls, vce(robust)
eststo ws_earn_mode_m3
quietly xtreg ln_tpearn y1_status_v2##sex i.race_collapsed i.educ_collapsed $ctrl_nosex, vce(robust)
eststo ws_earn_mode_m4

esttab ws_earn_mode??? using wage_earner_`logdate'.rtf, ///
	legend label ///
	title(Relationship between Initial Employment Status and Wage/Salary Earnings) ///
	varlabels(_cons Constant) compress onecell replace  


// throws error 
//xi:xtmdqr ln_tpearn i.y1_status_v2, re

// doesn't produce estimate 
//xi: qregpd ln_tpearn i.y1_status_v2 age, id(ssuid_spanel_pnum_id) fix(calyear)





// what if we ignore the panel structure
quietly qreg ln_tpearn i.y1_status_v2, vce(robust)
eststo median_reg1
quietly qreg ln_tpearn i.y1_status_v2 i.race_collapsed, vce(robust)
eststo median_reg2

quietly qreg ln_tpearn i.y1_status_v2 i.race_collapsed i.educ_collapsed, vce(robust)
eststo median_reg3

quietly qreg ln_tpearn i.y1_status_v2 i.race_collapsed i.educ_collapsed $controls, vce(robust)
eststo median_reg4


esttab median* using wage_earner_`logdate'.rtf, ///
	legend label ///
	title(Relationship between Initial Employment Status and Wage/Salary Earnings) ///
	varlabels(_cons Constant) compress onecell append  
