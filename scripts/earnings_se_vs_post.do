webdoc init earnings_pre_post_se, replace logall
webdoc toc 5

/***
<html>
<title>Post-Self Employment Wage Premium Analyses </title>

<p> Overview of this script: <br>
<br>
	- This script begins from the initial compiled files we create from the raw SIPP data. We then perform some formatting and 
tidying to get the data cleaned for analyses. Then, we run descriptive analyses to examine the earnings of those who exit SE. 
The goal is to investigate if there is a wage premium that the formerly self-employed receive. <br>

 1. Within individuals, how do earnings during SE compare with W&S employment earnings after exiting SE.  <br>
	1a. A sub question of this is: for those who start as W&S, then enter SE, then return to W&S, do we observe an earnings change? 
 2. Comparing the earnings of individuals who were SE and left with those who've never entered SE.<br>
 3. 




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



gen combine_race_eth = 1  if initial_race == 1 // white
replace combine_race_eth = 2 if initial_race == 2 // black
replace combine_race_eth = 3 if initial_race == 3 // asian
replace combine_race_eth = 4 if initial_hisp == 1 & combine_race_eth == .  // hispanic
replace combine_race_eth = 5 if initial_race == 4 & initial_hisp == 0 & combine_race_eth == . // other (non-hispanic residual)
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


egen unique_tag = tag(ssuid_spanel_pnum_id) // unique id


// To be reworked using TSSPELL command for clarity ---------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------





/***
<html>
<body>
<h3>at this point we have a person-month level file with an employment status for them for each period captured in employment_type </h3>
***/

drop if tjb_mwkhrs < 15
**# marking when their job status changes
bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen change = employment_type1 != employment_type1[_n-1] & _n >1 
list ssuid_spanel_pnum_id spanel swave monthcode employment_type1  change if ssuid_spanel_pnum_id == 28558, sepby(swave) 

bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen first_status = employment_type1 if _n==1

by ssuid_spanel_pnum_id: egen ever_changed = total(change)
table ever_changed
unique ssuid_spanel_pnum_id, by(ever_changed)  // counts of people falling into each job change category. 

gsort ssuid_spanel_pnum_id -change spanel swave monthcode

list ssuid_spanel_pnum_id spanel swave monthcode employment_type1 change *status if ssuid_spanel_pnum_id == 199771
by ssuid_spanel_pnum_id: gen second_status = employment_type1 if change ==1 & _n ==1
by ssuid_spanel_pnum_id: gen third_status = employment_type1 if change ==1 & _n ==2
by ssuid_spanel_pnum_id: gen fourth_status = employment_type1 if change ==1 & _n ==3
by ssuid_spanel_pnum_id: gen fifth_status = employment_type1 if change ==1 & _n ==4
by ssuid_spanel_pnum_id: gen sixth_status = employment_type1 if change ==1 & _n ==5
by ssuid_spanel_pnum_id: gen seventh_status = employment_type1 if change ==1 & _n ==6
by ssuid_spanel_pnum_id: gen eighth_status = employment_type1 if change ==1 & _n ==7
by ssuid_spanel_pnum_id: gen ninth_status = employment_type1 if change ==1 & _n ==8
by ssuid_spanel_pnum_id: gen tenth_status = employment_type1 if change ==1 & _n ==9
by ssuid_spanel_pnum_id: gen eleventh_status = employment_type1 if change ==1 & _n ==10
by ssuid_spanel_pnum_id: gen twelfth_status = employment_type1 if change ==1 & _n ==11


foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status {
	label values `x' employment_types
	//bysort ssuid_spanel_pnum_id (`x'): carryforward `x', replace 

}

sort ssuid_spanel_pnum_id spanel swave monthcode 
list ssuid_spanel_pnum_id spanel swave monthcode employment_type1  change *status if ssuid_spanel_pnum_id == 199771

list ssuid_spanel_pnum_id spanel swave monthcode employment_type1  change *status if ssuid_spanel_pnum_id == 28558	


local i = 0
foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status  {
	gsort ssuid_spanel_pnum_id -`x' 
	local i = `i' + 1
	by ssuid_spanel_pnum_id: carryforward `x', gen(status_`i') 
	
}


preserve
keep if unique_tag
contract status_1 status_2 status_3 
gsort -_freq
list
restore 



sort ssuid_spanel_pnum_id swave monthcode employment_type1

local i = 0

foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status {
	local i = `i' + 1
	bysort ssuid_spanel_pnum_id (swave monthcode) employment_type1: carryforward `x', gen(status_`i'_lim)  dynamic_condition(employment_type1[_n-1]==employment_type1[_n])

}

list ssuid_spanel_pnum_id swave monthcode employment_type1 status_*_lim if ssuid_spanel_pnum_id ==  178409 
list ssuid_spanel_pnum_id swave monthcode employment_type1 status_*_lim if ssuid_spanel_pnum_id ==  199771 
list ssuid_spanel_pnum_id swave monthcode employment_type1 status_*_lim if ssuid_spanel_pnum_id ==  28558 

// calculating average tpearns for each employment status by person 
bysort ssuid_spanel_pnum_id status_1_lim: egen tpearn_s1 = mean(tpearn) if status_1_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tpearn_s1, replace 
bysort ssuid_spanel_pnum_id status_2_lim: egen tpearn_s2 = mean(tpearn) if status_2_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tpearn_s2, replace 
bysort ssuid_spanel_pnum_id status_3_lim: egen tpearn_s3 = mean(tpearn) if status_3_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tpearn_s3, replace 


// calculating average tjb_msums for each employment status by person 
bysort ssuid_spanel_pnum_id status_1_lim: egen tjb_msum_s1 = mean(tjb_msum) if status_1_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tjb_msum_s1, replace 
bysort ssuid_spanel_pnum_id status_2_lim: egen tjb_msum_s2 = mean(tjb_msum) if status_2_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tjb_msum_s2, replace 
bysort ssuid_spanel_pnum_id status_3_lim: egen tjb_msum_s3 = mean(tjb_msum) if status_3_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tjb_msum_s3, replace 





// use this method and a reshape if we decide to track more statuses 
// collapse (mean) tpearn, by(ssuid_spanel_pnum_id status_1 status_2 status_3 status_1_lim status_2_lim status_3_lim erace) cw


/***
<html>
<body>
<h3> Multi-month unemployment flag</h3>
<p> Here we create a measure of how long people held each employment status. So we can now create a person-level flag for if someone experienced unemployment for 3 months or 6 months. </p>
***/
sort ssuid_spanel_pnum_id swave monthcode 
list ssuid_spanel_pnum_id swave monthcode status_1 status_2 status_3 status_4 status_5  status_1_lim status_2_lim status_3_lim status_4_lim status_5_lim if ssuid_spanel_pnum_id== 704 

forval x = 1/12 {
	by ssuid_spanel_pnum_id: egen months_s`x' = count(status_`x'_lim)
	
}
/*
by ssuid_spanel_pnum_id: egen months_s1 = count(status_1_lim)
by ssuid_spanel_pnum_id: egen months_s2 = count(status_2_lim)
by ssuid_spanel_pnum_id: egen months_s3 = count(status_3_lim)
*/

list ssuid_spanel_pnum_id swave monthcode status_1 status_2 status_3 status_1_lim status_2_lim status_3_lim months_* if ssuid_spanel_pnum_id== 704 

/*
bysort ssuid_spanel_pnum_id: gen unemp_3 = 1 if (status_1 == 4 & months_s1 >=3) | (status_2 == 4 & months_s2 >=3) | (status_3 ==4 & months_s3 >=3)
replace unemp_3 = 0 if unemp_3 == . 

bysort ssuid_spanel_pnum_id: gen unemp_6 = 1 if (status_1 == 4 & months_s1 >=6) | (status_2 == 4 & months_s2 >=6) | (status_3 ==4 & months_s3 >=6)
replace unemp_6 = 0 if unemp_6 == . 

list ssuid_spanel_pnum_id swave monthcode status_1 status_2 status_3 status_1_lim status_2_lim status_3_lim months_*  unemp_* in 1/200, sepby(ssuid_spanel_pnum_id)
*/



/***
<html>
<body>
<h1> Assessing what we have</h1>
<p> At this point, we've created status_* variables that capture each unique employment status and the order someone experiences them. For those variables, unemployed is simply that we had no ejb data for that month and the enjflag signalled unemployed. We also have the month_* vars that tell us how long people held each status. Next we have the tpearn_* vars that capture the average monthly earnings for each status. Finally, we have the two unemployment flags signalling if someone was unemployed for 3 or more months or 6 or more months.</p>
***/

list ssuid_spanel_pnum_id status_1 status_2 status_3 months_s1-months_s3 tpearn tpearn_* tjb_msum*   in 1/100, sepby(ssuid_spanel_pnum_id)



/***
<html>
<body>
<h1>Earnings Comparisons for those who move from SE to W&S</h1>
***/
table status_1 status_2 if unique_tag ==1 

mean tpearn_s1  if unique_tag ==1 & status_1 == 2 & status_2 == 1
mean tpearn_s2  if unique_tag ==1 & status_1 ==2 & status_2 ==1 


mean tjb_msum_s1  if unique_tag ==1 & status_1 == 2 & status_2 == 1
mean tjb_msum_s2  if unique_tag ==1 & status_1 ==2 & status_2 ==1 



// what if we broaden to other transitions from SE to W&SE
table combine_race_eth if unique_tag ==1 & ((status_1 == 2 & status_2 ==1) | (status_2 == 2 & status_3 == 1))

table combine_race_eth if unique_tag ==1 & status_1 == 2 & status_2 == 1
table combine_race_eth if unique_tag ==1 & status_1 == 2 & status_2 == 1, statistic( mean tpearn_s1 tpearn_s2)
table combine_race_eth if unique_tag ==1 & status_1 == 2 & status_2 == 1, statistic( sd tpearn_s1 tpearn_s2)









/***
<html>
<body>
<h3>Effect of unemployment on subsequent earnings</h3>
<p> Here we see that those entering SE from unemployment earn more on average than those entering W&S from unemployment. However, this difference only holds for white respondents, not black respondents. </p>
***/

table erace if unique_tag ==1 
table erace status_2 if unique_tag ==1 & status_1 == 4 
table erace status_2 if unique_tag ==1 & status_1 == 4, statistic(mean tpearn_s2)
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2), by(status_2) // those who start as unemployed and enter W&S or SE
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2) & erace ==1 , by(status_2) // white, start as unemp and enter W&S or SE
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2) & erace ==2 , by(status_2) // black, start as unemp and enter W&S and SE


/***
<html>
<body>
<h4>Those who started as W&S versus those who entered from unemployment</h4>
<p> As expected, those who enter W&S from unemployment earn less during their employed period than those who never experienced unemployment. Holds for both white and black respondents  </p>
***/
tabstat tpearn_s1 if unique_tag ==1 & status_1 == 1 & status_2 == ., statistic(n mean sd) 
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 1 , statistic(n mean sd)
ttesti 58372 4810 4772 13168 2246 3143

tabstat tpearn_s1 if unique_tag ==1 & status_1 == 1 & status_2 == ., statistic(n mean sd) by(erace) 
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 1 , statistic(n mean sd) by(erace)
ttesti 46226 4898 4826 9678 2269 3305 // white respondents
ttesti 6034 3800 3538 20178 2000 2264 // black respondents 





