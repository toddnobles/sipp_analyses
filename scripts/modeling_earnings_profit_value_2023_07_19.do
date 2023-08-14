webdoc init modeling_earnings_profit_2023_07_19, replace logall
webdoc toc 5

/***
<html>
<title>Descriptive analyses and preliminary multivariate models of earnings, profit and business value </title>

<p> Overview of this script: <br>
<br>
	- This script begins from the initial compiled files we create from the raw SIPP data. We then perform some formatting and 
tidying to get the data cleaned for analyses. <br>


Descriptive analyses: <br>
The first set of descriptive comparisons uses the dataset at the person-month level. 
Later in the script there is a similar analysis done using person level averages for their
average monthly earnings.



Models (Earnings):<br>
M1:<br>
Earnings = those who were unemployed versus those who were not or those who entered SE from WS vs Unemployment (base model)<br>
 <br>
M2:<br>
M1+ controls (demographic characteristics + industry + year)<br>
 <br>
Models (Profit and business value) <br>
M1: <br>
profit/business value  (base model) <br>
 <br>
M2: <br>
M1+ controls (demographic characteristics + industry + year </p> 
***/
clear all 
eststo clear 
local homepath "/Volumes/Extreme SSD/SIPP Data Files/"

local datapath "`homepath'/dtas"

cd "`datapath'"
set linesize 255


/***
<html>
<body>
<h2>Data Prep</h2>
<p> Note: This dataset being read in is created in the middle of the employment_pathway_earnings.do script. For profitability we can operate at yearly level as this value is reported at yearly level. 
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

recode tceb (1/7=1 "Have a child or more") (0=0 "Have no children"), gen(parent)
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


egen unique_tag = tag(ssuid_spanel_pnum_id) // unique id

frame copy default profits, replace
frame copy default earnings, replace
frame copy default bizvalue, replace 


global controls= "i.sex i.initial_hisp age age2 immigrant parent industry2 calyear"


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
hist pct_se_after_12
su pct_se_after_12, detail 
restore 

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


drop ejb_clwrk ejb_endwk ejb_jborse ejb_startwk ejb_incpb ejb_bslryb ejb_typpay1 ejb_jobid tjb_occ tjb_ind tjb_empb 
drop tjb_gamt1 tbsjdebtval tdebt_cc tdebt_ed tdebt_bus teq_bus tval_home tdebt_home teq_home tval_ast tdebt_ast 
drop tnetworth thdebt_cc thdebt_ed thval_home thdebt_home theq_home thval_ast thdebt_ast thnetworth

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
label variable tpearn "tpearn"

// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=. 


hist tpearn 
webdoc graph, hardcode nokeep
hist ln_tpearn 
webdoc graph, hardcode nokeep
hist tjb_msum 
webdoc graph, hardcode nokeep
hist ln_tjb_msum
webdoc graph, hardcode nokeep

su ln_tjb_msum ln_tpearn, detail

su tpearn tjb_msum


/***
<html>
<body>
<h2>Descriptive comparisons</h2>
<p>This first set of descriptive comparisons uses the dataset at the person-month level. 
Later in the script there is a similar analysis done using person level averages for their
average monthly earnings.</p>
***/

/***
<html>
<body>
<h3>WS/SE Earnings</h3>
***/

/***
<html>
<body>
<h4>Full Sample</h4>
<p></p>
***/
ttest tpearn, by(unempf12_6)
ttest tjb_msum, by(unempf12_6)
pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) effects 
pwmean tjb_msum, over(mode_status_f12v2) mcompare(dunnett) effects

/***
<html>
<body>
<h4>Between Race differences</h4>
<p> Here we see that earnings for whites are on average, greater than earnings for other groups except for Asians. 
These relationships hold looking at the subsample that experienced unemployment and the subsample that did 
not experience unemployment in their first 12 months. Likewise, these relationships hold within the subsamples of those who 
started as wage and salary, those who started as self-employed, and those who started as unemployed. The relationships are generally 
the same using either tjb_msum or tpearn. One instance the earnings measures matters is in comparing asian vs white earnings for those
who started as self-employed. Using tpearn this is a statistically significant difference, using tjb_msum they are indistinguishable. </p>
***/

foreach var of varlist tpearn tjb_msum {
	display _newline(2)
	display "basic table below of earnings using `var' by race"
	table initial_race unempf12_6, statistic(mean `var') 

	display _newline(2)
	display "table below comparing earnings between racial groups using `var'"
	pwmean `var', over(initial_race) mcompare(dunnett) effects 

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were unemployed"
	pwmean `var' if unempf12_6 ==1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were NOT unemployed "
	pwmean `var' if unempf12_6 ==0, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as wage and salary"
	pwmean `var' if mode_status_f12v2 == 1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as self-employed"
	pwmean `var' if mode_status_f12v2 == 2, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as unemployed"
	pwmean `var' if mode_status_f12v2 == 4, over(initial_race) mcompare(dunnett) effects
}


/***
<html>
<body>
<h4>Within race differences</h4>
<p> Here we see that unemployment is associated with lower average earnings. This relationship holds within all racial groups 
and for both measures of earnings. Using tpearn, we see that starting out unemployed is associated with lower earnings than starting 
out as wage and salary within all racial groups. For white, asian, and 'residual' group respondents, starting as self-employed is associated with 
higher earnings than starting as W&S. This does not hold for black respondents, where thsoe starting as SE earn less on average
than those starting as W&S. Using tjb_msum, those starting as W&S earn more on average than those starting as SE or unemployed within all racial groups. 
</p>
***/
foreach var of varlist tpearn tjb_msum {
	display _newline(2)
	display "`var' earnings within white subsample by unemployment"
	ttest `var' if initial_race == 1, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within black subsample by unemployment"
	ttest `var' if initial_race == 2, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within asian subsample by unemployment" 
	ttest `var' if initial_race == 3, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within 'residual' subsample by unemployment"  
	ttest `var' if initial_race == 4, by(unempf12_6)


	display _newline(2)
	display "comparing `var' within white subsample by initial employment status"
	pwmean `var' if initial_race == 1, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within black subsample by initial employment status"
	pwmean `var' if initial_race == 2, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within asian subsample by initial employment status"
	pwmean `var' if initial_race == 3, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within 'residual' subsample by initial employment status"
	pwmean `var' if initial_race == 4, over(mode_status_f12v2) mcompare(dunnett) effects
}

/***
<html>
<body>
<h3>SE Earnings</h3>
<p></p>
***/

/***
<html>
<body>
<h4>Overall SE sample</h4>
<p> Unemployment associated with lower earnings. Holds whether we measure unemployment as 6 consecutive months or as modal status in first year. 
Using tpearn we see that those starting as SE earn more than those starting as W&S. Using tjb_msum, SE and WS starting groups are indistinguisable.</p>
***/

unique ssuid_spanel_pnum_id if pct_se_after_12==1, by(mode_status_f12v2)

table initial_race unempf12_6 if pct_se_after_12 ==1, statistic(mean tpearn tjb_msum) 


ttest tpearn if pct_se_after_12 ==1, by(unempf12_6)
ttest tjb_msum if pct_se_after_12 ==1, by(unempf12_6)
pwmean tpearn if pct_se_after_12 ==1, over(mode_status_f12v2) mcompare(dunnett) effects 
pwmean tjb_msum if pct_se_after_12 ==1, over(mode_status_f12v2) mcompare(dunnett) effects



/***
<html>
<body>
<h4>Between Race differences SE </h4>
<p>Among our self-employed sample, we see that there are statistically significant differences in earnings between 
black vs white, residual vs white, but not asian vs white. This holds for both tbj_msum and tpearn as our earnings measure. 

Using tpearn: <br>
Among those who entered SE from unemployment, we see that asian respondents earned more on average
than white respondents while black and those falling in our residual racial group earned less on average than white respondents. <br>
For those who didn't enter from unemployment, the differences remain significant for black vs white and residual vs white but there is no disernible difference 
between asian and white respondents in terms of earnings.<br>
<br>
Among those who enter SE from WS, there are statistically significant differences between white and black earnings, 
and white and our residual racial category earnings, with white respondents earning more on average than 
respondents from those two groups. <br>
Among those who enter SE from SE, the differences are the same as for those who enter from WS. <br>
Among those who enter SE from unemployment, white respondents earn more on average than black and "residual" respondents.
Meanwhile, Asian respondents earn more on average than white respondents. <br>
<br>


Using tjb_msum: <br>
Looking at those unemployed in first 12 months, the only significant difference is asian respondents earning more than white white respondents. 
The differences between black and white and 'residual' and white are not significant. For those who did not experience unemployment, 
asian and white earnings are not significantly different, but black vs white and 'residual' vs white are significant with white earnings higher than either group. 
<br>
Comparing entrance conditions: <br>
- within those who enter SE from W&S, white respondents' earnings were greater than black and 'residual' respondents' earnings. 
Asian respondents' earnings are greater than white respondents' earnings at .1 level but not .05 level. <br>
- The above  relationships hold for those who enter from SE. <br>
- For those who start as unemployed as their modal status, earnings for whites are indistinguishable from those for blacks or members of our 'residual' group.
Asian respondents earn more than whites on average in this comparison. 
</p>
***/

preserve 
keep if pct_se_after_12 == 1 
foreach var of varlist tpearn tjb_msum  {
	display _newline(2)
	display "basic table below of earnings using `var' by race"
	table initial_race unempf12_6, statistic(mean `var') 

	display _newline(2)
	display "table below comparing earnings between racial groups using `var'"
	pwmean `var', over(initial_race) mcompare(dunnett) effects 

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were unemployed"
	pwmean `var' if unempf12_6 ==1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were NOT unemployed "
	pwmean `var' if unempf12_6 ==0, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as wage and salary"
	pwmean `var' if mode_status_f12v2 == 1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as self-employed"
	pwmean `var' if mode_status_f12v2 == 2, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as unemployed"
	pwmean `var' if mode_status_f12v2 == 4, over(initial_race) mcompare(dunnett) effects
}

restore 

/***
<html>
<body>
<h4>Within race differences SE </h4>
<p>Within all of our racial groups, those who were unemployed before entering SE earn less than those who did not, 
except for the asian subsample when we measure earnings with tjb_msum.  <br>

Within white subsample and using tpearn, those entering SE from unemployment had lower earnings and those entering from SE had higher earnings 
than those entering from WS. Using tjb_msum, the SE vs W&S difference is no longer significant. <br>
Within black subsample, those entering from SE or unemp earn less on avearge than those entering from W&S. This holds when using tjb_msum. <br>
Within asian submsample and using tpearn, those entering from SE earn more on average and those entering from unemp earn less on average than those 
entering from W&S.  Our "residual" subsample has the same relationships as the asian subsample. 
Using tjb_msum, in the asian subsample, earnings for those who 
enter SE from W&S are no longer statistically different than those who enter from SE. Likewise for the 'residual' group.    </p>
***/
preserve
keep if pct_se_after_12 == 1

foreach var of varlist tpearn tjb_msum  {
	display _newline(2)
	display "`var' earnings within white subsample by unemployment"
	ttest `var' if initial_race == 1, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within black subsample by unemployment"
	ttest `var' if initial_race == 2, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within asian subsample by unemployment" 
	ttest `var' if initial_race == 3, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within 'residual' subsample by unemployment"  
	ttest `var' if initial_race == 4, by(unempf12_6)	

	display _newline(2)
	display "comparing `var' within white subsample by initial employment status"
	pwmean `var' if initial_race == 1, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within black subsample by initial employment status"
	pwmean `var' if initial_race == 2, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within asian subsample by initial employment status"
	pwmean `var' if initial_race == 3, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within 'residual' subsample by initial employment status"
	pwmean `var' if initial_race == 4, over(mode_status_f12v2) mcompare(dunnett) effects
}

restore 


/***
<html>
<body>
<h3>Wage and Salary Earnings</h3>
***/

/***
<html>
<body>
<h4>Wage and Salary overall </h4>
<p>Those who experienced unemployment earn less regardless of earnings measure. Those entering W&S from SE earn more than those who
start as SE if we use tpearn but less if tjb_msum. </p>
***/
preserve
keep if pct_se_after_12 == 0 
unique ssuid_spanel_pnum_id, by(mode_status_f12v2)
ttest tpearn, by(unempf12_6)
ttest tjb_msum, by(unempf12_6)
pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) effects 
pwmean tjb_msum, over(mode_status_f12v2) mcompare(dunnett) effects

/***
<html>
<body>
<h4>Between Race differences</h4>
<p> Using tpearn or tjb_msum, for the total W&S subsample as well as within those who experienced unemployment and those who did not, 
asian respondents earned more than white respondents who in turn earned more than black or 'residual' group respondents. <br>
<br>
For those who started as wage and salary and remained wage and salary, using either earnings measure the relationships remain the same with 
asians earning more than whites who in turn earned more than black or 'residual' group respondents. <br>
<br>
For those who started as SE and entered WS using tjb_msum the difference between blacks and whites is not significant, while those in the 'residual'
category and asians earned more than whites. Using tpearn, asian and white earnings are similar. Black respondents earned less
than white respondents. <br>
<br>
For those who entered WS from unemployment, using either earnings measure, white respondents earned more than black and 
'residual' group members but less than asian respondents.
</p>
***/

foreach var of varlist tpearn tjb_msum {
	display _newline(2)
	display "basic table below of earnings using `var' by race"
	table initial_race unempf12_6, statistic(mean `var') 

	display _newline(2)
	display "table below comparing earnings between racial groups using `var'"
	pwmean `var', over(initial_race) mcompare(dunnett) effects 

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were unemployed"
	pwmean `var' if unempf12_6 ==1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were NOT unemployed "
	pwmean `var' if unempf12_6 ==0, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as wage and salary"
	pwmean `var' if mode_status_f12v2 == 1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as self-employed"
	pwmean `var' if mode_status_f12v2 == 2, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as unemployed"
	pwmean `var' if mode_status_f12v2 == 4, over(initial_race) mcompare(dunnett) effects
}


/***
<html>
<body>
<h4>Within race differences</h4>
<p> examining impact of unemployment on earnings within each racial group. Here we see that those who experienced unemployment
have on average lower earnings during our full period of observation than those who did not, regardless of racial group and using either earnings measure. <br>
<br>
Using tpearn, within black, white, and our 'residual' group, those entering W&S from SE earn more on average than those starting 
as W&S. This difference is not significant within the asian subsample. Within all groups, those who were unemployed at first earned less than those who started as W&S. <br>
<br>
Using tjb_msum, within white and asian subsamples, those entering W&S from SE or unemployment earned less than those who started as W&S.
Within the black subsample, those who entered W&S from unemployment earned less than those who started WS. Earnings for those entering WS from SE vs those who started as WS are not significantly different. 
Within the 'residual' subsample, those entering W&S from SE earn more than those who started as SE. 
 </p>
***/
foreach var of varlist tpearn tjb_msum {
	display _newline(2)
	display "`var' earnings within white subsample by unemployment"
	ttest `var' if initial_race == 1, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within black subsample by unemployment"
	ttest `var' if initial_race == 2, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within asian subsample by unemployment" 
	ttest `var' if initial_race == 3, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within 'residual' subsample by unemployment"  
	ttest `var' if initial_race == 4, by(unempf12_6)

	display _newline(2)
	display "comparing `var' within white subsample by initial employment status"
	pwmean `var' if initial_race == 1, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within black subsample by initial employment status"
	pwmean `var' if initial_race == 2, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within asian subsample by initial employment status"
	pwmean `var' if initial_race == 3, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within 'residual' subsample by initial employment status"
	pwmean `var' if initial_race == 4, over(mode_status_f12v2) mcompare(dunnett) effects
}

restore 

/***
<html>
<body>
<h2>Descriptive Comparisons using individual respondent averages </h2>
<p></p>
***/

frame copy earnings collapsed_earnings
frame change collapsed_earnings

collapse (mean) tjb_msum tpearn ln_tpearn ln_tjb_msum, by(ssuid_spanel_pnum_id pct_se_after_12 unempf12_6 mode_status_f12v2 initial_race)
list in 1/5

/***
<html>
<body>
<h3>WS/SE Earnings</h3>
***/

/***
<html>
<body>
<h4>Full Sample</h4>
<p>Interestingly, we get different results for avg earnings for
 those who start as SE vs WS depending on if we use tbj_msum or tpearn.</p>
***/
ttest tpearn, by(unempf12_6)
ttest tjb_msum, by(unempf12_6)
pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) effects 
pwmean tjb_msum, over(mode_status_f12v2) mcompare(dunnett) effects

/***
<html>
<body>
<h4>Between Race differences</h4>
<p>Here we see that earnings for whites are on average, greater than earnings for other groups except for Asians. 
These relationships hold looking at the subsample that experienced unemployment and the subsample that did 
not experience unemployment in their first 12 months. These hold using either earnings measure.
Likewise, these relationships hold within the subsamples of those who  started as wage and salary and the subsample of those who started as unemployed.

Among those who start as self-employed, using tjb_msum  or tpearn the only significant difference is white respondents earning more than black respondents.
</p>
***/

foreach var of varlist tpearn tjb_msum {
	display _newline(2)
	display "basic table below of earnings using `var' by race"
	table initial_race unempf12_6, statistic(mean `var') 

	display _newline(2)
	display "table below comparing earnings between racial groups using `var'"
	pwmean `var', over(initial_race) mcompare(dunnett) effects 

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were unemployed"
	pwmean `var' if unempf12_6 ==1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were NOT unemployed "
	pwmean `var' if unempf12_6 ==0, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as wage and salary"
	pwmean `var' if mode_status_f12v2 == 1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as self-employed"
	pwmean `var' if mode_status_f12v2 == 2, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as unemployed"
	pwmean `var' if mode_status_f12v2 == 4, over(initial_race) mcompare(dunnett) effects
}


/***
<html>
<body>
<h4>Within race differences</h4>
<p> Here we see that unemployment is associated with lower average earnings. This relationship holds within all racial groups 
and for both measures of earnings. 

Using tpearn, we see that starting out unemployed is associated with lower earnings than starting 
out as wage and salary within all racial groups. For white and 'residual' group respondents, starting as self-employed is associated with 
higher earnings than starting as W&S. This does not hold for black respondents, where thsoe starting as SE earn less on average
than those starting as W&S. Using tjb_msum, those starting as W&S earn more on average than those starting as SE or unemployed within all racial groups 
with the exception of the comparison between 'residual' SE vs 'residual' WS which is not significant.  
</p>
***/
foreach var of varlist tpearn tjb_msum {
display _newline(2)
	display "`var' earnings within white subsample by unemployment"
	ttest `var' if initial_race == 1, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within black subsample by unemployment"
	ttest `var' if initial_race == 2, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within asian subsample by unemployment" 
	ttest `var' if initial_race == 3, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within 'residual' subsample by unemployment"  
	ttest `var' if initial_race == 4, by(unempf12_6)


	display _newline(2)
	display "comparing `var' within white subsample by initial employment status"
	pwmean `var' if initial_race == 1, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within black subsample by initial employment status"
	pwmean `var' if initial_race == 2, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within asian subsample by initial employment status"
	pwmean `var' if initial_race == 3, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within 'residual' subsample by initial employment status"
	pwmean `var' if initial_race == 4, over(mode_status_f12v2) mcompare(dunnett) effects
}

/***
<html>
<body>
<h3>SE Earnings</h3>
<p></p>
***/

/***
<html>
<body>
<h4>Overall SE sample</h4>
<p> Unemployment associated with lower earnings. Holds whether we measure unemployment as 6 consecutive months or as modal status in first year. 
 Using tjb_msum or tpearn, SE and WS starting groups are indistinguisable.
</p>
***/

unique ssuid_spanel_pnum_id if pct_se_after_12 ==1, by(mode_status_f12v2)

table initial_race unempf12_6 if pct_se_after_12 ==1, statistic(mean tpearn tjb_msum) 


ttest tpearn if pct_se_after_12 ==1, by(unempf12_6)
ttest tjb_msum if pct_se_after_12 ==1, by(unempf12_6)
pwmean tpearn if pct_se_after_12 ==1, over(mode_status_f12v2) mcompare(dunnett) effects 
pwmean tjb_msum if pct_se_after_12 ==1, over(mode_status_f12v2) mcompare(dunnett) effects



/***
<html>
<body>
<h4>Between Race differences SE</h4>
<p>
Among our self-employed sample, we see that there are statistically significant differences in earnings between 
black vs white, residual vs white, but not asian vs white. This holds for both tbj_msum and tpearn as our earnings measure. 

Using tpearn: <br>
We see that black respondents earn less on average than white respondents. <br>
Among those who entered SE from unemployment, those falling in our residual racial group earned less on average than white respondents. Neither other comparison was significant. <br>
For those who didn't enter from unemployment, blacks earned less than whites, neither of the other two comparisons was significant. <br>
<br>
Among those who enter SE from WS, the earnings between groups are not statistically different. <br>
Among those who enter SE from SE, the only significant difference is white respondents earning more than black respondents on average <br>
Among those who enter SE from unemployment, white respondents earn more on average than "residual" respondents. <br>
<br>


Using tjb_msum: <br>
We see that black respondents earn less on average than white respondents. <br>
Looking at those unemployed in first 12 months, the only significant difference is asian respondents earning more than white white respondents. 
The differences between black and white and 'residual' and white are not significant. For those who did not experience unemployment, 
asian and white and 'residual' and white earnings are not significantly different, but black vs white are significant with white earnings higher than either group. 
<br>
Comparing entrance conditions: <br>
- Among those who enter SE from WS, the earnings between groups are not statistically different. <br>
- Among those who enter SE from SE, the only significant difference is white respondents earning more than black respondents on average <br>
- For those who start as unemployed as their modal status, the earnings between groups are not statistically different. 
</p>
***/

preserve 
keep if pct_se_after_12 == 1 
foreach var of varlist tpearn tjb_msum  {
	display _newline(2)
	display "basic table below of earnings using `var' by race"
	table initial_race unempf12_6, statistic(mean `var') 

	display _newline(2)
	display "table below comparing earnings between racial groups using `var'"
	pwmean `var', over(initial_race) mcompare(dunnett) effects 

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were unemployed"
	pwmean `var' if unempf12_6 ==1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were NOT unemployed "
	pwmean `var' if unempf12_6 ==0, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as wage and salary"
	pwmean `var' if mode_status_f12v2 == 1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as self-employed"
	pwmean `var' if mode_status_f12v2 == 2, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as unemployed"
	pwmean `var' if mode_status_f12v2 == 4, over(initial_race) mcompare(dunnett) effects
}

restore 

/***
<html>
<body>
<h4>Within race differences SE</h4>
<p> Using tpearn: <br> 
- Within white and 'residual' groups, those who were unemployed for 6-months had lower earnings on average than those who were not. 
The differences between unemployed vs not unemployed were not significant with black or asian subsamples. <br>
- Entering SE from W&S vs starting as SE not associated with different earnings for any groups. <br>
- Entering SE from unemployment associated with lower earnings for black and white subsamples (asian and 'residual' have small n's) 
<br>
<br>
Using tjb_msum: <br>
- Within white subsample, those unemployed for 60months has lower earnings than those who were not unemployed. Difference for other
groups is not significant (black subsample significant at .1 level). <br>
- Entering SE from W&S vs starting as SE not associated with different earnings for any groups. <br>
- Entering SE from unemployment associated with lower earnings for black and white subsamples (asian and 'residual' have small n's) 
<br>

 </p>
***/
preserve
keep if pct_se_after_12 == 1

foreach var of varlist tpearn tjb_msum  {
	display _newline(2)
	display "`var' earnings within white subsample by unemployment"
	ttest `var' if initial_race == 1, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within black subsample by unemployment"
	ttest `var' if initial_race == 2, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within asian subsample by unemployment" 
	ttest `var' if initial_race == 3, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within 'residual' subsample by unemployment"  
	ttest `var' if initial_race == 4, by(unempf12_6)	

	display _newline(2)
	display "comparing `var' within white subsample by initial employment status"
	pwmean `var' if initial_race == 1, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within black subsample by initial employment status"
	pwmean `var' if initial_race == 2, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within asian subsample by initial employment status"
	pwmean `var' if initial_race == 3, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within 'residual' subsample by initial employment status"
	pwmean `var' if initial_race == 4, over(mode_status_f12v2) mcompare(dunnett) effects
}

restore 


/***
<html>
<body>
<h3>Wage and Salary Earnings</h3>
***/

/***
<html>
<body>
<h4>Wage and Salary overall </h4>
<p>Unemployment associated with lower earnings. Holds whether we measure unemployment as 6 consecutive months or as modal status in first year. 
Using tjb_msum we see that those starting as SE earn less than those starting as W&S. Using tpearn, SE and WS starting groups are indistinguisable. </p>
***/
preserve
keep if pct_se_after_12 == 0 

ttest tpearn, by(unempf12_6)
ttest tjb_msum, by(unempf12_6)
pwmean tpearn, over(mode_status_f12v2) mcompare(dunnett) effects 
pwmean tjb_msum, over(mode_status_f12v2) mcompare(dunnett) effects

/***
<html>
<body>
<h4>Between Race differences WS </h4>
<p>Using tpearn or tjb_msum, for the total W&S subsample as well as within subsamples of those who experienced unemployment and those who did not, 
asian respondents earned more than white respondents who in turn earned more than black or 'residual' group respondents. <br>
<br>
For those who started as wage and salary and remained wage and salary, using either earnings measure the relationships remain the same with 
asians earning more than whites who in turn earned more than black or 'residual' group respondents. <br>
<br>
For those who started as SE and entered WS using tjb_msum the difference between blacks and whites as well as 'residual' and whites are
 not significant, while asians earned more than whites. Using tpearn, none of the between group differences for the SE to WS subsample are significant. <br>
<br>
For those who entered WS from unemployment, using either earnings measure, white respondents earned more than black and 
'residual' group members but less than asian respondents. </p>
***/

foreach var of varlist tpearn tjb_msum {
	display _newline(2)
	display "basic table below of earnings using `var' by race"
	table initial_race unempf12_6, statistic(mean `var') 

	display _newline(2)
	display "table below comparing earnings between racial groups using `var'"
	pwmean `var', over(initial_race) mcompare(dunnett) effects 

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were unemployed"
	pwmean `var' if unempf12_6 ==1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who were NOT unemployed "
	pwmean `var' if unempf12_6 ==0, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as wage and salary"
	pwmean `var' if mode_status_f12v2 == 1, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as self-employed"
	pwmean `var' if mode_status_f12v2 == 2, over(initial_race) mcompare(dunnett) effects

	display _newline(2)
	display "table below comparing earnings using `var' by race for those who started as unemployed"
	pwmean `var' if mode_status_f12v2 == 4, over(initial_race) mcompare(dunnett) effects
}


/***
<html>
<body>
<h4>Within race differences WS </h4>
<p> Examining impact of unemployment on earnings within each racial group. Here we see that those who experienced unemployment
have on average lower earnings during our full period of observation than those who did not, regardless of racial group and using either earnings measure. <br>
<br>
Using tpearn, those in our 'residual' group entering W&S from SE earn more on average than those starting 
as W&S. The differences between those starting in SE vs WS were not significant for other racial groups.
 Within all groups, those who were unemployed at first earned less than those who started as W&S. <br>
<br>
Using tjb_msum, Within all groups, those who were unemployed at first earned less than those who started as W&S.
Within the white subsample, those entering W&S from SE or unemployment earned less than those who started as W&S.
Within the black, asian, and 'residual' subsamples, those entering W&S from SE did not have statistically significant different earnings than their counterparts who were 
always W&S.</p>
***/
foreach var of varlist tpearn tjb_msum {
	display _newline(2)
	display "`var' earnings within white subsample by unemployment"
	ttest `var' if initial_race == 1, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within black subsample by unemployment"
	ttest `var' if initial_race == 2, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within asian subsample by unemployment" 
	ttest `var' if initial_race == 3, by(unempf12_6)

	display _newline(2)
	display "`var' earnings within 'residual' subsample by unemployment"  
	ttest `var' if initial_race == 4, by(unempf12_6)

	display _newline(2)
	display "comparing `var' within white subsample by initial employment status"
	pwmean `var' if initial_race == 1, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within black subsample by initial employment status"
	pwmean `var' if initial_race == 2, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within asian subsample by initial employment status"
	pwmean `var' if initial_race == 3, over(mode_status_f12v2) mcompare(dunnett) effects

	display _newline(2)
	display "comparing `var' within 'residual' subsample by initial employment status"
	pwmean `var' if initial_race == 4, over(mode_status_f12v2) mcompare(dunnett) effects
}


restore 


/***
<html>
<body>
<h1>Beginning of modeling</h1>
<p></p>
***/


frame change earnings
xtset ssuid_spanel_pnum_id  month_overall


 /**********************************************************************/
 /*  SECTION WS/SE Earnings			
     Notes: */
 /**********************************************************************/ 
 
foreach y of varlist  ln_tjb_msum  ln_tpearn {
	foreach x of varlist unempf12_6 mode_status_f12v2 {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust)  mle
		eststo b_`y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3 i.initial_race $controls , vce(robust) mle
		eststo b_`y'_`xname'_2re

		*quietly xtreg `y' i.se_only, fe vce(robust) 
		*eststo se_`y'1_x'_fe

		*quietly xtreg `y' i.se_only i.educ3 i.initial_race $controls, fe vce(robust)
		*eststo se_`y'2_x'_fe
}
}

/***
<html>
<body>
<h4>Table1: DV: WS/SE earnings. IV: 6 months unemployment</h4>
<p> The dependent variable is monthly earnings (from any employment type) during any time we observe them. Put another way, 
these models include earnings within the first 12 months.
Independent variable is our indicator for 6 consecutive months of unemployment during the first 12 months in our data.  </p>
***/


esttab b_ln_*unemp*re, legend label varlabels(_cons Constant) title(6 month unemployed) aic bic 
*esttab b_tpearn_unemp*re b_tjb_msum_unemp*, legend label varlabels(_cons Constant) title(6 month unemployed All models) aic bic 


/***
<html>
<body>
<h4>Table2: DV WS/SE earnings. IV: modal status </h4>
<p>The dependent variable is monthly earnings (from any employment type) during any time we observe them. 
Put another way, these models include earnings within the first 12 months.
Independent variable is our indicator for their modal employment status during the first 12 months in our data. </p>
***/
esttab b_ln_*mode*re, legend label varlabels(_cons Constant) title(Modal status ) aic bic 
*esttab b_tpearn_mode*re b_tjb_msum_mode*, legend label varlabels(_cons Constant) title(Modal status All models) aic bic 

 /*------------------------------------ End of SECTION WS/SE Earnings ------------------------------------*/




/**********************************************************************/
/*  SECTION: SE Models  			
    Notes: */
/**********************************************************************/
preserve
keep if pct_se_after_12 == 1 

foreach y of varlist  ln_tjb_msum  ln_tpearn {
	foreach x of varlist unempf12_6 mode_status_f12v2 {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust)  mle
		eststo se`y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3 i.initial_race $controls , vce(robust) mle
		eststo se`y'_`xname'_2re
	}
}

restore

/***
<html>
<body>
<h4>Table3: DV: SE earnings. IV: 6 months unemployment</h4>
<p>The dependent variable is monthly earnings from self-employment during any time we observe them. Put another way, these models include earnings within the first 12 months.
Independent variable is our indicator for 6 consecutive months of unemployment during the first 12 months in our data.  </p>
***/


esttab seln_*unemp*re, legend label varlabels(_cons Constant) title(6 month unemployed SE earnings ) aic bic 
*esttab setpearn_unemp*re setjb_msum_unemp*, legend label varlabels(_cons Constant) title(6 month unemployed All models SE Earnings) aic bic 


/***
<html>
<body>
<h4>Table4: DV SE earnings. IV: modal status </h4>
<p>The dependent variable is monthly earnings from self-employment during any time we observe them. Put another way, these models include earnings within the first 12 months.
Independent variable is our indicator for modal employment type during the first 12 months in our data. </p>
***/
esttab seln_*mode*re, legend label varlabels(_cons Constant) title(Modal Status SE earnings) aic bic 
*esttab setpearn_mode*re setjb_msum_mode*, legend label varlabels(_cons Constant) title(Modal status All models SE earnings ) aic bic 

/*------------------------------------ End of SECTION  ------------------------------------*/

/**********************************************************************/
/*  SECTION: WS Models  			
    Notes: */
/**********************************************************************/
preserve
keep if pct_se_after_12 == 0

foreach y of varlist  ln_tjb_msum  ln_tpearn {
	foreach x of varlist unempf12_6 mode_status_f12v2 {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust)  mle
		eststo ws_`y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3 i.initial_race $controls , vce(robust) mle
		eststo ws_`y'_`xname'_2re

}
}

restore



/***
<html>
<body>
<h4>Table 5: DV: WS earnings. IV: 6 months unemployment</h4>
<p> The dependent variable is monthly earnings from wage/salary during any time we observe them. Put another way, these models include earnings within the first 12 months.
Independent variable is our indicator for 6 consecutive months of unemployment during the first 12 months in our data. </p>
***/

esttab ws_ln_*unemp*re, legend label varlabels(_cons Constant) title(6 month unemployed WS earnings ) aic bic 
*esttab ws_tpearn_unemp*re ws_tjb_msum_unemp*, legend label varlabels(_cons Constant) title(6 month unemployed All models WS Earnings) aic bic 


/***
<html>
<body>
<h4>Table6 : DV WS earnings. IV: modal status </h4>
<p>The dependent variable is monthly earnings from wage/salary during any time we observe them. Put another way, these models include earnings within the first 12 months.
Independent variable is our indicator for modal employment status during the first 12 months in our data. </p>
***/
esttab ws_ln_*mode*re, legend label varlabels(_cons Constant) title(Modal Status WS earnings) aic bic 
*esttab ws_tpearn_mode*re ws_tjb_msum_mode*, legend label varlabels(_cons Constant) title(Modal status All models WS earnings ) aic bic 


/*------------------------------------ End of SECTION WS Models  ------------------------------------*/


/***
<html>
<body>
<h2>Abbreviated Summaries of Earnings models</h2>
<p></p>
***/

/***
<html>
<body>
<h3>ln_tjb_msum as DV</h3>
<p></p>
***/
esttab  b_ln_tjb_msum_*unemp*2* b_ln_tjb_msum*mode*2* seln_tjb_msum*unemp*2* seln_tjb_msum*mode*2* ws_ln_tjb_msum*unemp*2* ws_ln_tjb_msum*mode*2*, legend label aic bic drop(*.educ3 age* immigrant parent industry2 calyear _cons) ///
mtitles("Any earnings" "Any earnings" "SE earnings" "SE earnings" "WS earnings" "WS earnings") 

/***
<html>
<body>
<h3>ln_tpearn as DV</h3>
<p></p>
***/
esttab  b_ln_tpearn_*unemp*2* b_ln_tpearn*mode*2* seln_tpearn*unemp*2* seln_tpearn*mode*2* ws_ln_tpearn*unemp*2* ws_ln_tpearn*mode*2*, legend label aic bic drop(*.educ3 age* immigrant parent industry2 calyear _cons) ///
mtitles("Any earnings" "Any earnings" "SE earnings" "SE earnings" "WS earnings" "WS earnings") 

/***
<html>
<body>
<h3> Using first year earnings as a predictor  	</h3>
<p></p>
***/

/**********************************************************************/
/*  SECTION f12 predictor: Using first year earnings as a predictor  			
    Notes: */
/**********************************************************************/

preserve
keep if month_individ <=12
collapse (mean) tjb_msum_f12 = tjb_msum tpearn_f12 = tpearn tjb_prftb_f12 = tjb_prftb tbsjval_f12 = tbsjval, by(ssuid_spanel_pnum_id spanel)
save f12_data.dta, replace 
restore 

drop _merge 
merge m:1 ssuid_spanel_pnum_id using f12_data
// instance of someone not re-merging here is 199880. They were SE for fewer than 15 hours in first 12 months 
// so those records get dropped before this preserve which means they have only rows >= 13 in our working dataset for models
// above. So, in our preserve collapse restore, there are no rows for months 1-12 in to calculate based on.

frame copy earnings earningsf12
frame change earningsf12
drop if month_individ <= 12 

xtset ssuid_spanel_pnum_id month_overall

foreach y of varlist  ln_tjb_msum  {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x' tjb_msum_f12 , vce(robust)  mle
		eststo b12_`y'_`xname'_1re

		quietly xtreg `y' i.`x' tjb_msum_f12 i.educ3 i.initial_race $controls , vce(robust) mle
		eststo b12_`y'_`xname'_2re

}
}


foreach y of varlist ln_tpearn  {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x' tpearn_f12 , vce(robust)  mle
		eststo b12_`y'_`xname'_1re

		quietly xtreg `y' i.`x' tpearn_f12 i.educ3 i.initial_race $controls , vce(robust) mle
		eststo b12_`y'_`xname'_2re

}
}

/***
<html>
<body>
<h4>Table 7: DV: WS/SE earnings. IV: 6 months unemployment</h4>
<p>The dependent variable is monthly earnings from any employment. We've excluded the first 12 months as they're now used as a predictor.  
Independent variable is our indicator for 6 consecutive months of unemployment during the first 12 months in our data. 
These now include the average earnings during first 12 months as a predictor. </p>
***/
esttab b12_*unemp* , legend label varlabels(_cons Constant) title(6 month unemployed All models) aic bic 


/***
<html>
<body>
<h4>Table 8: DV WS/SE earnings. IV: modal status f12</h4>
<p>The dependent variable is monthly earnings from any employment. 
Independent variable is our modal employment status during the first 12 months in our data. 
These now include the average earnings during first 12 months as a predictor.</p>
***/
esttab b12_*mode*, legend label varlabels(_cons Constant) title(Modal status All models) aic bic 


/*------------------------------------ End of SECTION f12 as predictor ------------------------------------*/

preserve
keep if pct_se_after_12 == 1
foreach y of varlist  ln_tjb_msum  {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x' tjb_msum_f12 , vce(robust)  mle
		eststo se12_`y'_`xname'_1re

		quietly xtreg `y' i.`x' tjb_msum_f12 i.educ3 i.initial_race $controls , vce(robust) mle
		eststo se12_`y'_`xname'_2re

}
}


foreach y of varlist ln_tpearn  {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x' tpearn_f12 , vce(robust)  mle
		eststo se12_`y'_`xname'_1re

		quietly xtreg `y' i.`x' tpearn_f12 i.educ3 i.initial_race $controls , vce(robust) mle
		eststo se12_`y'_`xname'_2re

}
}

restore 

/***
<html>
<body>
<h4>Table 9: DV: SE earnings. IV: 6 months unemployment</h4>
<p>The dependent variable is monthly earnings from self-employment. 
Independent variable is our indicator for 6 consecutive months of unemployment during the first 12 months in our data. 
These now include the average earnings during first 12 months as a predictor.</p>
***/


esttab se12_*unemp*, legend label varlabels(_cons Constant) title(6 month unemployed) aic bic 

/***
<html>
<body>
<h4>Table 10: DV SE earnings. IV: Modal status f12</h4>
<p>The dependent variable is monthly earnings from self-employment. 
Independent variable is our modal employment status during the first 12 months in our data. 
These now include the average earnings during first 12 months as a predictor.</p>
***/
esttab se12_*mode*, legend label varlabels(_cons Constant) title(Modal status All models) aic bic 


/*------------------------------------ End of Earnings Models  ------------------------------------*/

/***
<html>
<body>
<h2>Abbreviated comparisons for models using f12 earnings as predictors</h2>
<p></p>
***/

/***
<html>
<body>
<h3>ln_tjb_msum as DV</h3>
<p></p>
***/
esttab  b12_ln_tjb_msum_*unemp*2* b12_ln_tjb_msum*mode*2* se12_ln_tjb_msum*unemp*2* se12_ln_tjb_msum*mode*2*, legend label aic bic drop(*.educ3 age* immigrant parent industry2 calyear _cons) ///
mtitles("Any earnings" "Any earnings" "SE earnings" "SE earnings") 

/***
<html>
<body>
<h3>ln_tpearn as DV</h3>
<p></p>
***/
esttab  b12_ln_tpearn_*unemp*2* b12_ln_tpearn*mode*2* se12_ln_tpearn*unemp*2* se12_ln_tpearn*mode*2*, legend label aic bic drop(*.educ3 age* immigrant parent industry2 calyear _cons) ///
mtitles("Any earnings" "Any earnings" "SE earnings" "SE earnings") 



/***
<html>
<body>
<h1>Profit models</h1>
<p></p>
***/
/**********************************************************************/
/*  SECTION Profit models 		
    Notes: */
/**********************************************************************/
frame copy earnings profits, replace
frame change profits


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

/***
<html>
<body>
<h3>Profit: SE vs unemp to SE</h3>
***/
list ssuid_spanel_pnum_id calyear profpos prof10k ln_tjb_prftb tjb_prftb tbsjval ln_tbsjval ///
unempf12_6 mode_status_f12v2 in 1/500 if pct_se_after_12 ==1, sepby(ssuid_spanel_pnum_id) abbrev(10)



// getting to sample of interest

keep if pct_se_after_12 == 1 

sum tjb_prftb profpos prof10k ln_tjb_prftb

bysort ssuid_spanel_pnum_id: egen mean_tjb_prftb = mean(tjb_prftb) 
bysort ssuid_spanel_pnum_id: egen mean_ln_tjb_prftb = mean(ln_tjb_prftb)


unique ssuid_spanel_pnum_id, by(mode_status_f12v2 initial_race)

/***
<html>
<body>
<h4>Descriptive Stats: Profit</h4>
<p>Using our 6-month unemployment measure, those who were unemployed have less profitable business on average than those 
who were not. No difference in entering SE from unemp vs W&S. </p>
***/

ttest tjb_prftb, by(unempf12_6)
pwmean tjb_prftb, over(mode_status_f12v2) mcompare(tukey) effects 


/***
<html>
<body>
<h5>Between group differences: profit</h5>
<p>Overall, black respondents reported lower profits than white and asian respondents. Among those who were unemployed, no significant difference in avg profit. 
Among thos who were NOT unemployed, black respondents reported lower profits than white and asian respondents. </p>
***/

foreach var of varlist tjb_prftb {
	display _newline(2)
	display "basic table below of profit using `var' by race"
	table initial_race unempf12_6, statistic(mean `var') 

	display _newline(2)
	display "table below comparing profit between racial groups using `var'"
	pwmean `var', over(initial_race) mcompare(tukey) groups 

	display _newline(2)
	display "table below comparing profit using `var' by race for those who were unemployed"
	pwmean `var' if unempf12_6 ==1, over(initial_race) mcompare(tukey) groups

	display _newline(2)
	display "table below comparing profit using `var' by race for those who were NOT unemployed "
	pwmean `var' if unempf12_6 ==0, over(initial_race) mcompare(tukey) groups

	display _newline(2)
	display "table below comparing profit using `var' by race for those who started as wage and salary"
	pwmean `var' if mode_status_f12v2 == 1, over(initial_race) mcompare(tukey) groups

	display _newline(2)
	display "table below comparing profit using `var' by race for those who started as self-employed"
	pwmean `var' if mode_status_f12v2 == 2, over(initial_race) mcompare(tukey) groups

	display _newline(2)
	display "table below comparing profit using `var' by race for those who started as unemployed"
	pwmean `var' if mode_status_f12v2 == 4, over(initial_race) mcompare(tukey) groups
}


/***
<html>
<body>
<h5>Within group differences: profit</h5>
<p>Only within the white subsample do those who were unemployed have statistically significantly lower earnings. 
Within the white subsample   </p>
***/


foreach var of varlist tjb_prftb {
	display _newline(2)
	display "`var' profit within white subsample by unemployment"
	ttest `var' if initial_race == 1, by(unempf12_6)

	display _newline(2)
	display "`var' profit within black subsample by unemployment"
	ttest `var' if initial_race == 2, by(unempf12_6)

	display _newline(2)
	display "`var' profit within asian subsample by unemployment" 
	ttest `var' if initial_race == 3, by(unempf12_6)

	display _newline(2)
	display "`var' profit within 'residual' subsample by unemployment"  
	ttest `var' if initial_race == 4, by(unempf12_6)

	display _newline(2)
	display "comparing `var' within white subsample by initial employment status"
	pwmean `var' if initial_race == 1, over(mode_status_f12v2) mcompare(tukey) effects

	display _newline(2)
	display "comparing `var' within black subsample by initial employment status"
	pwmean `var' if initial_race == 2, over(mode_status_f12v2) mcompare(tukey) effects

	display _newline(2)
	display "comparing `var' within asian subsample by initial employment status"
	pwmean `var' if initial_race == 3, over(mode_status_f12v2) mcompare(tukey) effects

	display _newline(2)
	display "comparing `var' within 'residual' subsample by initial employment status"
	pwmean `var' if initial_race == 4, over(mode_status_f12v2) mcompare(tukey) effects
}



/***
<html>
<body>
<h3>Beginning profit models</h3>
<p></p>
***/
xtset ssuid_spanel_pnum_id calyear 

eststo clear 

foreach y of varlist profpos prof10k   {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtlogit `y' i.`x', vce(robust)  
		eststo `y'_`xname'_1re

		quietly xtlogit `y' i.`x' i.educ3 i.initial_race $controls , vce(robust) 
		eststo `y'_`xname'_2re



}
}

foreach y of varlist ln_tjb_prftb ln_tbsjval   {
	foreach x of varlist unempf12_6 mode_status_f12v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust)  mle
		eststo `y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3 i.initial_race $controls , vce(robust) mle
		eststo `y'_`xname'_2re



}
}



/***
<html>
<body>
<h4>Table 11: DV: profit binaries. IV: unemp and modal status</h4>
<p></p>
***/


esttab prof*unemp* , legend label varlabels(_cons Constant) title(Profit Models: IV Unemp) aic bic 
esttab prof*mode*, legend label varlabels(_cons Constant) title(Profit Models: IV Modal status) aic bic
/***
<html>
<body>
<h4>Table 12: DV tbsjval . IV: unemp and modal status</h4>
<p></p>
***/
esttab *jval*, legend label varlabels(_cons Constant) title(Business Value  Models) aic bic 


/*------------------------------------ End of SECTION number ------------------------------------*/

rm f12_data.dta 


/*------------------------- 
	To Do:
		 1. run profit/value models using first year as predictor
		 2. test out interactions of status/first year earnings and race 

-------------------------*/ 
