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

list ssuid_spanel_pnum_id if _merge_avg >2 & _merge_avg <3 in 1/100
list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tjb_mwkhrs tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==5
// by bringing in the monthly data we get the full 12 months for this person. previously missing months 9 and 10 in the job only data set 


/***
<html>
<body>
<p>examining how our job variables overlap with unemployment flag that we brought in reingesting data for sipp_monthly_combined in data. <br>
 Wave 4 month 7 here we see that you can be marked as a jobless spell even if you get recorded as a job during the month given there can be gaps in <br>
  start/end weeks that don't stretch a full month-job </p>
***/
sort ssuid_spanel_pnum_id spanel swave monthcode ejb_startwk
list ssuid_spanel_pnum_id  swave monthcode job ejb_jborse ejb_startwk ejb_endwk enjflag  tjb_mwkhrs if ssuid_spanel_pnum_id ==199771 



// filtering to population of interest
keep if tage>=18 & tage<=64

codebook ejb_jborse

/***
<html>
<body>
<h3>Creating main job flag</h3>
***/
**# main job

gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 

duplicates report ssuid_spanel_pnum_id swave monthcode tjb_mwkhrs ejb_jobid  // no ties actually broken 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

sort ssuid_spanel_pnum_id swave monthcode 
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5
list ssuid_spanel_pnum_id ejb_jobid swave monthcode ejb_jobid tjb_mwkhrs jb_main ejb_jborse ejb_startwk ejb_endwk enjflag tpearn if ssuid_spanel_pnum_id==199771

keep if jb_main ==1 // gets us one record for each month with their main job or that they were unemployed 
recode enjflag (1=1 unemployed) (2=0 no), into(unemployed_flag)
codebook enjflag 
codebook unemployed_flag

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

// looking into odd cases here. These are instances where there's no ejb_jborse data but they have tpearn and don't get flagged as unemployed
list ssuid_spanel_pnum_id if employment_type1 == . 
list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type1 if ssuid_spanel_pnum_id==272
list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type1 if ssuid_spanel_pnum_id==937
list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type1 if ssuid_spanel_pnum_id==193993 

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

recode industry1 (0010/0560=1  "Agriculture, Forestry, Fishing and Hunting, and Mining") ///
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


list ssuid_spanel_pnum_id swave monthcode month_over employment_type1  if ssuid_spanel_pnum_id == 204

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
<h2>Earnings Models</h2>
***/

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

preserve
keep if unique_tag ==1 
keep if months_se_after_12 >0
// hist pct_se_after_12
su pct_se_after_12, detail 
restore 



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
drop if industry2 == 15 // dropping military members as we can't have SE military so no comparison group 
label variable tpearn "tpearn"


foreach var of varlist unempf12_6 mode_status_f12v2 educ3 combine_race_eth sex age immigrant parent industry2 calyear{

	drop if `var' == . 
}


// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=. 



su ln_tjb_msum ln_tpearn, detail

su tpearn tjb_msum, detail 

// What's going on with these extreme tpearn values? 
/*
list ssuid_spanel_pnum_id age combine_race_eth monthcode employment_type1 tpearn tjb_msum ejb_incpb tjb_empb tbsjval tjb_prftb tnetworth  if ssuid_spanel_pnum_id == 2392 | ssuid_spanel_pnum_id ==  150005 | ssuid_spanel_pnum_id ==  193139, sepby(ssuid_spanel_pnum_id) 
list ssuid_spanel_pnum_id employment_type1 if tpearn <= -100000

gen low_earnings = tpearn <= -50000
bysort ssuid_spanel_pnum_id: egen has_low_earnings = max(low_earnings)

preserve
keep if has_low_earnings == 1
unique ssuid_spanel_pnum_id
table ejb_incpb employment_type1, missing



restore

unique ssuid_spanel_pnum_id if tpearn >= 200000
gen high_earnings = tpearn >= 200000
bysort ssuid_spanel_pnum_id: egen has_high_earnings = max(high_earnings)

preserve
keep if has_high_earnings == 1 
tabstat tpearn, by(ssuid_spanel_pnum_id) stats(mean median sd min max n ) 
restore 

table employment_type1  ejb_incpb if has_high_earnings == 1


drop high_earnings has_high_earnings low_earnings has_low_earnings
*/

local logdate : di %tdCYND daily("$S_DATE", "DMY")
display `logdate'


global summarize_me = "i.sex age age2 immigrant parent industry2 i.educ3 i.combine_race_eth"
global controls  = "i.sex age age2 i.immigrant i.parent industry2 calyear"


label variable unempf12_6 "Unemployed 6-months"
label variable calyear "Year"


frame copy earnings collapsed_earnings, replace 
frame change collapsed_earnings 


collapse (mean) tpearn ln_tpearn tjb_msum ln_tjb_msum (max) educ3 (first) industry2 parent age, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth immigrant sex pct_se_after_12 unempf12_6 pct_ws_after_12)


label variable combine_race_eth "Race/Ethnicity"
label variable sex "Sex"
label variable age "Age"
label values immigrant immigrant_values
label variable immigrant "Immigrant"
label variable parent "Parent"

label define industry_labels 1  "Agriculture, Forestry, Fishing, and Mining" ///
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

label values industry2 industry_labels 
label variable industry2 "Industry"

label define education_labels 1 "High School or Less" 2 "Associates or Less" 3 "4-year Degree" 4 "Graduate Degree"
label values educ3 education_labels
label variable educ3 "Education"

label variable tpearn "Mean Monthly Earnings (tpearn)"
label variable ln_tpearn "Mean Log Monthly Earnings (tpearn)"
label variable tjb_msum "Mean Monthly Earnings (tjb_msum)"
label variable ln_tjb_msum "Mean Log Monthly Earnings (tjb_msum)"
 
label define parent_labels 1 "Parent" 0 "Not Parent"
label values parent parent_labels


label define immigrant_labels 1 "Immigrant" 0 "Native Born"
label  values immigrant immigrant_labels


gen tpearn_med = tpearn 
label variable tpearn_med "Median Monthly Earnings (tpearn)"
gen tjb_msum_med = tjb_msum
label variable tjb_msum_med "Median Monthly Earnings (tjb_msum)"

keep if pct_se_after_12 == 1 | pct_ws_after_12 == 1



**# Table 1

dtable i.sex i.combine_race_eth i.educ3 i.immigrant i.parent i.industry2 tpearn tpearn_med ln_tpearn  tjb_msum tjb_msum_med ln_tjb_msum, ///
	by(mode_status_f12v2) ///
	sample(, statistics(freq) place(seplabels)) ///
	continuous(tpearn_med tjb_msum_med, statistics(median)) /// 
	sformat("(N=%s)" frequency) ///
	note(Average earnings are grand means of individuals' average monthly earnings for any type of employment. Median earnings are the median of individual average monthly earnings. Initial employment status determined by individuals' most common employment status during first 12 months observed in data. Excluded from sample are those who dropped out of the SIPP sample after only one year of participation, months where individuals worked fewer than 15 hours, and "Other" employment types besides self-employed or wage and salaried.) ///
	column(by(hide)) ///
	nformat(%7.2f mean sd) ///
	title(Table 1. Descriptive Statistics by Initial Employment Status) 
	
putdocx begin 

putdocx collect 
putdocx pagebreak



**# Table 2
gen status_after_12 = "Self-Employed" if pct_se_after_12 == 1
replace  status_after_12 = "Wage-Salaried" if pct_ws_after_12 == 1

dtable i.sex i.combine_race_eth i.educ3 i.immigrant i.parent i.industry2 tpearn tpearn_med ln_tpearn tjb_msum tjb_msum_med ln_tjb_msum, by(status_after_12) ///
sample(, statistics(freq) place(seplabels)) ///
	continuous(tpearn_med tjb_msum_med, statistics(median)) /// 
	sformat("(N=%s)" frequency) ///	nformat(%7.2f mean sd) ///
	column(by(hide)) ///
	title(Table 2. Descriptive Statistics for Self-Employed Only and Wage and Salary Only Samples) ///
	note(Here, "Self-Employed" refers to those who from the 13th month of observation onwards were never unemployed and reported being self-employed for each month. Similarly, "Wage and Salary" refers to thoe who from the 13th month of observation onwards were never unemployed and reported being employed in a waged/salaried position for each month. Average earnings are grand means of individuals' average monthly earnings for any type of employment. Median earnings are the median of individual average monthly earnings. Excluded from sample are those who dropped out of the SIPP sample after only one year of participation, months where individuals worked fewer than 15 hours, and "Other" employment types besides self-employed or wage and salaried.)
	
putdocx collect 
putdocx pagebreak




*------------------------------------------------------------------------------|
* Full Sample (t-tests across unemployed flag within each race )
*------------------------------------------------------------------------------|
**# Table 3 Full sample table using mode_status_f12v2 
local x = 0
local names White Black Asian Hispanic Other
foreach name of local names {
	local x = `x' + 1
	collect create `name', replace 
	quietly: pwmean tpearn if combine_race_eth ==`x' , over(mode_status_f12v2) mcompare(dunnett) 
	collect get r(table) 
	collect remap rowname[b] = values[lev1], ///
		fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
	collect remap rowname[b] = values[lev2], ///
		fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
	collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])

	collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
}

collect create Full_Sample, replace 
quietly: pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], ///
	fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
collect remap rowname[b] = values[lev2], ///
	fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])

collect combine newc = Full_Sample White Black Asian Hispanic Other, replace
 
collect layout (collection#values) (mode_status_f12v2)  (), name(newc)
collect label levels mode_status_f12v2 1 "Wage/Salary" 2 "Self-Employed" 4 "Unemployed", replace
collect style row split, dups(first)
collect title "Table 3. Monthly Earnings Within Race/Ethnicity by Initial Employment Status (Full Sample)"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect

dtable i.combine_race_eth
putdocx collect 

**# Table 4 Full Sample table using unemployment 
collect create tpearn_race_unemp_within, replace 
quietly: collect r(N_1) r(mu_1) r(N_2) r(mu_2) r(p) Difference = (r(mu_2)-r(mu_1)): by combine_race_eth, sort: ttest tpearn, by(unempf12_6)
quietly: collect r(N_1) r(mu_1) r(N_2) r(mu_2) r(p) Difference = (r(mu_2)-r(mu_1)): ttest tpearn, by(unempf12_6)
collect remap result[N_1 mu_1] = Employed
collect remap result[N_2 mu_2] = Unemployed
collect remap result[p] = Significant
collect label dim cmdset "Race/Ethnicity", modify
collect label levels cmdset 1 "White" 2 "Black" 3 "Asian" 4 "Hispanic" 5 "Other" 6 "Full Sample", modify
collect style header Employed Unemployed Difference Significant, title(name)
collect layout (cmdset) (Employed Unemployed result Significant )
collect label levels Employed N_1 "N" mu_1 "Mean Earnings"
collect label levels Unemployed N_2 "N" mu_2 "Mean Earnings"
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect style cell Employed[mu_1] Unemployed[mu_2] Significant[p] result, nformat(%5.2f)
collect title "Table 4. Monthly Earnings Comparisons by Unemployment Experience within Race/Ethnicity (Full Sample)"
collect notes "Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings of those who experienced unemployment for 6-months during first 12 months in data versus those who experienced fewer than 6 months unemployment during first 12 months in data."
collect preview

putdocx collect
putdocx pagebreak

**# Table 5 Full Sample (any earnings) Between Race Earnings by Unemployment Experience

*------------------------------------------------------------------------------|
*Between Race differences Full Sample
*------------------------------------------------------------------------------|

// get the mean tpearn values here
collect create Full_Sample, replace 
quietly: pwmean tpearn, over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])


collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// unemployed 
collect create Unemployed, replace 
quietly: pwmean tpearn if unempf12_6 ==1 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// not unemployed 
collect create Employed, replace 
quietly: pwmean tpearn if unempf12_6 ==0 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// combine them into one 
collect combine newc = Full_Sample Employed Unemployed, replace 
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 5. Monthly Earnings Comparisons by Race/Ethnicity and Unemployment Experience (Full Sample)"
collect notes "Unemployed here refers to those who reported at least 6 consecutive months of unemployment during their first 12 months in the data. Employed refers to those who reported fewer than 6 consecutive months of unemployment during their first 12 months in the data. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect 

dtable i.combine_race_eth if unempf12_6 == 0
putdocx collect 
dtable i.combine_race_eth if unempf12_6 == 1 
putdocx collect 
putdocx pagebreak

**# Table 6 Full Sample (any earnings) Between Race/Ethnicity within Initial Employment Status 
*------------------------------------------------------------------------------|
*Between Race differences using modal status flag
*------------------------------------------------------------------------------|

collect create salaried, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==1 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)



// self-employed 
collect create self_employed, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==2 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)

// unemployed
collect create unemployed_start, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==4 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// combine them into one 
collect combine newc = Full_Sample salaried self_employed unemployed_start, replace 
collect label levels collection Full_Sample "Full Sample" salaried "Wage & Salary" ///
self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 6. Monthly Earnings Comparisons by Race/Ethnicity and Initial Employment Status (Full Sample)"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview


putdocx collect
putdocx pagebreak


*------------------------------------------------------------------------------|
* WS Sample (t-tests across unemployed flag within each race )
*------------------------------------------------------------------------------|
**# Table 7: Salaried Sample by unemployment experience within race
preserve
keep if pct_ws_after_12 == 1
collect create tpearn_race_unemp_within_ws, replace 
quietly: collect r(N_1) r(mu_1) r(N_2) r(mu_2) r(p) Difference = (r(mu_2)-r(mu_1)): by combine_race_eth, sort: ttest tpearn, by(unempf12_6)
collect layout (combine_race_eth) (result)
collect remap result[N_1 mu_1] = Employed
collect remap result[N_2 mu_2] = Unemployed
collect remap result[p] = Significant
collect remap Difference = Difference 
collect style header Employed Unemployed Difference Significant, title(name)
collect layout (combine_race_eth) (Employed Unemployed result Significant )
collect label levels Employed N_1 "N" mu_1 "Mean Earnings"
collect label levels Unemployed N_2 "N" mu_2 "Mean Earnings"
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect style cell Employed[mu_1] Unemployed[mu_2] Significant[p] result, nformat(%5.2f)
collect title "Table 7. Salaried Sample Monthly Earnings Comparisons by Unemployment Experience within Race/Ethnicity"
collect notes "This table is restricted to respondents who from the 13th month of observation onwards were never unemployed and reported being employed in a waged/salaried position for each month. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings of those who experienced unemployment for 6-months during first 12 months in data versus those who experienced fewer than 6 months unemployment during first 12 months in data."
collect preview

putdocx collect 
putdocx pagebreak


**# Table 8. Salaried Sample by initial status within race 
local x = 0
local names White Black Asian Hispanic Other
foreach name of local names {
	local x = `x' + 1
	collect create `name', replace 
	quietly: pwmean tpearn if combine_race_eth ==`x' , over(mode_status_f12v2) mcompare(dunnett) 
	collect get r(table) 
	collect remap rowname[b] = values[lev1], ///
		fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
	collect remap rowname[b] = values[lev2], ///
		fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
	collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])

	collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
}

collect create Full_Sample, replace 
quietly: pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], ///
	fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
collect remap rowname[b] = values[lev2], ///
	fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])

collect combine newc = Full_Sample White Black Asian Hispanic Other, replace
 
collect layout  (collection#values) (mode_status_f12v2) (), name(newc)
collect label levels mode_status_f12v2 1 "Wage/Salary" 2 "Self-Employed" 4 "Unemployed", replace
collect style row split, dups(first)
collect title "Table 8. Monthly Earnings Within Race/Ethnicity by Initial Employment Status (Salaried Sample)"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction. Salaried sample is defined as those who reported continous wage or salary employment from month 13-onwards."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect



**# Table 9 Salaried Sample Between Race Earnings by Unemployment Experience
// get the mean tpearn values here
collect create Full_Sample, replace 
quietly: pwmean tpearn, over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])


collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// unemployed 
collect create Unemployed, replace 
quietly: pwmean tpearn if unempf12_6 ==1 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// not unemployed 
collect create Employed, replace 
quietly: pwmean tpearn if unempf12_6 ==0 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// combine them into one 
collect combine newc = Full_Sample Employed Unemployed, replace 
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 9. Monthly Earnings Comparisons by Race/Ethnicity and Unemployment Experience (Wage/Salary Sample)"
collect notes "Unemployed here refers to those who reported at least 6 consecutive months of unemployment during their first 12 months in the data. Employed refers to those who reported fewer than 6 consecutive months of unemployment during their first 12 months in the data. Wage/Salary sample refers to those who were continously employed in wage/salary positions from month 13 onwards. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect 

dtable i.combine_race_eth if unempf12_6 == 0
putdocx collect 
dtable i.combine_race_eth if unempf12_6 == 1 
putdocx collect 
putdocx pagebreak





**# Table 10 Salaried Sample Between Race/Ethnicity within Initial Employment Status 

*------------------------------------------------------------------------------|

collect create salaried, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==1 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)



// self-employed 
collect create self_employed, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==2 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)

// unemployed
collect create unemployed_start, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==4 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// combine them into one 
collect combine newc = Full_Sample salaried self_employed unemployed_start, replace 
collect label levels collection Full_Sample "Full Sample" salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 10. Monthly Earnings Comparisons by Race/Ethnicity and Initial Employment Status (Wage/Salary Sample)"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Wage/Salary refers to those who were continously employed in wage/salary positions from month 13 onwards. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview


putdocx collect
putdocx pagebreak


restore 





*------------------------------------------------------------------------------|
* SE Sample (t-tests across unemployed flag within each race )
*------------------------------------------------------------------------------|
**# Table 11 Self-employed sample by unemployment within race 
preserve
keep if pct_se_after_12 == 1 




collect create tpearn_race_unemp_within_se, replace 
quietly: collect r(N_1) r(mu_1) r(N_2) r(mu_2) r(p) Difference = (r(mu_2)-r(mu_1)): by combine_race_eth, sort: ttest tpearn, by(unempf12_6)
collect layout (combine_race_eth) (result)
collect remap result[N_1 mu_1] = Employed
collect remap result[N_2 mu_2] = Unemployed
collect remap result[p] = Significant
collect remap Difference = Difference 
collect style header Employed Unemployed Difference Significant, title(name)
collect layout (combine_race_eth) (Employed Unemployed result Significant )
collect label levels Employed N_1 "N" mu_1 "Mean Earnings"
collect label levels Unemployed N_2 "N" mu_2 "Mean Earnings"
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect style cell Employed[mu_1] Unemployed[mu_2] Significant[p] result, nformat(%5.2f)
collect title "Table 11. Self-Employed Sample Monthly Earnings Comparisons by Unemployment Experience within Race/Ethnicity"
collect notes "Self-employed refers to those who from the 13th month of observation onwards were never unemployed and reported being self-employed for each month. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings of those who experienced unemployment for 6-months during first 12 months in data versus those who experienced fewer than 6 months unemployment during first 12 months in data."
collect preview
putdocx collect 
putdocx pagebreak





**# Table 12. Self-Employed Sample by initial status within race 
local x = 0
local names White Black Asian Hispanic Other
foreach name of local names {
	local x = `x' + 1
	collect create `name', replace 
	quietly: pwmean tpearn if combine_race_eth ==`x' , over(mode_status_f12v2) mcompare(dunnett) 
	collect get r(table) 
	collect remap rowname[b] = values[lev1], ///
		fortags(colname[1.mode_status_f12v2 2.mode_status_f12v2 4.mode_status_f12v2])
	collect remap rowname[b] = values[lev2], ///
		fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])
	collect remap rowname[se] = values[lev3], fortags(colname[2vs1.mode_status_f12v2  4vs1.mode_status_f12v2])

	collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
}

collect create Full_Sample, replace 
quietly: pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) //already filtered to pct_se_after_12 == 1 above
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

collect title "Table 12. Monthly Earnings Within Race/Ethnicity by Initial Employment Status (Self-Employed Sample)"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction. Self-Employed sample is defined as those who were continously self-emplyed from month 13-onwards."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect




**# Table 13 Self-Employed Sample Between Race Earnings by Unemployment Experience
// get the mean tpearn values here
collect create Full_Sample, replace 
quietly: pwmean tpearn, over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])


collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// unemployed 
collect create Unemployed, replace 
quietly: pwmean tpearn if unempf12_6 ==1 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// not unemployed 
collect create Employed, replace 
quietly: pwmean tpearn if unempf12_6 ==0 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// combine them into one 
collect combine newc = Full_Sample Employed Unemployed, replace 
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 13. Monthly Earnings Comparisons by Race/Ethnicity and Unemployment Experience (Self-Employed Sample)"
collect notes "Unemployed here refers to those who reported at least 6 consecutive months of unemployment during their first 12 months in the data. Employed refers to those who reported fewer than 6 consecutive months of unemployment during their first 12 months in the data. Self-employed sample refers to those who were continously self-employed from month 13 onwards. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect 

dtable i.combine_race_eth if unempf12_6 == 0
putdocx collect 
dtable i.combine_race_eth if unempf12_6 == 1 
putdocx collect 
putdocx pagebreak





**# Table 14 Self-employed Sample Between Race/Ethnicity within Initial Employment Status 

*------------------------------------------------------------------------------|

collect create salaried, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==1 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)



// self-employed 
collect create self_employed, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==2 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)

// unemployed
collect create unemployed_start, replace 
quietly: pwmean tpearn if mode_status_f12v2 ==4 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// combine them into one 
collect combine newc = Full_Sample salaried self_employed unemployed_start, replace 
collect label levels collection Full_Sample "Full Sample" salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 14. Monthly Earnings Comparisons by Race/Ethnicity and Initial Employment Status (Self-Employed Sample)"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Self-Employed refers to those who were continously self-employed from month 13 onwards. Mean earnings are calculated as a grand mean of person level average monthly earnings as reported in the tpearn variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview


putdocx collect
putdocx pagebreak

restore 










**# Earnings Models 


frame change earnings
xtset ssuid_spanel_pnum_id month_overall

keep if pct_se_after_12 == 1 | pct_ws_after_12 == 1



quietly xtreg ln_tpearn i.unempf12_6, vce(robust) 
eststo any_earn_unemp_m1 

quietly xtreg ln_tpearn i.unempf12_6 i.educ3 i.combine_race_eth $controls, vce(robust) 
eststo any_earn_unemp_m2


quietly xtreg ln_tpearn i.mode_status_f12v2, vce(robust) 
eststo any_earn_mode_m1 

quietly xtreg ln_tpearn i.mode_status_f12v2 i.educ3 i.combine_race_eth $controls, vce(robust) 
eststo any_earn_mode_m2

preserve 
keep if pct_se_after_12 == 1 
quietly xtreg ln_tpearn i.unempf12_6, vce(robust) 
eststo se_earn_unemp_m1 

quietly xtreg ln_tpearn i.unempf12_6 i.educ3 i.combine_race_eth $controls, vce(robust) 
eststo se_earn_unemp_m2


quietly xtreg ln_tpearn i.mode_status_f12v2, vce(robust) 
eststo se_earn_mode_m1 

quietly xtreg ln_tpearn i.mode_status_f12v2 i.educ3 i.combine_race_eth $controls, vce(robust) 
eststo se_earn_mode_m2

restore 


preserve 
keep if pct_ws_after_12 == 1

quietly xtreg ln_tpearn i.unempf12_6, vce(robust) 
eststo ws_earn_unemp_m1 

quietly xtreg ln_tpearn i.unempf12_6 i.educ3 i.combine_race_eth $controls, vce(robust) 
eststo ws_earn_unemp_m2


quietly xtreg ln_tpearn i.mode_status_f12v2, vce(robust) 
eststo ws_earn_mode_m1 

quietly xtreg ln_tpearn i.mode_status_f12v2 i.educ3 i.combine_race_eth $controls, vce(robust)  
eststo ws_earn_mode_m2

restore 



**# Table 15 Regression Earnings on Unemployment 
esttab any_earn_unemp* se_earn_unemp* ws_earn_unemp* using draft_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 15: Relationship between Unemployment and Log Earnings) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Full Sample" "Full Sample" "Self-Employed Sample" ///
	"Self-Employed Sample" "Salaried Sample" "Salaried Sample") ///
	addnote("Source: SIPP Data. Dependent Variable is log of tpearn") ///
	compress onecell replace  

**# Table 16: Regression Earnings on Initial Employment Status
esttab any_earn_mode* se_earn_mode* ws_earn_mode* using draft_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 16: Relationship between Initial Employment Status and Log Earnings) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Full Sample" "Full Sample" "Self-Employed Sample" ///
	"Self-Employed Sample" "Salaried Sample" "Salaried Sample") ///
	addnote("Source: SIPP Data Dependent Variable is log of tpearn") ///
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
unempf12_6 mode_status_f12v2 in 1/50 if pct_se_after_12 ==1, sepby(ssuid_spanel_pnum_id) abbrev(10)



// getting to sample of interest
keep if pct_se_after_12 == 1 

frame copy profits profits_collapse, replace 
frame change profits_collapse

collapse (mean) tjb_prftb tbsjval ln_tjb_prftb ln_tbsjval (max) educ3 (first) industry2 parent age, by(ssuid_spanel_pnum_id mode_status_f12v2 combine_race_eth immigrant sex unempf12_6 pct_ws_after_12)
label variable combine_race_eth "Race/Ethnicity"
label variable sex "Sex"
label variable age "Age"
label values immigrant immigrant_values
label variable immigrant "Immigrant"
label variable parent "Parent"
label variable unempf12_6 "Unemployed 6-months"

label values industry2 industry_labels 
label variable industry2 "Industry"

label values educ3 education_labels
label variable educ3 "Education"

label variable tjb_prftb "Mean Annual Profit (tjb_prftb)"
label variable ln_tjb_prftb "Mean Log Annual Profit (ln_tjb_prftb)"
label variable tbsjval "Mean Annual Business Value (tbsjval)"
label variable ln_tbsjval "Mean Log Annual Business Value (ln_tbsjval)"


gen tjb_prftb_med = tjb_prftb 
label variable tjb_prftb_med "Median Annual Profit Earnings (tjb_prftb)"
gen tbsjval_med = tbsjval
label variable tbsjval_med "Median Annual Business Value (tbsjval)"

**# Table 17: Descriptive Stats for SE Sample and Profit and Business Value 
dtable i.sex i.combine_race_eth i.educ3 immigrant parent i.industry2 tjb_prftb tjb_prftb_med ln_tjb_prftb tbsjval tbsjval_med ln_tbsjval, ///
	by(unempf12_6) ///
	continuous(tjb_prftb_med tbsjval_med, statistics(median)) /// 
	sample(, statistics(freq) place(seplabels)) ///
	sformat("(N=%s)" frequency) ///
	column(by(hide)) ///
	nformat(%5.1f mean sd) ///
	title(Table 17. Descriptive Statistics for Self-Employed Sample and Profitability) /// 
	note(Self-employed refers to those who from the 13th month of observation onwards were never unemployed and reported being self-employed for each month. Mean profits are calculated as a grand mean of person level average annual profits as reported in the tjb_prftb variable. Unemployed are defined as those who experienced unemployment for at least 6 consecutive months during first 12 months in data versus those who experienced fewer than 6 consecutive months unemployment during first 12 months in data.) 
	
	
**# Table 18: Profit by Race/Ethnicity using mode_statu

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
collect title "Table 18. Profit within Race/Ethnicity by Initial Employment Status"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean profit is calculated as a grand mean of person level average annual profit as reported in the tjb_msum variable. T-tests run comparing average profit using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect

dtable i.combine_race_eth
putdocx collect 

**# Table 19 Profit within Race by unemployment 
collect create tjb_prftb_race_unemp_within, replace 
quietly: collect r(N_1) r(mu_1) r(N_2) r(mu_2) r(p) Difference = (r(mu_2)-r(mu_1)): by combine_race_eth, sort: ttest tjb_prftb, by(unempf12_6)
quietly: collect r(N_1) r(mu_1) r(N_2) r(mu_2) r(p) Difference = (r(mu_2)-r(mu_1)): ttest tjb_prftb, by(unempf12_6)
collect remap result[N_1 mu_1] = Employed
collect remap result[N_2 mu_2] = Unemployed
collect remap result[p] = Significant
collect label dim cmdset "Race/Ethnicity", modify
collect label levels cmdset 1 "White" 2 "Black" 3 "Asian" 4 "Hispanic" 5 "Other" 6 "Full Sample", modify
collect style header Employed Unemployed Difference Significant, title(name)
collect layout (cmdset) (Employed Unemployed result Significant )
collect label levels Employed N_1 "N" mu_1 "Mean Earnings"
collect label levels Unemployed N_2 "N" mu_2 "Mean Earnings"
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect style cell Employed[mu_1] Unemployed[mu_2] Significant[p] result, nformat(%5.2f)
collect title "Table 19. Profit Comparisons by Unemployment Experience within Race/Ethnicity"
collect notes "Mean profit is calculated as a grand mean of person level average annual profit as reported in the tjb_msum variable. T-tests run comparing average profits of those who experienced unemployment for 6-months during first 12 months in data versus those who experienced fewer than 6 months unemployment during first 12 months in data."
collect preview

putdocx collect
putdocx pagebreak


**# Table 20  Profitability Between Race Comparisons by Unemployment Experience 

collect create Full_Sample, replace 
quietly: pwmean tjb_prftb, over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])


collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// unemployed 
collect create Unemployed, replace 
quietly: pwmean tjb_prftb if unempf12_6 ==1 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// not unemployed 
collect create Employed, replace 
quietly: pwmean tjb_prftb if unempf12_6 ==0 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// combine them into one 
collect combine newc = Full_Sample Employed Unemployed, replace 
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 20. Profit Comparisons by Race/Ethnicity and Unemployment Experience"
collect notes "Unemployed here refers to those who reported at least 6 consecutive months of unemployment during their first 12 months in the data. Employed refers to those who reported fewer than 6 consecutive months of unemployment during their first 12 months in the data. Mean profit is calculated as a grand mean of person level average yearly profit as reported in the tjb_prftb variable. T-tests run comparing average profit using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect 

dtable i.combine_race_eth if unempf12_6 == 0
putdocx collect 
dtable i.combine_race_eth if unempf12_6 == 1 
putdocx collect 
putdocx pagebreak

**# Table 21 Profit Comparison Between Race/Ethnicity within Initial Employment Status 

collect create salaried, replace 
quietly: pwmean tjb_prftb if mode_status_f12v2 ==1 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)



// self-employed 
collect create self_employed, replace 
quietly: pwmean tjb_prftb if mode_status_f12v2 ==2 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)

// self-employed 
collect create unemployed_start, replace 
quietly: pwmean tjb_prftb if mode_status_f12v2 ==4 , over(combine_race_eth) mcompare(dunnett) 
collect get r(table) 
collect remap rowname[b] = values[lev1], fortags(colname[1.combine_race_eth 2.combine_race_eth 3.combine_race_eth 4.combine_race_eth 5.combine_race_eth])
collect remap rowname[b] = values[lev2], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])
collect remap rowname[se] = values[lev3], fortags(colname[2vs1.combine_race_eth 3vs1.combine_race_eth 4vs1.combine_race_eth 5vs1.combine_race_eth])

collect label levels values lev1 "Mean" lev2 "Difference" lev3 "Std. Error"
collect layout (combine_race_eth) (values)


// combine them into one 
collect combine newc = Full_Sample salaried self_employed unemployed_start, replace 
collect label levels collection Full_Sample "Full Sample" salaried "Wage & Salary" self_employed "Self-Employed" unemployed_start "Unemployed"
collect layout (combine_race_eth) (collection#values) (), name(newc)
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect title "Table 21. Profit Comparisons by Race/Ethnicity and Initial Employment Status"
collect notes "Initial employment status is determined by individuals' most common employment status during first 12 months observed in data. Mean profit are calculated as a grand mean of person level average annual profits as reported in the tjb_prftb variable. T-tests run comparing average monthly earnings using Dunnett multiple comparison correction."
collect style cell values, nformat(%5.1f)
collect preview
putdocx collect

collect create n_counts, replace
table combine_race_eth mode_status_f12v2 
collect layout (combine_race_eth) (mode_status_f12v2)
putdocx collect 

putdocx pagebreak

putdocx save draft_outputs_`logdate'_collects, replace 



*------------------------------------------------------------------------------|
** Profit Modeling
*------------------------------------------------------------------------------|

frame change profits 
xtset ssuid_spanel_pnum_id calyear 

foreach y of varlist profpos prof10k   {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtlogit `y' i.`x', vce(robust)  
		eststo `y'_`xname'_1re

		quietly xtlogit `y' i.`x' i.educ3 i.combine_race_eth $controls , vce(robust) 
		eststo `y'_`xname'_2re
}
}

foreach y of varlist ln_tjb_prftb ln_tbsjval   {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust) 
		eststo `y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3 i.combine_race_eth $controls , vce(robust) 
		eststo `y'_`xname'_2re

}
}



**# Regressions for Profits 
esttab prof*unemp* using draft_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 22. Logistic Regressions Profit on Unemployment) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Positive Profit" "Positive Profit" "Profit >= 10k" ///
	"Profit >= 10k") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append  

	
esttab prof*mode* using draft_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 23. Logistic Regressions Profit on Initial Employment Status) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Positive Profit" "Positive Profit" "Profit >= 10k" ///
	"Profit >= 10k") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append  

esttab ln_tjb_prftb_unemp* using draft_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 24. Regressions Profit on Unemployment) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Log Profit" "Log Profit") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append  
	
esttab ln_tjb_prftb_mode* using draft_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 25. Regressions Profit on Initial Employment Status) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Log Profit" "Log Profit") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append  

**# Regressions for business value 
esttab *jval*, legend label varlabels(_cons Constant) title(Business Value  Models) aic bic 
	
esttab ln_tbsjval_unemp_* using draft_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 26. Regressions Profit on Unemployment) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Log Business Value" "Log Business Value") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append  

esttab ln_tbsjval_mode_* using draft_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 27. Regressions Profit on Initial Employment Status) ///
	varlabels(_cons Constant 1.educ3 "HS or Less" 2.educ3  ///
	"Some College or Assoc." 3.educ3 "4-year College" 4.educ3 "Graduate Degree") ///
	nonumbers mtitles("Log Business Value" "Log Business Value") ///
	addnote("Source: SIPP Data.") ///
	compress onecell append  
	
	
**# Plots for unemployment 
label define unemp_labels 0 "Not Unemployed" 1 "Unemployed"
label values unempf12_6 unemp_labels
cd "/Users/toddnobles/Documents/sipp_analyses/"
local logdate : di %tdCYND daily("$S_DATE", "DMY")
display `logdate'

putdocx begin 
xtlogit prof10k i.unempf12_6 i.educ3 i.combine_race_eth $controls , vce(robust) 
/*
margins unempf12_6, at(combine_race_eth =(1 2 3 4) ) at((asobserved) _all)  post
est sto m1
coefplot (m1, keep(5*) asequation(Full Sample) \m1, ///
keep(1*) asequation(White) \m1, ///
keep(2*) asequation(Black) \m1, ///
keep(3*) asequation(Asian) \m1, ///
keep(4*) asequation(Hispanic)), vert xlabel(, angle(45) labsize(tiny)) 
*/
**# Unemployment Profit 10k scatter
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


margins unempf12_6, at(combine_race_eth =(1 2 3 4) ) 
marginsplot, recast(scatter) xdimension(combine_race_eth) title("Race/Ethnicity") ///
xtitle("Race/Ethnicity") ytitle("") ylabel(0(.1).6) saving(g2, replace ) 

grc1leg  g1.gph g2.gph , ycommon legend(g2.gph) title("Predicted Probability of Profit >= $10,000")  ///
subtitle("by Unemployment") 

graph export temp.png, replace
putdocx paragraph, halign(center)
putdocx image temp.png

**# Unemployment Profit 10k bar
margins unempf12_6, saving(tempmargins, replace)
preserve
clear
use tempmargins
twoway (bar _margin _term, sort colorvar(_m1) colordiscrete colorcuts(0 1) colorlist(stc1 stc2) clegend(off))  ///
(rcap _ci_lb _ci_ub _term, lcolor(black)) ///
(scatter _margin _term if _m1==0, sort mc("black") ) ///
(scatter _margin _term if _m1==1, sort mc("black")), ///
title("Overall Sample") xlabel(1 "Overall") xtitle("") ///
ytitle("Probability of Profit >= 10k") saving(g1, replace) fxsize(50) ylabel(0(.1).6)
restore


margins unempf12_6, at(combine_race_eth =(1 2 3 4) ) 
marginsplot, recast(bar) xdimension(combine_race_eth) title("Race/Ethnicity") ///
xtitle("") ytitle("") ylabel(0(.1).6) saving(g2, replace ) 

grc1leg2  g1.gph g2.gph , ycommon legendfrom(g2.gph) title("Predicted Probability of Profit >= $10,000")  ///
subtitle("by Unemployment") 
graph export temp.png, replace
putdocx paragraph, halign(center)
putdocx image temp.png




**# Unemployment Positive Profit Scatter
xtlogit profpos i.unempf12_6 i.educ3 i.combine_race_eth $controls , vce(robust) 

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


margins unempf12_6, at(combine_race_eth =(1 2 3 4) ) 
marginsplot, recast(scatter) xdimension(combine_race_eth) title("Race/Ethnicity") ///
xtitle("Race/Ethnicity") ytitle("") ylabel(0(.1).6) saving(g2, replace ) 

grc1leg  g1.gph g2.gph , ycommon legend(g2.gph) title("Predicted Probability of Positive Profit")  ///
subtitle("by Unemployment") 

graph export temp.png, replace
putdocx paragraph, halign(center)
putdocx image temp.png



**# Unemployment Positve Profit Bar
margins unempf12_6, saving(tempmargins, replace)
preserve
clear
use tempmargins
twoway (bar _margin _term, sort colorvar(_m1) colordiscrete colorcuts(0 1) colorlist(stc1 stc2) clegend(off))  ///
(rcap _ci_lb _ci_ub _term, lcolor(black)) ///
(scatter _margin _term if _m1==0, sort mc("black") ) ///
(scatter _margin _term if _m1==1, sort mc("black")), ///
title("Overall Sample") xlabel(1 "Overall") xtitle("") ///
ytitle("Probability of Positive Profit") saving(g1, replace) fxsize(50) ylabel(0(.1).6)
restore


margins unempf12_6, at(combine_race_eth =(1 2 3 4) ) 
marginsplot, recast(bar) xdimension(combine_race_eth) title("Race/Ethnicity") ///
xtitle("") ytitle("") ylabel(0(.1).6) saving(g2, replace ) 

grc1leg2  g1.gph g2.gph , ycommon legendfrom(g2.gph)  title("Predicted Probability of Positive Profit")  ///
subtitle("by Unemployment") 
graph export temp.png, replace
putdocx paragraph, halign(center)
putdocx image temp.png





**# Plots for modal status

**# Modal status Profit 10k scatter
recode mode_status_f12v2 (1=1) (2=2) (4=3), generate(rescaled_mode_status)
label define status_labs 1 "Wage/Salary" 2 "Self-Employed" 3 "Unemployed"
label values rescaled_mode_status status_labs

xtlogit prof10k i.rescaled_mode_status i.educ3 i.combine_race_eth $controls , vce(robust) 

margins rescaled_mode_status, saving(tempmargins, replace)
preserve
clear
use tempmargins
twoway (rcap _ci_lb _ci_ub _m1, sort colorvar(_m1) colordiscrete colorcuts(1 2 3) colorlist(stc1 stc2 stc3) clegend(off)) ///
(scatter _margin _m1 if _m1==1, sort mc("stc1") ) ///
(scatter _margin _m1 if _m1==2, sort mc("stc2")) ///
(scatter _margin _m1 if _m1==3, sort mc("stc3")), ///
legend(off) title("Overall Sample") xlabel(1 "Wage/Salary" 2 "Self-Employed" 3 "Unemployed") xtitle("") ///
ytitle("Probability of Profit >= $10,000") saving(g1, replace) fxsize(50) ylabel(0(.1).6)
restore


margins rescaled_mode_status, at(combine_race_eth =(1 2 3 4) ) 
mplotoffset, recast(scatter) offset(.1)  xdimension(combine_race_eth) title("Race/Ethnicity") ///
ytitle("") ylabel(0(.1).6) saving(g2, replace ) legend(cols(3)) xtitle("")


grc1leg  g1.gph g2.gph , ycommon legend(g2.gph) title("Predicted Probability of Profit >= $10,000")  ///
subtitle("by Initial Employment Status") 

graph export temp.png, replace
putdocx paragraph, halign(center)
putdocx image temp.png




**# Modal status Profit 10k bar
margins rescaled_mode_status, saving(tempmargins, replace)
preserve
clear
use tempmargins
twoway (bar _margin _m1, sort colorvar(_m1) colordiscrete colorcuts(1 2 3) colorlist(stc1 stc2 stc3) clegend(off))  ///
(rcap _ci_lb _ci_ub _m1, lcolor(black)) ///
(scatter _margin _m1 if _m1==1, sort mc("black") ) ///
(scatter _margin _m1 if _m1==2, sort mc("black")) ///
(scatter _margin _m1 if _m1==3, sort mc("black")), ///
title("Overall Sample") xlabel(2 "Overall") xtitle("") ///
ytitle("Probability of Profit >= $10,000") saving(g1, replace) fxsize(50) ylabel(0(.1).6)
restore


margins rescaled_mode_status, at(combine_race_eth =(1 2 3 4) ) 
mplotoffset, offset(.25) recast(bar) xdimension(combine_race_eth) title("Race/Ethnicity") ///
xtitle("") ytitle("") ylabel(0(.1).6) saving(g2, replace )  plotopts(barw(.25)) legend(cols(3))

grc1leg  g1.gph g2.gph , ycommon legend(g2.gph) title("Predicted Probability of Profit >= $10,000")  ///
subtitle("by Initial Employment Status") 

graph export temp.png, replace
putdocx paragraph, halign(center)
putdocx image temp.png


**# Modal status Positive Profit scatter
xtlogit profpos i.rescaled_mode_status i.educ3 i.combine_race_eth $controls , vce(robust) 


margins rescaled_mode_status, saving(tempmargins, replace)
preserve
clear
use tempmargins
twoway (rcap _ci_lb _ci_ub _m1, sort colorvar(_m1) colordiscrete colorcuts(1 2 3) colorlist(stc1 stc2 stc3) clegend(off)) ///
(scatter _margin _m1 if _m1==1, sort mc("stc1") ) ///
(scatter _margin _m1 if _m1==2, sort mc("stc2")) ///
(scatter _margin _m1 if _m1==3, sort mc("stc3")), ///
legend(off) title("Overall Sample") xlabel(1 "Wage/Salary" 2 "Self-Employed" 3 "Unemployed") xtitle("") ///
ytitle("Probability of Positive Profit") saving(g1, replace) fxsize(50) ylabel(0(.1).6)
restore


margins rescaled_mode_status, at(combine_race_eth =(1 2 3 4) ) 
mplotoffset, offset(0.1) recast(scatter) xdimension(combine_race_eth) /// 
title("Race/Ethnicity") ///
ytitle("") ylabel(0(.1).6) saving(g2, replace ) legend(cols(3)) xtitle("")


grc1leg  g1.gph g2.gph , ycommon legend(g2.gph) title("Predicted Probability of Positive Profit")  ///
subtitle("by Initial Employment Status") 

graph export temp.png, replace
putdocx paragraph, halign(center)
putdocx image temp.png

**# Modal Status Positive Profit Bar

margins rescaled_mode_status, saving(tempmargins, replace)
preserve
clear
use tempmargins
twoway (bar _margin _m1, sort colorvar(_m1) colordiscrete colorcuts(1 2 3) colorlist(stc1 stc2 stc3) clegend(off))  ///
(rcap _ci_lb _ci_ub _m1, lcolor(black)) ///
(scatter _margin _m1 if _m1==1, sort mc("black") ) ///
(scatter _margin _m1 if _m1==2, sort mc("black")) ///
(scatter _margin _m1 if _m1==3, sort mc("black")), ///
title("Overall Sample") xlabel(2 "Overall") xtitle("") ///
ytitle("Probability of Positive Profit") saving(g1, replace) fxsize(50) ylabel(0(.1).6)
restore


margins rescaled_mode_status, at(combine_race_eth =(1 2 3 4) ) 
mplotoffset, offset(.25) recast(bar) xdimension(combine_race_eth) title("Race/Ethnicity") ///
xtitle("") ytitle("") ylabel(0(.1).6) saving(g2, replace )  plotopts(barw(.25)) legend(cols(3))

grc1leg  g1.gph g2.gph , ycommon legend(g2.gph) title("Predicted Probability of Positive Profit")  ///
subtitle("by Initial Employment Status") 

graph export temp.png, replace
putdocx paragraph, halign(center)
putdocx image temp.png




putdocx save draft_graphs`logdate', replace 

