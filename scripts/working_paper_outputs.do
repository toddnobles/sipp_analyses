clear all 
eststo clear 

/* use for running off SSD 
local homepath "/Volumes/Extreme SSD/SIPP Data Files/"
local datapath "`homepath'/dtas"


cd "`datapath'"
*/

cd "/Users/toddnobles/Documents/sipp_analyses/"
set linesize 255


/***
<html>
<body>
<h2>Data Prep</h2>
***/

**# Data import
//use earnings_by_status, clear  
use sipp_reshaped_work_comb_imputed, clear  

// bringing in monthly level data 
merge m:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined 
sort ssuid_spanel_pnum_id spanel swave monthcode 
bysort ssuid_spanel_pnum_id: egen _merge_avg = mean(_merge)


// filtering to population of interest
keep if tage>=18 & tage<=64

/***
<html>
<body>
<h3>Creating main job flag</h3>
***/
**# main job

gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 
keep if jb_main ==1 // gets us one record for each month with their main job or that they were unemployed 
recode enjflag (1=1 unemployed) (2=0 no), into(unemployed_flag)


// dropping those who never worked in our dataset
bysort ssuid_spanel_pnum_id: egen sum_enjflag = sum(unemployed_flag)
bysort ssuid_spanel_pnum_id: gen num_records = _N
drop if sum_enjflag == num_records

/***
<html>
<body>
<h3>creating lenient employment type flag</h3>
<p> job trumps unemployment flag  (must be unemployed for at least one month to count as unemployed)</p>
***/
**# employment type flag 

gen employment_type1 = 1 if ejb_jborse == 1 // W&S
replace employment_type1 = 2 if ejb_jborse == 2 // SE
replace employment_type1 = 3 if ejb_jborse == 3 // other 
replace employment_type1 = 4 if ejb_jborse == . & enjflag == 1
codebook employment_type1



 // will ignore these few edge cases for now as they just seem to be data entry issues 
drop if employment_type1 == . 
unique ssuid_spanel_pnum_id swave monthcode // person month level file here. So we only have one job per month and it's their main job 
unique ssuid_spanel_pnum_id swave // person years
isid ssuid_spanel_pnum_id swave monthcode // double checking 

/***
<html>
<body>
<h3>at this point we have a person-month level file with an employment status for them for each period captured in employment_type </h3>
***/
egen tag = tag(ssuid_spanel_pnum_id employment_type1)
su tag
bysort ssuid_spanel_pnum_id: egen tag_sum = sum(tag)
unique ssuid_spanel_pnum_id
unique ssuid_spanel_pnum_id if tag_sum >1 // gives us count of people who changed at some point 

label define employment_types 1 "W&S" 2 "SE" 3 "Other" 4 "Unemp"
label values employment_type1 employment_types

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



/***
<html>
<body>
<h3>Month variable work</h3>
<p>https://www2.census.gov/programs-surveys/sipp/tech-documentation/methodology/2022_SIPP_Users_Guide_JUN23.pdf </p>
***/

gen month_overall = monthcode if spanel == 2014 & swave == 1 		// 1-12 = 2013 
replace month_overall = monthcode + 1*12 if spanel == 2014 & swave == 2  // 13-24 = 2014
replace month_overall = monthcode + 2*12 if spanel == 2014 & swave == 3  // 25-36 = 2015
replace month_overall = monthcode + 3*12 if spanel == 2014 & swave == 4  // 37-48 = 2016
replace month_overall = monthcode + 4*12 if spanel == 2018 & swave == 1  // 49-60 = 2017
replace month_overall = monthcode + 5*12 if (spanel == 2018 & swave == 2) | (spanel == 2019 & swave == 1)  // 61-72 = 2018
replace month_overall = monthcode + 6*12 if (spanel == 2018 & swave == 3) | (spanel == 2020 & swave == 1)  // 73-84 = 2019
replace month_overall = monthcode + 7*12 if (spanel == 2018 & swave == 4) | (spanel == 2020 & swave == 2) | (spanel == 2021 & swave	== 1) // 85-96 = 2020


bysort ssuid_spanel_pnum_id (month_over) : gen temp = 1 if month_over[1] > 12 
unique ssuid_spanel_pnum_id if temp == 1 

// here we have people who weren't in wave 1 so don't have month_over values less than 12 so the original version of the below codes wouldn't work for capturing their first month. Switching to using month_individ to start counting a 12 month window from the first observation we have for someone in our data 
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


frame copy default earnings, replace

global controls= "i.sex age age2 immigrant parent industry2 calyear"



/***
<html>
<body>
<h3>Flags for unemployment during first 12 months </h3>
<p>max_consec_unempf12 gives us the length of longest unemployment spell during the first 12 months. months_unempf12 gives us the total number of months unemployed during first 12 months</p>
***/

frame change earnings 
bysort ssuid_spanel_pnum_id: gen months_in_data = _N
drop if months_in_data < 12 // do we actually want this? 
bysort ssuid_spanel_pnum_id: egen months_unempf12=  count(month_individ) if (employment_type1 == 4 & month_individ <=12) // doesn't account for non-consecutive issues 

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

foreach var of varlist unempf12_1 unempf12_3 unempf12_6{
	replace `var' = 0 if `var' == . 
}

/***
<html>
<body>
<h3>Quantifying self-employment after the first 12 months </h3>
<p></p>
***/


drop if tjb_mwkhrs < 15 // keeps in unemployment records as they're coded with tjb_mwkhrs = . 

bysort ssuid_spanel_pnum_id (month_individ): egen months_after_12 = count(month_individ) if month_individ>12 // measure of how many unemployed or employment >=15 hours we observe this person after first 12 months
gsort ssuid_spanel_pnum_id -month_individ 
by ssuid_spanel_pnum_id: carryforward months_after_12, replace 
replace months_after_12 = 0 if months_after_12 == .

drop if months_after_12 == 0 // don't care about people who we only have for 12 months 


gen self_emp = 1 if month_individ >12 & employment_type1 == 2
bysort ssuid_spanel_pnum_id: egen months_se_after_12 = sum(self_emp)
gen pct_se_after_12 = months_se_after_12/months_after_12



bysort ssuid_spanel_pnum_id (month_individ): egen months_employed_after_12 = count(month_individ) if month_individ>12 & employment_type !=4 & employment_type !=3 // measure of how many SE or WS months after first 12 months and >=15 hours we observe this person 
gsort ssuid_spanel_pnum_id -month_individ 
by ssuid_spanel_pnum_id: carryforward months_employed_after_12, replace 

gen ws = 1 if month_individ >12 & employment_type1 == 1
bysort ssuid_spanel_pnum_id: egen months_ws_after_12 = sum(ws)
gen pct_ws_after_12 = months_ws_after_12/months_after_12

/***
<html>
<body>
<h4>making flags for statuses during first 12 months</h4>
<p></p>
***/

bysort ssuid_spanel_pnum_id (month_individ): gen change = employment_type1 != employment_type1[_n-1] & _n >1 & month_individ<=12
bysort ssuid_spanel_pnum_id (month_individ): gen first_status_f12 = employment_type1 if _n==1 


gsort ssuid_spanel_pnum_id -change spanel swave monthcode

by ssuid_spanel_pnum_id: gen second_status_f12 = employment_type1 if change ==1 & _n ==1
by ssuid_spanel_pnum_id: gen third_status_f12 = employment_type1 if change ==1 & _n ==2
by ssuid_spanel_pnum_id: gen fourth_status_f12 = employment_type1 if change ==1 & _n ==3
by ssuid_spanel_pnum_id: gen fifth_status_f12 = employment_type1 if change ==1 & _n ==4
by ssuid_spanel_pnum_id: gen sixth_status_f12 = employment_type1 if change ==1 & _n ==5
by ssuid_spanel_pnum_id: gen seventh_status_f12 = employment_type1 if change ==1 & _n ==6 

// no one has more than 7 statuses in first 12 months 
// let's see what their last status is in month 12

sort ssuid_spanel_pnum_id month_individ
list ssuid_spanel_pnum_id month_individ employment_type1 change *status* if ssuid_spanel_pnum_id == 199771

local i = 0
foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status {
	gsort ssuid_spanel_pnum_id -`x' 
	local i = `i' + 1
	by ssuid_spanel_pnum_id: carryforward `x', gen(status_`i') 
	
}

local i = 0

foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status {
	local i = `i' + 1
	bysort ssuid_spanel_pnum_id (swave monthcode) employment_type1: carryforward `x', gen(status_`i'_lim)  dynamic_condition(employment_type1[_n-1]==employment_type1[_n])
	replace status_`i'_lim = . if month_individ > 12

}

forval x = 1/7 {
	by ssuid_spanel_pnum_id: egen months_s`x' = count(status_`x'_lim)
	
}


// we want their most common status during first 12 months, first status and last status 
// we have first status in variable first_status_f12, 
bysort ssuid_spanel_pnum_id (month_individ): gen last_status_f12 = employment_type1[12] // last status 

bysort ssuid_spanel_pnum_id (month_individ): egen mode_status_f12v1 = mode(employment_type1) if month_individ <=12, minmode 
bysort ssuid_spanel_pnum_id (month_individ): egen mode_status_f12v2 = mode(employment_type1) if month_individ <= 12, maxmode 

bysort ssuid_spanel_pnum_id (month_individ): carryforward mode_status_f12v1 , replace
bysort ssuid_spanel_pnum_id (month_individ): carryforward mode_status_f12v2 , replace




/***
<html>
<body>
<h3>Evaluating what we have </h3>
<p> We now have a dataset with the following flags and measures:<br>
	- Sample restricted to those who were of working age and their monthly job level records when they were employed at least 15 hours 		
	when they were unemployed (we may want to drop these at this point for analyses) <br> 
	- Monthly level earnings from all sources in tpearn and and from their main job in tjb_msum
	- "*_status_f12" vars capture the *nth status held within the first 12 months (only non-missing for one observation) <br>
	- "status_*" vars capture the same information as the above vars but carryforward the value to be present for all observations <br> 
	- "months_s*" vars capture the number of consecutive months that a specific status was held during the first 12 months. For instance months_s1 = 6 and status_1 == 2 means the first 6 months we observed that individual they were self-employed. <br>
	- "last_status" is the last status held during the first 12 months we observe someone <br>
	- "mode_status_f12v1" is the most common that person held during the first 12 months and breaks ties by taking the min value (prioritizes employment)
	- "mode_status_f12v2" is the same as above, but takes the max mode so prioritizes unemployment in tie breaking <br>
	- pct_se_after_12 captures the share of months after the 12 month entry window that someone was self-employed. 
	So if someone is in our data for 36 months, we ignore the first 12 months, then count the number of months their main job 
	that they worked more than 15 hours was self-employment. That value is our numerator. Then we count the total number of months they 
	were present in the data post-12 month window (excluding the months they worked for fewer than 15 hours but including the months they were unemployed) <br>
<br>
We also have flags for unemployment during the first 12 months: <br>
	- months_unempf12 gives us the total number of months unemployed during first 12 months <br>
	- max_consec_unempf12 gives us the maximum consecutive spell of unemployment a person experienced <br>
	- unempf12_1, unempf12_3, unempf12_6 are flags indicating whether that person experienced at least 1, 3, or 6 months of consecutive unemployment 
	in the first 12 month window we observe them. 
</p>
***/

foreach var of varlist first_status_f12-status_7_lim last_status_f12 status_* mode* {
	label values `var' employment_types
}
list month_individ	employment_type1 tjb_mwkhrs tpearn months_s1-months_s2 status_1_lim-status_2_lim status_1 status_2 last_status pct_se_after_12 mode_status_f12v1 unempf12_6 if ssuid_spanel_pnum_id == 200324 

/*
drop ejb_clwrk ejb_endwk ejb_jborse ejb_startwk ejb_incpb ejb_bslryb ejb_typpay1 ejb_jobid tjb_occ tjb_ind tjb_empb 
drop tjb_gamt1 tbsjdebtval tdebt_cc tdebt_ed tdebt_bus teq_bus tval_home tdebt_home teq_home tval_ast tdebt_ast 
drop tnetworth thdebt_cc thdebt_ed thval_home thdebt_home theq_home thval_ast thdebt_ast thnetworth
*/ 


compress 

/***
<html>
<body>
<h3>Comparing those experienced unemployment versus those who did not</h3>
<p>These models include earnings within the first 12 months. <br>
Unemployed months here are still in the data but the model ignores them since their tjb_msum and tpearn values are missing. 
</p>
***/

drop if employment_type1 == 3 
drop if status_1 == 3 
drop if mode_status_f12v1 == 3 
drop if mode_status_f12v2 == 3 
drop if industry2 == 15 // dropping military members as can't have self-employed military 
label variable tpearn "tpearn"


foreach var of varlist unempf12_6 mode_status_f12v2 educ3 combine_race_eth sex age immigrant parent industry2 calyear{

	drop if `var' == . 
}





**# Collapsing to yearly values for earnings 
*-------------------------------------------------------------------------------|

local logdate : di %tdCYND daily("$S_DATE", "DMY")
display `logdate'


label variable unempf12_6 "Unemployed 6-months"
label variable calyear "Year"
label define parent_labels 1 "Parent" 0 "Not Parent"
label values parent parent_labels
label variable parent "Parent"

label variable immigrant "Immigrant"

label define immigrant_labels 1 "Immigrant" 0 "Native Born"
label  values immigrant immigrant_labels


frame copy earnings annual_earnings, replace 
frame change annual_earnings 

keep if pct_se_after_12 == 1 | pct_ws_after_12 == 1

bys ssuid_spanel_pnum_id: egen mode_industry=mode(industry2), minmode

collapse (sum) tpearn tjb_msum (max) educ3 (first) mode_industry parent age (count) n_months = tpearn, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth immigrant sex pct_se_after_12 unempf12_6 pct_ws_after_12 calyear)

// at this point have a file that is collapsed to person-per year with their total earnings in tpearn and tjb_sum per year


bysort ssuid_spanel_pnum_id (calyear): drop if _n == 1 

// collapsing once more to mirror the monthly earnings analysis where we can produce a table that n-counts match the individuals that fall in that group

collapse (mean) tpearn tjb_msum (max) educ3 (first) mode_industry parent age (count) n_years = tpearn, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth immigrant sex pct_se_after_12 unempf12_6 pct_ws_after_12)



label variable combine_race_eth "Race/Ethnicity"
label variable sex "Sex"
label variable age "Age"
label values immigrant immigrant_labels
label variable immigrant "Immigrant"
label variable parent "Parent"

label define industry_labels 1  "Forestry, Farming, Fishing, and Mining" ///
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

//label values industry2 industry_labels 
//label variable industry2 "Industry"
label variable mode_industry "Industry"
label values mode_industry industry_labels 

label define education_labels 1 "High School or Less" 2 "Associates or Less" 3 "4-year Degree" 4 "Graduate Degree"
label values educ3 education_labels
label variable educ3 "Education"

label variable tpearn "Mean Annual Earnings"
gen tpearn_med = tpearn 
label variable tpearn_med "Median Annual Earnings"
label values parent parent_labels
label  values immigrant immigrant_labels
label define mode_status_labels 1 "Wage & Salary" 2 "Self-Employed" 4 "Unemployed"
label values mode_status_f12v2 mode_status_labels

**# Table 1
*------------------------------------------------------------------------------|
preserve
keep if pct_se_after_12 == 1 
dtable tpearn tpearn_med i.sex i.combine_race_eth i.educ3 i.immigrant i.parent i.mode_industry, by( mode_status_f12v2) ///
sample(, statistics(freq) place(seplabels)) ///
	continuous(tpearn_med, statistics(median)) /// 
	sformat("(N=%s)" frequency) nformat(%7.0f mean sd) ///
	column(by(hide) total("Full Sample")) ///
	title(Table 1. Descriptive Statistics for Self-Employed Sample by Initial Employment Status) ///
	note(This table contains information on those who from the 13th month of observation onwards were never unemployed and reported being self-employed for each month. Average earnings are grand means of individuals' average annual earnings for any type of employment. Median earnings are the median of individual average annual earnings. Excluded from sample are those who dropped out of the SIPP sample after only one year of participation, months where individuals worked fewer than 15 hours, and "Other" employment types besides self-employed or wage and salaried.)
	
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 1) replace
restore 

**# Appendix Table 1A
*------------------------------------------------------------------------------|
dtable tpearn tpearn_med i.sex i.combine_race_eth i.educ3 i.immigrant i.parent i.mode_industry , ///
	by(mode_status_f12v2) ///
	sample(, statistics(freq) place(seplabels)) ///
	continuous(tpearn_med, statistics(median)) /// 
	sformat("(N=%s)" frequency) nformat(%7.0f mean sd) ///
	note(Average earnings are grand means of individuals' average annual earnings for any type of employment. Median earnings are the median of individual average annual earnings. Initial employment status determined by individuals' most common employment status during first 12 months observed in data. Excluded from sample are those who dropped out of the SIPP sample after only one year of participation, months where individuals worked fewer than 15 hours, and "Other" employment types besides self-employed or wage and salaried. Sample is also restricted to those who were continuously employed in either self-employment or wage and salaried employment after the first 12-months observed in the data. ) ///
	column(by(hide) total("Full Sample")) ///
	nformat(%7.1f mean sd) ///
	title(Table 1A. Descriptive Statistics by Initial Employment Status) 


collect export working_paper_outputs_`logdate'.xlsx, sheet(Appendix Table 1A) modify



**# Appendix Table 1B
*------------------------------------------------------------------------------|
gen status_after_12 = "Self-Employed" if pct_se_after_12 == 1
replace  status_after_12 = "Wage-Salaried" if pct_ws_after_12 == 1

dtable tpearn tpearn_med i.sex i.combine_race_eth i.educ3 i.immigrant i.parent i.mode_industry, by(status_after_12) ///
sample(, statistics(freq) place(seplabels)) ///
	continuous(tpearn_med, statistics(median)) /// 
	sformat("(N=%s)" frequency) nformat(%7.0f mean sd) ///
	column(by(hide) total("Full Sample")) ///
	title(Table 1B. Descriptive Statistics for Self-Employed Only and Wage and Salary Only Samples) ///
	note(Here, "Self-Employed" refers to those who from the 13th month of observation onwards were never unemployed and reported being self-employed for each month. Similarly, "Wage and Salary" refers to thoe who from the 13th month of observation onwards were never unemployed and reported being employed in a waged/salaried position for each month. Average earnings are grand means of individuals' average annual earnings for any type of employment. Median earnings are the median of individual average annual earnings. Excluded from sample are those who dropped out of the SIPP sample after only one year of participation, months where individuals worked fewer than 15 hours, and "Other" employment types besides self-employed or wage and salaried. Sample is also restricted to those who were continuously employed in either self-employment or wage and salaried employment after the first 12-months observed in the data.)
	
collect export working_paper_outputs_`logdate'.xlsx, sheet(Appendix Table 1B, replace) modify


**# Working with Wage and Salary Sample for tables
*------------------------------------------------------------------------------|

local race_comparisons 2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth
local race_list 1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth
local ed

preserve
keep if pct_ws_after_12 == 1

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
    
    quietly: pwmean tpearn if mode_status_f12v2 == `status', over(combine_race_eth) mcompare(dunnett)
    
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
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2, replace) modify

collect create Full_Sample, replace 
quietly: pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], ///
	fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
collect remap rowname[b] = values[lev2], ///
	fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout  (values) ( mode_status_f12v2) ()
collect style cell values, nformat(%6.0f)
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2) cell(M1) modify

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
    
    quietly: pwmean tpearn if mode_status_f12v2 == `status', over(sex) mcompare(dunnett)
    
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
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2) cell(A11) modify


**# Table 2.Education: Annual Earnings Comparisons by Education and Initial Employment Status (Wage/Salary Sample)
*------------------------------------------------------------------------------|

local educ_comparisons 2vs1.educ3 3vs1.educ3 4vs1.educ3 
local educ_list 1.educ3 2.educ3 3.educ3 4.educ3 
label variable educ3 "Education"

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
    
    quietly: pwmean tpearn if mode_status_f12v2 == `status', over(educ3) mcompare(dunnett)
    
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
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2) cell(A18) modify


dtable i.combine_race_eth i.sex i.educ3 i.mode_status_f12v2
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2) cell(M8) modify




restore



**# Working with Self-employed sample now
*------------------------------------------------------------------------------|
preserve
keep if pct_se_after_12 == 1

**# Table 3	Annual Earnings Comparisons by Race/Ethnicity and Initial Employment Status (Self-Employed Sample)
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
    
    quietly: pwmean tpearn if mode_status_f12v2 == `status', over(combine_race_eth) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[`race_list'])
    collect remap rowname[b] = values[lev2], fortags(colname[`race_comparisons'])
    collect remap rowname[se] = values[lev3], fortags(colname[`race_comparisons'])
    
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (combine_race_eth) (values)
}

// combine them into one 
collect combine newc = salaried self_employed unemployed_start, replace 
collect label levels collection salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 3. Annual Earnings Comparisons by Race/Ethnicity, Sex, Education and Initial Employment Status (Self-Employed Sample)"
collect notes "Note: Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Self-Employed refers to those who were continuously self-employed from month 13 onwards. Mean earnings are calculated as a grand mean of person level average annual earnings. T-tests run comparing average annual earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%6.0f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 3, replace) modify

collect create Full_Sample, replace 
quietly: pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) //already filtered to pct_se_after_12 == 1 above
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
collect remap rowname[b] = values[lev2],fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout  (values) ( mode_status_f12v2) ()
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 3) cell(M1) modify





**# Table 3. Sex: Annual Earnings Comparisons by Sex and Initial Employment Status (Self-Employed Sample)
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
    
    quietly: pwmean tpearn if mode_status_f12v2 == `status', over(sex) mcompare(dunnett)
    
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
collect title "Table 3 Annual Earnings Comparisons by Sex and Initial Employment Status (Self-Employed Sample)"
collect style cell values, nformat(%6.0f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 3) cell(A11) modify


**# Table 3 Annual Earnings Comparisons by Education and Initial Employment Status 
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
    
    quietly: pwmean tpearn if mode_status_f12v2 == `status', over(educ3) mcompare(dunnett)
    
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
collect title "Table 2 Annual Earnings Comparisons by Education and Initial Employment Status (Self Employed Sample)"
collect style cell values, nformat(%6.0f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 3) cell(A18) modify


dtable i.combine_race_eth i.sex i.educ3 i.mode_status_f12v2
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 3) cell(M8) modify

restore 







**# Regressions for earnings 
frame copy earnings earnings_models
frame change earnings_models

keep if pct_se_after_12 == 1 | pct_ws_after_12 == 1
bys ssuid_spanel_pnum_id calyear: egen mode_industry_year =mode(industry2), minmode

collapse (sum) tpearn tjb_msum (max) educ3 (first) mode_industry_year parent age (count) n_months = tpearn, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth immigrant sex pct_se_after_12 unempf12_6 pct_ws_after_12 calyear)


// Dropping first year for everyone as otherwise we don't have a fair comparison group for earnings. 
bysort ssuid_spanel_pnum_id (calyear): drop if _n == 1 


gen age2 = age^2
label variable age2 "Age squared"
label variable age "Age"
label values mode_industry_year industry_labels
label variable mode_industry_year "Industry"
label define education_labels_abbr 1 "HS or Less" 2 "Some College or Assoc." 3 "4-year Degree" 4 "Graduate Degree"
label values educ3 education_labels_abbr



// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=.
xtset ssuid_spanel_pnum_id calyear 
global controls  = "i.sex age age2 i.immigrant i.parent mode_industry_year calyear"

// regressions for full-sample
quietly xtreg ln_tpearn i.unempf12_6, vce(robust) 
eststo any_earn_unemp_m1 
quietly xtreg ln_tpearn i.unempf12_6 i.educ3 $controls, vce(robust) 
eststo any_earn_unemp_m2
quietly xtreg ln_tpearn i.unempf12_6 i.combine_race_eth i.educ3 $controls, vce(robust) 
eststo any_earn_unemp_m3

// same models with mixed commands
/*
quietly mixed ln_tpearn i.unempf12_6 || ssuid_spanel_pnum_id:, vce(robust)
eststo mix_any_earn_unemp_m1
quietly mixed ln_tpearn i.unempf12_6 i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_any_earn_unemp_m2
quietly mixed ln_tpearn i.unempf12_6 i.combine_race_eth i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_any_earn_unemp_m3
*/


// mode status regressions 
quietly xtreg ln_tpearn i.mode_status_f12v2, vce(robust) 
eststo any_earn_mode_m1
quietly xtreg ln_tpearn i.mode_status_f12v2 i.educ3 $controls, vce(robust) 
eststo any_earn_mode_m2
quietly xtreg ln_tpearn i.mode_status_f12v2 i.combine_race_eth i.educ3 $controls, vce(robust) 
eststo any_earn_mode_m3


// same models with mixed commands 
/*
quietly mixed ln_tpearn i.mode_status_f12v2 || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_any_earn_mode_m1
quietly mixed ln_tpearn i.mode_status_f12v2 i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_any_earn_mode_m2
quietly mixed ln_tpearn i.mode_status_f12v2 i.combine_race_eth i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_any_earn_mode_m3
*/

// regression for self-employed sample 
preserve 
keep if pct_se_after_12 == 1 
quietly xtreg ln_tpearn i.unempf12_6, vce(robust) 
eststo se_earn_unemp_m1 
quietly xtreg ln_tpearn i.unempf12_6 i.educ3 $controls, vce(robust) 
eststo se_earn_unemp_m2
quietly xtreg ln_tpearn i.unempf12_6 i.combine_race_eth i.educ3  $controls, vce(robust) 
eststo se_earn_unemp_m3

quietly xtreg ln_tpearn i.mode_status_f12v2, vce(robust) 
eststo se_earn_mode_m1 
quietly xtreg ln_tpearn i.mode_status_f12v2 i.educ3 $controls, vce(robust) 
eststo se_earn_mode_m2
quietly xtreg ln_tpearn i.mode_status_f12v2 i.combine_race_eth i.educ3 $controls, vce(robust) 
eststo se_earn_mode_m3



// mixed version 
/*
quietly mixed ln_tpearn i.unempf12_6 || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_se_earn_unemp_m1
quietly mixed ln_tpearn i.unempf12_6 i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_se_earn_unemp_m2
quietly mixed ln_tpearn i.unempf12_6 i.combine_race_eth i.educ3  $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_se_earn_unemp_m3

quietly mixed ln_tpearn i.mode_status_f12v2 || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_se_earn_mode_m1
quietly mixed ln_tpearn i.mode_status_f12v2 i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_se_earn_mode_m2
quietly mixed ln_tpearn i.mode_status_f12v2 i.combine_race_eth i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_se_earn_mode_m3
*/
restore 

// regressions for wage/salaried sample 
*------------------------------------------------------------------------------|
preserve 
keep if pct_ws_after_12 == 1

quietly xtreg ln_tpearn i.unempf12_6, vce(robust) 
eststo ws_earn_unemp_m1 
quietly xtreg ln_tpearn i.unempf12_6 i.educ3  $controls, vce(robust) 
eststo ws_earn_unemp_m2
quietly xtreg ln_tpearn i.unempf12_6 i.combine_race_eth i.educ3 $controls, vce(robust) 
eststo ws_earn_unemp_m3


quietly xtreg ln_tpearn i.mode_status_f12v2, vce(robust) 
eststo ws_earn_mode_m1 
quietly xtreg ln_tpearn i.mode_status_f12v2 i.educ3 $controls, vce(robust)  
eststo ws_earn_mode_m2
quietly xtreg ln_tpearn i.mode_status_f12v2 i.combine_race_eth i.educ3  $controls, vce(robust)  
eststo ws_earn_mode_m3

//mixed versions
/*
quietly mixed ln_tpearn i.unempf12_6 || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_ws_earn_unemp_m1
quietly mixed ln_tpearn i.unempf12_6 i.educ3  $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_ws_earn_unemp_m2
quietly mixed ln_tpearn i.unempf12_6 i.combine_race_eth i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_ws_earn_unemp_m3

quietly mixed ln_tpearn i.mode_status_f12v2 || ssuid_spanel_pnum_id:, vce(robust) 
eststo mix_ws_earn_mode_m1
quietly mixed ln_tpearn i.mode_status_f12v2 i.educ3 $controls || ssuid_spanel_pnum_id:, vce(robust)  
eststo mix_ws_earn_mode_m2
quietly mixed ln_tpearn i.mode_status_f12v2 i.combine_race_eth i.educ3  $controls || ssuid_spanel_pnum_id:, vce(robust)  
eststo mix_ws_earn_mode_m3
*/
restore 




**# Table 4 Regression Earnings on Unemployment (SE Sample)
*------------------------------------------------------------------------------|
label variable age "Age"
label variable parent "Parent"
label values parent parent_labels
label variable immigrant "Immigrant"
label values immigrant immigrant_labels

label values educ3 education_labels_abbr

esttab any_earn_unemp??? se_earn_unemp??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*unemp* *combine_race_eth) ///
	title(Table 4: Relationship between Unemployment and Log Annual Earnings (Self-Employed Sample)) ///
	varlabels(_cons Constant) ///
	nonumbers mtitles("Full Sample" ""  "" "Self-Employed Sample" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell replace  

/*
esttab mix_any_earn_unemp??? mix_se_earn_unemp??? mix_ws_earn_unemp??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*unemp* *combine_race_eth) ///
	title(Table 5: Mixed: Relationship between Unemployment and Log Annual Earnings) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Full Sample" "Full Sample" "Full Sample"  "Self-Employed Sample" ///
	"Self-Employed Sample" "Self-Employed Sample" "Salaried Sample" "Salaried Sample" "Salaried Sample") ///
	addnote("Source: SIPP Data. Dependent Variable is log of tpearn") ///
	compress onecell append  	
*/


**# Table 5: Regression Earnings on Unemployment (WS Sample)
*------------------------------------------------------------------------------|
esttab any_earn_unemp??? ws_earn_unemp??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*unemp* *combine_race_eth) ///
	title(Table 5: Relationship between Unemployment and Log Annual Earnings (Salaried Sample)) ///
	varlabels(_cons Constant) ///
	nonumbers mtitles("Full Sample" ""  "" "Salaried Sample" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell replace  

**# Table 6: Regression Earnings on Initial Employment Status (Self-Employed Sample)
*------------------------------------------------------------------------------|
esttab any_earn_mode??? se_earn_mode??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*status* *combine_race_eth) ///
	title(Table 6: Relationship between Initial Employment Status and Log Annual Earnings (Self-Employed Sample)) ///
	varlabels(_cons Constant) ///
	nonumbers mtitles("Full Sample" ""  "" "Self-Employed Sample" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append 
	
**# Table 7: Regression Earnings on Initial Employment Status (Salaried Sample)
*------------------------------------------------------------------------------|
esttab any_earn_mode??? ws_earn_mode??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*status* *combine_race_eth) ///
	title(Table 7: Relationship between Initial Employment Status and Log Annual Earnings (Salaried Sample )) ///
	varlabels(_cons Constant) ///
	nonumbers mtitles("Full Sample" ""  "" "Salaried Sample" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append 
	
/*
esttab mix_any_earn_mode??? mix_se_earn_mode??? mix_ws_earn_mode??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*status* *combine_race_eth) ///
	title(Table 6: Mixed: Relationship between Initial Employment Status and Log Annual Earnings) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Full Sample" "Full Sample"  "Full Sample" "Self-Employed Sample" ///
	"Self-Employed Sample" "Self-Employed Sample" "Salaried Sample" "Salaried Sample" "Salaried Sample") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append 
*/
	
	
	
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
unempf12_6 mode_status_f12v2 in 1/50 if pct_se_after_12 ==1, sepby(ssuid_spanel_pnum_id) abbrev(10)

// getting to sample of interest
keep if pct_se_after_12 == 1 // keeping only SE 
bysort ssuid_spanel_pnum_id (calyear): drop if _n == 1 // dropping first year as we use it as determining status


frame copy profits profits_collapse, replace 
frame change profits_collapse

// taking most common industry reported by person over the years we observe them
bys ssuid_spanel_pnum_id: egen mode_industry=mode(industry2), minmode

collapse (mean) tjb_prftb tbsjval ln_tjb_prftb ln_tbsjval (max) educ3 (first) mode_industry parent age, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth immigrant sex unempf12_6 pct_ws_after_12)


label variable combine_race_eth "Race/Ethnicity"
label variable sex "Sex"
label variable age "Age"
label values immigrant immigrant_labels
label variable immigrant "Immigrant"
label variable parent "Parent"
label variable unempf12_6 "Unemployed 6-months"

//label values industry2 industry_labels 
//label variable industry2 "Industry"
label values mode_industry industry_labels
label variable mode_industry "Industry"

label values educ3 education_labels
label variable educ3 "Education"

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
local names White Black Asian Hispanic Other
foreach name of local names {
	local x = `x' + 1
	collect create `name', replace 
	quietly: pwmean tjb_prftb if combine_race_eth ==`x' , over(mode_status_f12v2) mcompare(dunnett) 
	collect get r(table) 
	collect remap rowname[b] = values[lev1], ///
		fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
	collect remap rowname[b] = values[lev2], ///
		fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
	collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])

	collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
}

collect create Full_Sample, replace 
quietly: pwmean tjb_prftb, over(mode_status_f12v2) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], ///
	fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
collect remap rowname[b] = values[lev2], ///
	fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])

collect combine newc = Full_Sample White Black Asian Hispanic Other, replace
collect layout  (collection#values) (mode_status_f12v2), name(newc)
collect label levels mode_status_f12v2 1 "Wage/Salary" 2 "Self-Employed" 4 "Unemployed", replace
collect style row split, dups(first)
collect title "Table 2A. Profit within Race/Ethnicity by Initial Employment Status"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean profit is calculated as a grand mean of person level average annual profit as reported in the tjb_prftb variable."
collect style cell values, nformat(%5.1f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2A, replace) modify



dtable i.combine_race_eth
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 2A) cell(H1) modify


**# Table 3A Profit Comparison Between Race/Ethnicity within Initial Employment Status 
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
    
    quietly: pwmean tjb_prftb if mode_status_f12v2 == `status', over(combine_race_eth) mcompare(dunnett)
    
    collect get r(table)
    collect remap rowname[b] = values[lev1], fortags(colname[`race_list'])
    collect remap rowname[b] = values[lev2], fortags(colname[`race_comparisons'])
    collect remap rowname[se] = values[lev3], fortags(colname[`race_comparisons'])
    
    collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
    collect layout (educ3) (values)
}



// combine them into one 
collect combine newc = salaried self_employed unemployed_start, replace 
collect label levels collection Full_Sample "Full Sample" salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 3A. Profit Comparisons by Race/Ethnicity and Initial Employment Status"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean profit are calculated as a grand mean of person level average annual profits as reported in the tjb_prftb variable."
collect style cell values, nformat(%5.1f)
collect preview
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 3A, replace) modify

collect create n_counts, replace
table combine_race_eth mode_status_f12v2 
collect layout (combine_race_eth) (mode_status_f12v2)
collect export working_paper_outputs_`logdate'.xlsx, sheet(Table 3A) cell(M1) modify


 


*------------------------------------------------------------------------------|
**# Profit Modeling
*------------------------------------------------------------------------------|

frame change profits 
label  values immigrant immigrant_labels
xtset ssuid_spanel_pnum_id calyear 

bysort ssuid_spanel_pnum_id calyear: egen mode_industry_year = mode(industry2), minmode
label values mode_industry_year industry_labels
label variable mode_industry_year "Industry"

label define education_labels_abbr 1 "HS or Less" 2 "Some College or Assoc." 3 "4-year Degree" 4 "Graduate Degree", replace
label values educ3 education_labels_abbr


foreach y of varlist profposi prof10k   {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtlogit `y' i.`x', vce(robust)  
		eststo `y'_`xname'_1re

		quietly xtlogit `y' i.`x' i.educ3 $controls , vce(robust) 
		eststo `y'_`xname'_2re
		
		quietly xtlogit `y' i.`x' i.combine_race_eth i.educ3  $controls , vce(robust) 
		eststo `y'_`xname'_3re
		
		/*
		 melogit `y' i.`x' || ssuid_spanel_pnum_id: , vce(robust)  
		eststo mix_`y'_`xname'_1

		 melogit `y' i.`x' i.educ3 $controls || ssuid_spanel_pnum_id: , vce(robust) 
		eststo mix_`y'_`xname'_2
		
		 melogit `y' i.`x' i.combine_race_eth i.educ3 $controls || ssuid_spanel_pnum_id: , vce(robust) 
		eststo mix_`y'_`xname'_3
		*/
		

		}
}



foreach y of varlist ln_tjb_prftb ln_tbsjval   {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust) 
		eststo `y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3  $controls , vce(robust) 
		eststo `y'_`xname'_2re
		
		quietly xtreg `y' i.`x' i.combine_race_eth i.educ3  $controls , vce(robust) 
		eststo `y'_`xname'_3re
		
		/*
		quietly mixed `y' i.`x' || ssuid_spanel_pnum_id: , vce(robust) 
		eststo mix_`y'_`xname'_1

		quietly mixed `y' i.`x' i.educ3  $controls || ssuid_spanel_pnum_id: , vce(robust) 
		eststo mix_`y'_`xname'_2
		
		quietly mixed `y' i.`x' i.combine_race_eth i.educ3  $controls ||ssuid_spanel_pnum_id: , vce(robust) 
		eststo mix_`y'_`xname'_3

*/
	}
}


**# Table 8 Logistic Regressions Profit on Unemployment
*------------------------------------------------------------------------------|
esttab prof*unemp* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*unemp* *combine*) ///
	title(Table 8. Logistic Regressions Profit on Unemployment) ///
	varlabels(_cons Constant) ///
	mtitles("Positive Profit" "" "" "Profit >= 10k"  "" 	"") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  

/*
	esttab mix_prof*unemp* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 7. Mixed: Logistic Regressions Profit on Unemployment) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Positive Profit" "Positive Profit" "Positive Profit" "Profit >= 10k" ///
	"Profit >= 10k" 	"Profit >= 10k") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append  
*/	
	
**# Table 9 Logistic Regressions of Profit on Initial Employment Status
*------------------------------------------------------------------------------|
esttab prof*mode* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 9. Logistic Regressions Profit on Initial Employment Status) ///
	varlabels(_cons Constant) ///
	mtitles("Positive Profit" "" "" "Profit >= 10k" "" 	"") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  
/*
	esttab mix_prof*mode* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 10. Mixed: Logistic Regressions Profit on Initial Employment Status) ///
	varlabels(_cons Constant) ///
	nonumbers mtitles("Positive Profit" "" "" "Profit >= 10k" ///
	"" 	"") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  

*/
	
*------------------------------------------------------------------------------|
**# Regressions for business value
*------------------------------------------------------------------------------|

	
**# Table 4A Regressions Business Value on Unemployment
*------------------------------------------------------------------------------|
esttab ln_tbsjval_unemp_* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*unemp* *combine*) ///
	title(Table 4A. Regressions Business Value on Unemployment) ///
	varlabels(_cons Constant) ///
	mtitles("Log Business Value" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  
	
/*	
esttab mix_ln_tbsjval_unemp_* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	order(*unemp* *combine*) ///
	title(Table 1A. Mixed: Regressions Business Value on Unemployment) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Log Business Value" "Log Business Value" "Log Business Value") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append 
*/

**# Table 5A Regressions Business Value on Initial Employment Status
*------------------------------------------------------------------------------|
esttab ln_tbsjval_mode_* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 5A. Regressions Business Value on Initial Employment Status) ///
	varlabels(_cons Constant) ///
	nonumbers mtitles("Log Business Value" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  
	
/*
esttab mix_ln_tbsjval_mode_* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 27. Mixed: Regressions Business Value on Initial Employment Status) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Log Business Value" "Log Business Value" "Log Business Value") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append  
*/	
	
	