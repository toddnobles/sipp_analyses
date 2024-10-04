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
//use earnings_by_status, clear  
use "../sipp_reshaped_work_comb_imputed", clear  

// bringing in monthly level data 
merge m:1 ssuid_spanel_pnum_id spanel swave monthcode using "../sipp_monthly_combined"
sort ssuid_spanel_pnum_id spanel swave monthcode 
bysort ssuid_spanel_pnum_id: egen _merge_avg = mean(_merge)

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
label define educ_lab 1 "HS or Less" 2 "Some College or Assoc." 3 "4-year Degree or more" 
label values educ_collapsed educ_lab


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


// dropping military members as can't have self-employed military 
gen military_emp = 1 if industry2 == 15
bysort ssuid_spanel_pnum_id: egen military_emp_sum = total(military_emp)
drop if military_emp_sum > 0 



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
foreach var of varlist unempf12_6 y1_status* educ_collapsed combine_race_eth sex age immigrant  calyear{
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



unique ssuid_spanel_pnum_id if parent == ., by(y1_status_v2)



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

// filtering to our SE sample. 
keep if pct_se_after_12_ft >= .5

// For making a table at the person level we need a single industry to assign them to. 
bys ssuid_spanel_pnum_id: egen mode_industry=mode(industry2), minmode


// collapsing to person year 
collapse (sum) tpearn tjb_msum (max) educ_collapsed (first) mode_industry age (count) n_months = tpearn (mean) tjb_mwkhrs, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth race_collapsed immigrant sex pct_se_after_12* unempf12_6  unempf12_3 months_unempf12 months_after_12* pct_ws_after_12* y1_status* calyear)

// at this point have a file that is collapsed to person-per year with their total earnings in tpearn and tjb_sum per year


bysort ssuid_spanel_pnum_id (calyear): drop if _n == 1 // drop first year for each person as that's the year we're establishing status based on

bysort ssuid_spanel_pnum_id (calyear): gen year_in_data = _n

// collapsing once more to mirror the monthly earnings analysis where we can produce a table that n-counts match the individuals that fall in that group
collapse (mean) tpearn tjb_msum (max) educ_collapsed year_in_data (first) mode_industry  age (count) n_years = tpearn (mean) tjb_mwkhrs, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth race_collapsed immigrant sex pct_se_after_12* unempf12_6 unempf12_3  months_unempf12 pct_ws_after_12* months_after* y1_status*)


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
label values educ_collapsed educ_lab
label variable educ_collapsed "Education"









**# Table 1
*------------------------------------------------------------------------------|

dtable tpearn tpearn_med i.sex i.race_collapsed i.educ_collapsed i.immigrant i.mode_industry, by(y1_status_v2) ///
sample(, statistics(freq) place(seplabels)) ///
	continuous(tpearn_med, statistics(median)) /// 
	sformat("(N=%s)" frequency) nformat(%7.0f mean sd) ///
	column(by(hide) total("Full Sample")) ///
	title(Table 1. Descriptive Statistics for Self-Employed Sample by Initial Employment Status) ///
	note(This table contains information on those who from the 13th month of observation onwards were never unemployed and reported being self-employed for each month. Average earnings are grand means of individuals' average annual earnings for any type of employment. Median earnings are the median of individual average annual earnings. Excluded from sample are those who dropped out of the SIPP sample after only one year of participation, months where individuals worked fewer than 15 hours, and "Other" employment types besides self-employed or wage and salaried.)
	
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 1) replace




// setting some macros for loops below 
local race_comparisons 2vs1.race_collapsed
local race_list 1.race_collapsed 2.race_collapsed
local educ_comparisons 2vs1.educ_collapsed 3vs1.educ_collapsed  
local educ_list 1.educ_collapsed 2.educ_collapsed 3.educ_collapsed


**# Table 2	Annual Earnings Comparisons by Race/Ethnicity and Initial Employment Status (Self-Employed Sample)
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
collect combine newc = salaried self_employed unemployed_start, replace 
collect label levels collection salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (race_collapsed) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 2. Annual Earnings Comparisons by Race/Ethnicity, Sex, Education and Initial Employment Status (Self-Employed Sample)"
collect notes "Note: Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Self-Employed refers to those who were continuously self-employed from month 13 onwards. Mean earnings are calculated as a grand mean of person level average annual earnings. T-tests run comparing average annual earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%6.0f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2, replace) modify

collect create Full_Sample, replace 
quietly: pwmean tpearn, over(y1_status_v2) mcompare(dunnett) //already filtered to pct_se_after_12 == .5 above
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.y1_status_v2 2.y1_status_v2 4.y1_status_v2])
collect remap rowname[b] = values[lev2],fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])
collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout  (values) ( y1_status_v2) ()
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2) cell(M1) modify





**# Table 2. Sex: Annual Earnings Comparisons by Sex and Initial Employment Status (Self-Employed Sample)
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
collect title "Table 2 Annual Earnings Comparisons by Sex and Initial Employment Status (Self-Employed Sample)"
collect style cell values, nformat(%6.0f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2) cell(A11) modify


**# Table 2 Annual Earnings Comparisons by Education and Initial Employment Status 
*---------------------------------------------------------------------------------------|
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
collect title "Table 2 Annual Earnings Comparisons by Education and Initial Employment Status (Self Employed Sample)"
collect style cell values, nformat(%6.0f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2) cell(A18) modify


dtable i.race_collapsed i.sex i.educ_collapsed, by(y1_status_v2)
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2) cell(m8) modify







**# Regressions for earnings 
frame copy earnings earnings_models
frame change earnings_models

bys ssuid_spanel_pnum_id calyear: egen mode_industry_year =mode(industry2), minmode

collapse (sum) tpearn tjb_msum (max) educ_collapsed (first) mode_industry_year age (count) n_months = tpearn, by(ssuid_spanel_pnum_id y1_status_v2 combine_race_eth race_collapsed immigrant sex pct_se_after_12 unempf12_6 pct_ws_after_12 calyear)


// Dropping first year for everyone as otherwise we don't have a fair comparison group for earnings. 
bysort ssuid_spanel_pnum_id (calyear): drop if _n == 1 


gen age2 = age^2
label variable age2 "Age squared"
label variable age "Age"
label values mode_industry_year industry_labels
label variable mode_industry_year "Industry"
label values educ_collapsed educ_lab



// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=.
xtset ssuid_spanel_pnum_id calyear 
global controls  = "i.sex age age2 i.immigrant  mode_industry_year calyear"
global ctrl_nosex = "age age2 i.immigrant  mode_industry_year calyear"

// regressions for full-sample
quietly xtreg ln_tpearn i.unempf12_6 i.educ_collapsed $controls, vce(robust) 
eststo any_earn_unemp_m1 
quietly xtreg ln_tpearn i.unempf12_6 i.race_collapsed i.educ_collapsed $controls, vce(robust) 
eststo any_earn_unemp_m2
quietly xtreg ln_tpearn unempf12_6##race_collapsed i.educ_collapsed $controls, vce(robust)
eststo any_earn_unemp_m3
quietly xtreg ln_tpearn unempf12_6##sex i.race_collapsed i.educ_collapsed $ctrl_nosex, vce(robust)
eststo any_earn_unemp_m4


// mode status regressions 
quietly xtreg ln_tpearn i.y1_status_v2 i.educ_collapsed $controls, vce(robust) 
eststo any_earn_mode_m1
quietly xtreg ln_tpearn i.y1_status_v2 i.race_collapsed i.educ_collapsed $controls, vce(robust) 
eststo any_earn_mode_m2
quietly xtreg ln_tpearn y1_status_v2##race_collapsed i.educ_collapsed $controls, vce(robust)
eststo any_earn_mode_m3
quietly xtreg ln_tpearn y1_status_v2##sex i.race_collapsed i.educ_collapsed $ctrl_nosex, vce(robust)
eststo any_earn_mode_m4


// regression for self-employed sample 
preserve 
keep if pct_se_after_12 >=.5
quietly xtreg ln_tpearn i.unempf12_6 i.educ_collapsed $controls, vce(robust) 
eststo se_earn_unemp_m1 
quietly xtreg ln_tpearn i.unempf12_6 i.race_collapsed i.educ_collapsed  $controls, vce(robust) 
eststo se_earn_unemp_m2
quietly xtreg ln_tpearn unempf12_6##race_collapsed i.educ_collapse $controls, vce(robust)
eststo se_earn_unemp_m3
quietly xtreg ln_tpearn unempf12_6##sex i.race_collapsed i.educ_collapse $ctrl_nosex, vce(robust)
eststo se_earn_unemp_m4


quietly xtreg ln_tpearn i.y1_status_v2 i.educ_collapsed $controls, vce(robust) 
eststo se_earn_mode_m1 
quietly xtreg ln_tpearn i.y1_status_v2 i.race_collapsed i.educ_collapsed $controls, vce(robust) 
eststo se_earn_mode_m2
quietly xtreg ln_tpearn y1_status_v2##race_collapsed i.educ_collapsed $controls, vce(robust)
eststo se_earn_mode_m3
quietly xtreg ln_tpearn y1_status_v2##sex i.race_collapsed i.educ_collapsed $ctrl_nosex, vce(robust)
eststo se_earn_mode_m4

restore 





**# Table 3 Regression Earnings on Unemployment (SE Sample)
*------------------------------------------------------------------------------|
label variable age "Age"
label variable immigrant "Immigrant"
label values immigrant immigrant_labels

label values educ_collapsed educ_lab

esttab any_earn_unemp??? se_earn_unemp??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 3: Relationship between Unemployment and Log Annual Earnings (Self-Employed Sample)) ///
	varlabels(_cons Constant)   ///
	nonumbers mtitles("Full Sample" ""  "" "Self-Employed Sample" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell replace  



**# Table 6: Regression Earnings on Initial Employment Status (Self-Employed Sample)
*------------------------------------------------------------------------------|
esttab any_earn_mode??? se_earn_mode??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 6: Relationship between Initial Employment Status and Log Annual Earnings (Self-Employed Sample)) ///
	varlabels(_cons Constant)   ///
	nonumbers mtitles("Full Sample" ""  "" "Self-Employed Sample" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append 
	


	
*------------------------------------------------------------------------------|
**# Examining Business Profits
*------------------------------------------------------------------------------|
frame copy earnings profits, replace  
frame change profits

// profit and tbsjval are only reported in records coded as main job SE so need to carry them throughout the year for each person. 
list swave monthcode tjb_prftb tbsjval if ssuid_spanel_pnum_id  ==  198178, sepby(swave)
gsort ssuid_spanel_pnum_id swave -tjb_prftb
by ssuid_spanel_pnum_id swave: carryforward tjb_prftb, replace 
gsort ssuid_spanel_pnum_id swave -tbsjval
by ssuid_spanel_pnum_id swave: carryforward tbsjval, replace 
list swave monthcode tjb_prftb tbsjval if ssuid_spanel_pnum_id  ==  198178, sepby(swave)

// now can create unique year tag given that we have prft and bus val  equal for every row per person per wave 
egen unique_yr_tag= tag(ssuid_spanel_pnum_id swave) // creating person-year flag 
keep if unique_yr_tag // now we're down to one row per person per year an


// recoding profits 
gen profposi=tjb_prftb>0 if tjb_prftb<. // 
tab profpos, missing
gen prof10k=tjb_prftb>=10000 if tjb_prftb<.
tab prof10k, missing

foreach x in  tjb_prftb tbsjval {
	egen min_`x' = min(`x')
	replace min_`x' = min_`x' *-1
	gen ln_`x' = ln(`x' + min_`x'+1)
} 

list ssuid_spanel_pnum_id calyear profpos prof10k ln_tjb_prftb tjb_prftb tbsjval ln_tbsjval ///
unempf12_6 y1_status_v2 in 1/50 if pct_se_after_12 ==1, sepby(ssuid_spanel_pnum_id) abbrev(10)

// getting to sample of interest
keep if pct_se_after_12 >=.5  // keeping only SE 
bysort ssuid_spanel_pnum_id (calyear): drop if _n == 1 // dropping first year as we use it as determining status


frame copy profits profits_collapse, replace 
frame change profits_collapse

// taking most common industry reported by person over the years we observe them
bys ssuid_spanel_pnum_id: egen mode_industry=mode(industry2), minmode

collapse (mean) tjb_prftb tbsjval ln_tjb_prftb ln_tbsjval (max) educ_collapsed (first) mode_industry  age, by(ssuid_spanel_pnum_id y1_status_v2 race_collapsed immigrant sex unempf12_6 pct_ws_after_12)


label variable race_collapsed "Race/Ethnicity"
label variable sex "Sex"
label variable age "Age"
label values immigrant immigrant_labels
label variable immigrant "Immigrant"
label variable unempf12_6 "Unemployed 6-months"

//label values industry2 industry_labels 
//label variable industry2 "Industry"
label values mode_industry industry_labels
label variable mode_industry "Industry"



label variable tjb_prftb "Mean Annual Profit"
label variable ln_tjb_prftb "Mean Log Annual Profit"
label variable tbsjval "Mean Annual Business Value"
label variable ln_tbsjval "Mean Log Annual Business Value"


gen tjb_prftb_med = tjb_prftb 
label variable tjb_prftb_med "Median Annual Profit Earnings"
gen tbsjval_med = tbsjval
label variable tbsjval_med "Median Annual Business Value"


**# Table 2A: Profit within Race/Ethnicity by Initial Employment Status
*------------------------------------------------------------------------------|
local x = 0
local names White Non_White
foreach name of local names {
	local x = `x' + 1
	collect create `name', replace 
	quietly: pwmean tjb_prftb if race_collapsed ==`x' , over(y1_status_v2) mcompare(dunnett) 
	collect get r(table) 
	collect remap rowname[b] = values[lev1], ///
		fortags(colname[1.y1_status_v2 2.y1_status_v2 4.y1_status_v2])
	collect remap rowname[b] = values[lev2], ///
		fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])
	collect remap rowname[se] = values[lev3], fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])

	collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
}

collect create Full_Sample, replace 
quietly: pwmean tjb_prftb, over(y1_status_v2) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], ///
	fortags(colname[1.y1_status_v2 2.y1_status_v2 4.y1_status_v2])
collect remap rowname[b] = values[lev2], ///
	fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.y1_status_v2  4vs1.y1_status_v2])

collect combine newc = Full_Sample White Non_White, replace
collect layout  (collection#values) (y1_status_v2), name(newc)
collect label levels y1_status_v2 1 "Wage/Salary" 2 "Self-Employed" 4 "Unemployed", replace
collect style row split, dups(first)
collect title "Table 2A. Profit within Race/Ethnicity by Initial Employment Status"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean profit is calculated as a grand mean of person level average annual profit as reported in the tjb_prftb variable."
collect style cell values, nformat(%5.1f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2A, replace) modify



dtable i.race_collapsed
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2A) cell(H1) modify


**# Table 2A Profit Comparison Between Race/Ethnicity within Initial Employment Status 
*------------------------------------------------------------------------------|
collect clear
local statuses "1 2 4"
local labels "salaried self_employed unemployed_start"

// Loop over the two lists 
forvalues i = 1/3 {
    // Get the status value and the corresponding label using the counter
    local status : word `i' of `statuses'
    local label : word `i' of `labels'

    local collection_name = strtoname("`label'")

    collect create `collection_name', replace
    
    quietly: pwmean tjb_prftb if y1_status_v2 == `status', over(race_collapsed) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[`race_list'])
    collect remap rowname[b] = values[lev2], fortags(colname[`race_comparisons'])
    collect remap rowname[se] = values[lev3], fortags(colname[`race_comparisons'])
    
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (educ_collapsed) (values)
}



// combine them into one 
collect combine newc = salaried self_employed unemployed_start, replace 
collect label levels collection Full_Sample "Full Sample" salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (race_collapsed) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 2A. Profit Comparisons by Race/Ethnicity and Initial Employment Status"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean profit are calculated as a grand mean of person level average annual profits as reported in the tjb_prftb variable."
collect style cell values, nformat(%5.1f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2A, replace) modify

collect create n_counts, replace
table race_collapsed y1_status_v2 
collect layout (race_collapsed) (y1_status_v2)
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2A) cell(M1) modify


 


*------------------------------------------------------------------------------|
**# Profit Modeling
*------------------------------------------------------------------------------|

frame change profits 
label  values immigrant immigrant_labels
xtset ssuid_spanel_pnum_id calyear 

bysort ssuid_spanel_pnum_id calyear: egen mode_industry_year = mode(industry2), minmode
label values mode_industry_year industry_labels
label variable mode_industry_year "Industry"



foreach y of varlist profposi prof10k   {
	foreach x of varlist unempf12_6 y1_status_v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtlogit `y' i.`x' i.educ_collapsed $controls , vce(robust) 
		eststo `y'_`xname'_1re

	    quietly xtlogit `y' i.`x' i.educ_collapsed i.race_collapsed $controls , vce(robust) 
		eststo `y'_`xname'_2re
		
		quietly xtlogit `y' `x'##race_collapsed i.educ_collapsed  $controls , vce(robust) 
		eststo `y'_`xname'_3re
		
		quietly xtlogit `y' `x'##sex i.race_collapsed i.educ_collapsed  $ctrl_nosex , vce(robust) 
		eststo `y'_`xname'_4re


		}
}



foreach y of varlist ln_tjb_prftb ln_tbsjval   {
	foreach x of varlist unempf12_6 y1_status_v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x' i.educ_collapsed  $controls , vce(robust) 
		eststo `y'_`xname'_1re

	    quietly xtreg `y' i.`x' i.educ_collapsed i.race_collapsed $controls , vce(robust) 
		eststo `y'_`xname'_2re
		
		quietly xtreg `y' `x'##race_collapsed i.educ_collapsed  $controls , vce(robust) 
		eststo `y'_`xname'_3re
		
		quietly xtreg `y' `x'##sex i.race_collapsed i.educ_collapsed $ctrl_nosex, vce(robust)
		eststo `y'_`xname'_4re
		
	}
}


**# Table 4 Logistic Regressions Profit on Unemployment
*------------------------------------------------------------------------------|
esttab prof*unemp* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 4. Logistic Regressions Profit on Unemployment) ///
	varlabels(_cons Constant)   ///
	mtitles("Positive Profit" "" "" "" "Profit >= 10k"  "" ""	"") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  
	
**# Table 5 Regressions Business Value on Unemployment
*------------------------------------------------------------------------------|
esttab ln_tbsjval_unemp_* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 5. Regressions Business Value on Unemployment) ///
	varlabels(_cons Constant)    ///
	mtitles("Log Business Value" "" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  

**# Table 7 Logistic Regressions of Profit on Initial Employment Status
*------------------------------------------------------------------------------|
esttab prof*y1* using working_paper_outputs_`logdate'.rtf, ///
	legend label  ///
	title(Table 7. Logistic Regressions Profit on Initial Employment Status) ///
	varlabels(_cons Constant) ///
	mtitles("Positive Profit" "" "" "" "Profit >= 10k" "" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  

	

	
**# Table 8 Regressions Business Value on Initial Employment Status
*------------------------------------------------------------------------------|
esttab ln_tbsjval_y1_* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 8. Regressions Business Value on Initial Employment Status) ///
	varlabels(_cons Constant)   ///
	nonumbers mtitles("Log Business Value" "" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  
	


**# Plotting
*------------------------------------------------------------------------------|

**# Plots for unemployment 
label define unemp_labels 0 "Not Unemployed" 1 "Unemployed", replace 
label values unempf12_6 unemp_labels
cd "/Users/toddnobles/Documents/sipp_analyses/outputs"


xtlogit prof10k i.unempf12_6 i.educ_collapsed i.race_collapsed $controls , vce(robust) 

**# Graph Unemployment Profit 10k scatter
*---------------------------------------------------------------------------|
margins unempf12_6, saving(tempmargins, replace)
preserve
clear
use tempmargins
twoway (rcap _ci_lb _ci_ub _m1, sort colorvar(_m1) colordiscrete colorcuts(0 1) colorlist(stc1 stc2) clegend(off)) ///
(scatter _margin _m1 if _m1==0, sort mc("stc1") ) ///
(scatter _margin _m1 if _m1==1, sort mc("stc2")), ///
legend(off) title("Overall Sample") xlabel(0 "Not Unemployed" 1 "Unemployed") xtitle("") ///
ytitle("Probability of Profit >= 10k") saving(g1, replace) fxsize(50) ylabel(0(.1).6)
restore


margins unempf12_6, at(race_collapsed =(1 2) ) 
marginsplot, recast(scatter) xdimension(race_collapsed) title("Race/Ethnicity") ///
xtitle("Race/Ethnicity") ytitle("") ylabel(0(.1).6) saving(g2, replace ) 

grc1leg  g1.gph g2.gph , ycommon legend(g2.gph) title("Predicted Probability of Profit >= $10,000")  ///
subtitle("by Unemployment") 

graph export graph_10kprofit.png, replace



**# Graph Unemployment Positive Profit Scatter
*---------------------------------------------------------------------------|
xtlogit profpos i.unempf12_6 i.educ_collapsed i.race_collapsed $controls , vce(robust) 

margins unempf12_6, saving(tempmargins, replace)
preserve
clear
use tempmargins
twoway (rcap _ci_lb _ci_ub _m1, sort colorvar(_m1) colordiscrete colorcuts(0 1) colorlist(stc1 stc2) clegend(off)) ///
(scatter _margin _m1 if _m1==0, sort mc("stc1") ) ///
(scatter _margin _m1 if _m1==1, sort mc("stc2")), ///
legend(off) title("Overall Sample") xlabel(0 "Not Unemployed" 1 "Unemployed") xtitle("") ///
ytitle("Probability of Positive Profit") saving(g1, replace) fxsize(50) ylabel(0(.1).6)
restore


margins unempf12_6, at(race_collapsed =(1 2) ) 
marginsplot, recast(scatter) xdimension(race_collapsed) title("Race/Ethnicity") ///
xtitle("Race/Ethnicity") ytitle("") ylabel(0(.1).6) saving(g2, replace ) 

grc1leg  g1.gph g2.gph , ycommon legend(g2.gph) title("Predicted Probability of Positive Profit")  ///
subtitle("by Unemployment") 

graph export graph_postive_profit.png, replace




**# graphs for interactions
frame change earnings_models

xtreg ln_tpearn unempf12_6##race_collapsed i.educ_collapsed $controls, vce(robust)
margins unempf12_6#race_collapsed 
marginsplot 

xtreg ln_tpearn y1_status_v2##race_collapsed i.educ_collapsed $controls, vce(robust)
margins y1_status_v2#race_collapsed
marginsplot

preserve
keep if pct_se_after_12 >= .5

xtreg ln_tpearn unempf12_6##race_collapsed i.educ_collapsed $controls, vce(robust)
margins unempf12_6#race_collapsed 
marginsplot, recast(scatter)
margins race_collapsed, dydx(unempf12_6) 
marginsplot, recast(scatter)

margins race_collapsed#unempf12_6
marginsplot

xtreg ln_tpearn y1_status_v2##race_collapsed i.educ_collapsed $controls, vce(robust)
margins y1_status_v2#race_collapsed
marginsplot, recast(scatter)

restore 
	
	