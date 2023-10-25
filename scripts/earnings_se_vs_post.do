webdoc init earnings_pre_post_se, replace logall
webdoc toc 5

/***
<html>
<title>Post-Self Employment Wage Premium Analyses </title>

<p> Overview of this script: <br>
<br>
	- This script begins from the initial compiled files we create from the raw SIPP data. We then perform some formatting and 
tidying to get the data cleaned for analyses. Then, we run descriptive analyses to examine the earnings of those who exit SE. 
The goal is to investigate if the formerly self-employed receive a wage premium in the wage and salary labor market. <br>

 1. Within individuals, how do earnings during SE compare with W&S employment earnings after exiting SE?  <br>
	1a. A sub question of this is: for those who start as W&S, then enter SE, then return to W&S, do we observe an earnings change? 
 2. Comparing the earnings of individuals who were SE and left with those who've never entered SE.<br>
 3. Comparing the earnings of individuals who were SE and left for WS with those who've only ever been WS. 
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
// here we have people who weren't in wave 1 so don't have month_over values less than 12, 
// so the original version of the below codes wouldn't work for capturing their first month. 
// Switching to using month_individ to start counting a 12 month window from the first observation we have for someone in our data 
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


/***
<html>
<body>
<h3>at this point we have a person-month level file with an employment status for them for each period captured in employment_type </h3>
***/

list ssuid_spanel_pnum_id month_individ employment_type1 tjb_msum tpearn tjb_prftb in 1/50

/***
<html>
<body>
<h2>Quick investigation of some data oddities</h2>
<p> //??.. How do we want to handle these?  </p> 
***/

// How many people do we have who report working but no income in any of our variables
count if tjb_mwkhrs >0 & tjb_mwkhrs != . & tjb_msum <=0 & tpearn <= 0 & tjb_prftb <=0 & tptotinc <=0 // number of records 
distinct ssuid_spanel_pnum_id if tjb_mwkhrs >0 & tjb_mwkhrs != . & tjb_msum <=0 & tpearn <= 0 & tjb_prftb <=0 & tptotinc <=0 // 2200 or so people 

list ssuid_spanel_pnum_id month_individ employment_type tjb_mwkhrs  tjb_msum tpearn tjb_prftb tptotinc teq_bus if tjb_mwkhrs >0 & tjb_mwkhrs != . & tjb_msum == 0 & tpearn == 0 in 1/10000, sepby(ssuid_spanel_pnum_id)

// some records here just loook like data entry issues (see person 15 who has one hour worked for each month of their third wave of data and no income)
//  we have people who don't get filtered in our working 15 hours or more such as 
// id = 123 who report no incomes for multiple waves) Looks like they have a small business that maybe truly didn't earn anything. 
// more concerningly, we have peopple like id 340 who have large total personal incomes but this income isn't captured in any of our income variables 
// how many records follow the pattern of id 340? 
distinct ssuid_spanel_pnum_id if tjb_mwkhrs >0 & tjb_mwkhrs !=. & tjb_msum <= 0 & tpearn <= 0 & tptotinc >0 & tptotinc != . & tjb_prftb == 0 

list ssuid_spanel_pnum_id month_individ employment_type tjb_mwkhrs  tjb_msum tpearn tjb_prftb tptotinc teq_bus if tjb_mwkhrs >0 & tjb_mwkhrs !=. & tjb_msum <= 0 & tpearn <= 0 & tptotinc >0 & tptotinc != . & tjb_prftb == 0 in 1/100000, sepby(ssuid_spanel_pnum_id) 


// how many that have notable incomes and are reportedly working but we don't capture incomes in their earnings variables? 
distinct ssuid_spanel_pnum_id if tjb_mwkhrs >0 & tjb_mwkhrs !=. & tjb_msum <= 0 & tpearn <= 0 & tptotinc >1000 & tptotinc != . & tjb_prftb == 0 

// will decide how to address these folks later

/***
<html>
<body>
<h2>Marking spells of different employment statuses</h2>
***/

// marking spells of employment/unemployment 
tsset ssuid_spanel_pnum_id month_individ
tsspell employment_type1

// this gives us indicator for when an employment status changes, how long that spell of a status was and when it ended. 
list ssuid_spanel_pnum_id month_individ employment_type tjb_mwkhrs  _s* _end in 1/50, sepby(ssuid_spanel_pnum_id)

drop if tjb_mwkhrs < 15 // drop employment records that we aren't interested in counting 


// this creates a flag to capture a w&S period immediately after an SE period 
bysort ssuid_spanel_pnum_id (month_individ): gen ws_after_se_immed = 1 if employment_type1[_n] == 1 & employment_type1[_n-1] == 2
bysort ssuid_spanel_pnum_id _spell (ws_after_se_immed): carryforward ws_after_se_immed, replace 

// this creates a flag for a W&S period that falls after an SE period. 
//So we look at each row, see if it is for a W&S period then we look to all previous spells for that person and see if they had any SE spells. 
bysort ssuid_spanel_pnum_id (month_individ): gen ws_after_se_ever =1 if employment_type1[_n] == 1 & employment_type[_n-1] ==2 
forval x = 2/47 {
	bysort ssuid_spanel_pnum_id (month_individ): replace ws_after_se_ever = 1 if employment_type1[_n] ==1 & employment_type[_n-`x'] == 2
}



// creating flag for a SE period right before a W&S period 
bysort ssuid_spanel_pnum_id (month_individ): gen se_before_ws_immed = 1 if employment_type1[_n] == 2 & employment_type1[_n+1] == 1
bysort ssuid_spanel_pnum_id _spell (se_before_ws_immed): carryforward se_before_ws_immed, replace 


// creating flag for a SE period that falls before any WS period. 
// This won't capture the final period for someone who goes (SE to UNEMP to WS to SE ). In that instance it will capture the first SE spell.  
bysort ssuid_spanel_pnum_id (month_individ): gen se_before_ws_ever =1 if employment_type1[_n] == 2 & employment_type[_n+1] ==1 
forval x = 2/47 {
	bysort ssuid_spanel_pnum_id (month_individ): replace se_before_ws_ever = 1 if employment_type1[_n] ==2 & employment_type[_n+`x'] == 1
}



list ssuid_spanel_pnum_id month_individ employment_type  _s* _end ws_after*  se_before* if ssuid_spanel_pnum_id  == 169475
list ssuid_spanel_pnum_id month_individ employment_type  _s* _end ws_after* se_before*  if ssuid_spanel_pnum_id  == 170435


/***
<html>
<body>
<h2>Comparing earnings within individual for SE premium in WS earnings </h2>
<p> Do we see a SE premium in W&S salaries of those who were previously self employed? Here for N-size considerations we take the broadest possible slice of folks. If we observe someone being self employed at any point in our data and they have a subsequent WS employed period then they get captured here. The periods do not need to be consecutive. For instance someone who went SE to Unemp to SE to WS. We would take the average earnings during any month they were SE and then compare those with the average during the WS months.  </p>
***/

// collapse down to get average earnings for each individual during the SE before WS period and the WS after SE period.
//  This leaves us with two rows per person. 
preserve

collapse (mean) tpearn (mean) tjb_msum (max) _seq, by(ssuid_spanel_pnum_id combine_race_eth se_before_ws_ever ws_after_se_ever)

list in 1/10

drop if ws_after_se_ever == . & se_before_ws_ever ==. 
gen period = "WS" if ws_after_se_ever == 1
replace period = "SE" if se_before_ws_ever == 1 


/***
<html>
<body>
<h3> Overall comparison  </h3>

***/
// The following two tables only includes those who went from SE to WS. 
// We have two observations in the dataset for them at this point, 
// one for their SE period and one for their WS period so we run a t-test comparing 
// the average earnings during SE for this group and the average earnings during WS for the same group of people. 
ttest tpearn, by(period) // no significant difference using tpearn 
ttest tjb_msum, by(period) 
// higher earnings during WS period using tjb_msum, however I think this is due to how people report self-employment income in the tjb_msum variable 





/***
<html>
<body>
<h3> Comparison within race/ethnicity </h3>
***/
egen unique_tag = tag(ssuid_spanel_pnum_id)
table combine_race_eth if unique_tag ==1 
table  period combine_race_eth, statistic(mean tpearn) // counts of each race/ethnicity in this group of people who switched 

// None of the following produce any statistically significant results. 
// Although the lack of decrease for white respondents versus a big decrease for black and asian respondents is notable. 
ttest tpearn if combine_race_eth ==1 , by(period) // white
ttest tpearn if combine_race_eth ==2 , by(period) // black
ttest tpearn if combine_race_eth ==3, by(period) // asian 


// Again, I think these differences are primarily due to issues with reporting 
// for self-employed income in the tjb_msum variable. 
table  period combine_race_eth, statistic(mean tjb_msum)

ttest tjb_msum if combine_race_eth ==1 , by(period) // white.  significant increase. 
ttest tjb_msum if combine_race_eth ==2 , by(period) // black. significant increase
ttest tjb_msum if combine_race_eth ==3, by(period) // asian. significant increase 

restore 


/***
<html>
<body>
<h2> Restrictive comparisons of those who transition from SE to WS.   </h2>
<p> What  if we take only those WS periods that fall right after an SE period?
 While the previous analyses allowed for a variety of paths from SE to WS, the 
 below analyses only examine direct transitions from SE to WS. 
 This captures the majority of people in the previous analysis.   </p>
***/

preserve
collapse (mean) tpearn (mean) tjb_msum (max) _seq, by(ssuid_spanel_pnum_id combine_race_eth se_before_ws_immed ws_after_se_immed)

keep if se_before_ws_immed ==1 | ws_after_se_immed == 1
gen period = "WS" if ws_after_se_immed == 1
replace period = "SE" if se_before_ws_immed == 1 

list in 1/10


/***
<html>
<body>
<h3> Restrictive: Overall comparison </h3>
***/
ttest tpearn, by(period) // no significant difference. sligtly larger difference than the less restrictive version above though by about $100
ttest tjb_msum, by(period) // significant, but again likely due to reporting 




/***
<html>
<body>
<h4> Restrictive: Comparison within race/ethnicity </h4>
***/

egen unique_tag = tag(ssuid_spanel_pnum_id)

// haven't excluded many people (~200) with this more restrictive definition of transition
table combine_race_eth if unique_tag ==1 

table  period combine_race_eth, statistic(mean tpearn)

// all decrease from SE to WS but not statistically significant
ttest tpearn if combine_race_eth ==1 , by(period) // white
ttest tpearn if combine_race_eth ==2 , by(period) // black
ttest tpearn if combine_race_eth ==3, by(period) // asian 


table  period combine_race_eth, statistic(mean tjb_msum)

ttest tjb_msum if combine_race_eth ==1 , by(period) // white. significant increase
ttest tjb_msum if combine_race_eth ==2 , by(period) // black. significant increase
ttest tjb_msum if combine_race_eth ==3, by(period) // asian. not significant increase

restore




/***
<html>
<body>
<h2>Comparing those who switched to those who remained </h2>
<p> How do earnings for those who switched from SE to W&S compare to those who never left SE and those who never entered WS? </p> 
***/

bysort ssuid_spanel_pnum_id: egen max_spell = max(_spell)

keep if (max_spell == 1 & employment_type1 == 1) | (max_spell == 1 & employment_type1 == 2) | (se_before_ws_ever == 1) | (ws_after_se_ever == 1 )

gen period = "WS Only" if employment_type1 == 1 & max_spell ==1 
replace period = "SE only" if employment_type1 == 2 & max_spell ==1 
replace period = "WS_post_se" if ws_after_se_ever == 1 
replace period = "SE_pre_WS" if se_before_ws_ever == 1

list ssuid_spanel_pnum_id month_individ employment_type  _s* _end ws_after* se_before* max_spell period in 1/100, compress

collapse (mean) tpearn (mean) tjb_msum (max) _seq, by(ssuid_spanel_pnum_id combine_race_eth period)

list in 1/50 // now have one row for everyone who was WS only or SE only and two rows for people who had both se then WS


/***
<html>
<body>
<h3>SE vs SE_pre_WS</h3>
***/

// do they earn more during SE period than their counterparts who never switch? 
// for both measures we see lower earnings during these SE periods. Only statistically 
// significant for tbj_msum measure 
ttest tpearn if (period == "SE only" | period == "SE_pre_WS"), by(period)
ttest tjb_msum if (period == "SE only" | period == "SE_pre_WS"), by(period)

/***
<html>
<body>
<h4>SE vs SE_pre_WS within race/ethnicity</h4>
***/
// what about within race for SE vs SE comparisons
// for white respondents we see lower earnings during SE for those who switched to WS vs those who did not
ttest tpearn if (period == "SE only" | period == "SE_pre_WS") & combine_race_eth ==1 , by(period) 

// for black respondents we see higher earnings for those who switched vs those who did not (not statistically significant though) 
ttest tpearn if (period == "SE only" | period == "SE_pre_WS") & combine_race_eth ==2 , by(period)

// for asian respondents we see higher earnings for those who switched vs those who did not (not statistically significant though) 
ttest tpearn if (period == "SE only" | period == "SE_pre_WS") & combine_race_eth ==3 , by(period)


// for white respondents we see lower earnings during SE for those who switched to WS vs those who did not
ttest tjb_msum if (period == "SE only" | period == "SE_pre_WS") & combine_race_eth ==1 , by(period)

// slightly lower  earnings using tjb_msum for black respondent sample but not significant
ttest tjb_msum if (period == "SE only" | period == "SE_pre_WS") & combine_race_eth ==2 , by(period)

// roughly the same earnings for asian sample 
ttest tjb_msum if (period == "SE only" | period == "SE_pre_WS") & combine_race_eth ==3 , by(period)



/***
<html>
<body>
<h3>WS vs WS_post_se</h3>
<p> How do the WS earnings for those who switch from SE to WS compare to their WS counterparts who we only observe as WS? </p> 
***/
// do they earn more after switching than those who were always WS_post_se

// using tpearn their are  signs of a premium 
ttest tpearn if (period == "WS Only" | period == "WS_post_se"), by(period)

// roughly equal earnings using tjb_msum 
ttest tjb_msum if (period == "WS Only" | period == "WS_post_se"), by(period)


/***
<html>
<body>
<h4>WS vs WS_post_se: within race</h4>
<p>  what about within race for WS vs WS post SE  </p>
***/

// higher earnings for switchers in white subsample 
ttest tpearn if (period == "WS Only" | period == "WS_post_se") & combine_race_eth ==1 , by(period)

// higher earnings for switchers in black subsample 
ttest tpearn if (period == "WS Only" | period == "WS_post_se") & combine_race_eth ==2 , by(period)

// rouhgly equal earnings for asian subsample 
ttest tpearn if (period == "WS Only" | period == "WS_post_se") & combine_race_eth ==3 , by(period)


// roughly equal using tjb_msum for white subsample 
ttest tjb_msum if (period == "WS Only" | period == "WS_post_se") & combine_race_eth ==1 , by(period)

// roughly equal using tjb_msum for black subsample
ttest tjb_msum if (period == "WS Only" | period == "WS_post_se") & combine_race_eth ==2 , by(period)

// decrease for asian subsample, but not significant
ttest tjb_msum if (period == "WS Only" | period == "WS_post_se") & combine_race_eth ==3 , by(period)






