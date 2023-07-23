webdoc init modeling_earnings_profit_2023_07_19, replace logall
webdoc toc 5

/***
<html>
<title>Preliminary models of earnings, profit and business value </title>

<p> Goals of analysis: <br>
Models (Earnings): Run models 1 and 2 for each comparison groups: <br>
(1) those who started as wage and salary versus those who entered wage and salary from unemployment, <br>
(2) those who started as self employed versus those who entered self employment from unemployed, <br>
(3) those who entered self employment from being unemployed versus those who entered self employment from a wage and salary job<br>
 <br>
M1:<br>
Earnings = those who started as wage and salary versus those who entered wage and salary from unemployment (base model)<br>
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
use earnings_by_status, clear  
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


list ssuid_spanel_pnum_id swave monthcode month_over employment_type1 change  if ssuid_spanel_pnum_id == 204

bysort ssuid_spanel_pnum_id (month_over) : gen temp = 1 if month_over[1] > 12 
unique ssuid_spanel_pnum_id if temp == 1 
// here we have people who weren't in wave 1 so don't have month_over values less than 12 so the original version of the below codes wouldn't work for capturing their first month. Switching to using month_individ to start counting a 12 month window from the first observation we have for someone in our data 
bysort ssuid_spanel_pnum_id (swave monthcode): gen month_individ = _n 




frame copy default profits, replace
frame copy default earnings, replace
frame copy default bizvalue, replace 


global controls= "i.sex i.initial_hisp age age2 immigrant parent industry2"


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

preserve
keep if unique_tag
count if max_consec_unempf12 >=1
count if max_consec_unempf12 >=3 
count if max_consec_unempf12 >=6
tab max_consec_unempf12 months_unempf12
restore  

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
// do we want only employed records after 12 months or do we want total number of records after 12 months that 

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
drop first_status second_status-status_12 status_1_lim-unemp_6 change
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
	- Sample restricted to those who were of working age and their monthly job level records when they were employed at least 15 hours 		when they were unemployed (we may want to drop these at this point for analyses) <br> 
	- Monthly level earnings from all sources in tpearn and and from their main job in tjb_msum
	- "*_status_f12" vars capture the *nth status held within the first 12 months (only non-missing for one observation) <br>
	- "status_*" vars capture the same information as the above vars but carryforward the value to be present for all observations <br> 
	- "months_s*" vars capture the number of consecutive months that a specific status was held during the first 12 months. For instance months_s1 = 6 and status_1 == 2 means the first 6 months we observed that individual they were self-employed. <br>
	- "last_status" is the last status held during the first 12 months we observe someone <br>
	- "mode_status_f12v1" is the most common that person held during the first 12 months and breaks ties by taking the min value (prioritizes employment)
	- "mode_status_f12v2" is the same as above, but takes the max mode so prioritizes unemployment in tie breaking <br>
	- pct_se_after_12 captures the share of months after the 12 month entry window that someone was self-employed. So if someone is in our data for 36 months, we ignore the first 12 months, then count the number of months their main job that they worked more than 15 hours was self-employment. That value is our numerator. Then we count the total number of months they were present in the data post-12 month window (excluding the months they worked for fewer than 15 hours but including the months they were unemployed) <br>
<br>
We also have flags for unemployment during the first 12 months: <br>
	- months_unempf12 gives us the total number of months unemployed during first 12 months <br>
	- max_consec_unempf12 gives us the maximum consecutive spell of unemployment a person experienced <br>
	- unempf12_1, unempf12_3, unempf12_6 are flags indicating whether that person experienced at least 1, 3, or 6 months of consecutive unemployment in the first 12 month window we observe them. 
</p>
***/
label define employment_types 1 "W&S" 2 "SE" 3 "Other" 4 "Unemp", replace 
foreach var of varlist first_status_f12-status_7_lim last_status_f12 status_* mode* {
	label values `var' employment_types
}
list month_individ	employment_type1 tjb_mwkhrs tpearn months_s1-months_s2 status_1_lim-status_2_lim status_1 status_2 last_status pct_se_after_12 mode_status_f12v1 unempf12_6 if ssuid_spanel_pnum_id == 200324 


drop ejb_clwrk ejb_endwk ejb_jborse ejb_startwk ejb_incpb ejb_bslryb ejb_typpay1 ejb_jobid tjb_occ tjb_ind tjb_empb tjb_gamt1 tbsjdebtval tdebt_cc tdebt_ed tdebt_bus teq_bus tval_home tdebt_home teq_home tval_ast tdebt_ast tnetworth thdebt_cc thdebt_ed thval_home thdebt_home theq_home thval_ast thdebt_ast thnetworth

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
	
// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=. 

xtset ssuid_spanel_pnum_id  month_overall
/* Notes: 
	1. Leaving in first 12 months of earnings for this first set of models. We test them as a predictor later. 
*/
 
foreach y of varlist tjb_msum ln_tjb_msum tpearn ln_tpearn {
	foreach x of varlist unempf12_6 mode_status_f12v2 {
		
		di "`y'_`x'"
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust)  mle
		eststo b_`y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3 i.initial_race $controls, vce(robust) mle
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
<h4>Table1: DV: WS/SE earnings. EV: 6 months unemployment</h4>
<p>These models include earnings within the first 12 months.  </p>
***/


esttab b_ln_*unemp*re, legend label varlabels(_cons Constant) title(6 month unemployed) aic bic 
esttab b_tpearn_unemp*re b_tjb_msum_unemp*, legend label varlabels(_cons Constant) title(6 month unemployed All models) aic bic 


/***
<html>
<body>
<h4>Table2: DV WS/SE earnings. EV: modal status </h4>
<p>/p>
***/
esttab b_ln_*mode*re, legend label varlabels(_cons Constant) title(Modal status ) aic bic 
esttab b_tpearn_mode*re b_tjb_msum_mode*, legend label varlabels(_cons Constant) title(Modal status All models) aic bic 





/**********************************************************************/
/*  SECTION: SE Models  			
    Notes: */
/**********************************************************************/
preserve
keep if pct_se_after_12 == 1 

foreach y of varlist tjb_msum ln_tjb_msum tpearn ln_tpearn {
	foreach x of varlist unempf12_6 mode_status_f12v2 {
		
		di "`y'_`x'"
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust)  mle
		eststo se`y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3 i.initial_race $controls , vce(robust) mle
		eststo se`y'_`xname'_2re

}
}

restore
/*------------------------------------ End of SECTION  ------------------------------------*/




/***
<html>
<body>
<h4>Table3: DV: SE earnings. EV: 6 months unemployment</h4>
<p>These models include earnings within the first 12 months.  </p>
***/


esttab seln_*unemp*re, legend label varlabels(_cons Constant) title(6 month unemployed SE earnings ) aic bic 
esttab setpearn_unemp*re setjb_msum_unemp*, legend label varlabels(_cons Constant) title(6 month unemployed All models SE Earnings) aic bic 


/***
<html>
<body>
<h4>Table4: DV SE earnings. EV: modal status </h4>
<p>/p>
***/
esttab seln_*mode*re, legend label varlabels(_cons Constant) title(Modal Status SE earnings) aic bic 
esttab setpearn_mode*re setjb_msum_mode*, legend label varlabels(_cons Constant) title(Modal status All models SE earnings ) aic bic 


/**********************************************************************/
/*  SECTION: WS Models  			
    Notes: */
/**********************************************************************/
preserve
keep if pct_se_after_12 == 0

foreach y of varlist tjb_msum ln_tjb_msum tpearn ln_tpearn {
	foreach x of varlist unempf12_6 mode_status_f12v2 {
		
		di "`y'_`x'"
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		quietly xtreg `y' i.`x', vce(robust)  mle
		eststo ws_`y'_`xname'_1re

		quietly xtreg `y' i.`x' i.educ3 i.initial_race $controls , vce(robust) mle
		eststo ws_`y'_`xname'_2re

}
}

restore
/*------------------------------------ End of SECTION WS Models  ------------------------------------*/


/***
<html>
<body>
<h4>Table 5: DV: WS earnings. EV: 6 months unemployment</h4>
***/


esttab ws_ln_*unemp*re, legend label varlabels(_cons Constant) title(6 month unemployed WS earnings ) aic bic 
esttab ws_tpearn_unemp*re ws_tjb_msum_unemp*, legend label varlabels(_cons Constant) title(6 month unemployed All models WS Earnings) aic bic 


/***
<html>
<body>
<h4>Table6 : DV WS earnings. EV: modal status </h4>
<p>/p>
***/
esttab ws_ln_*mode*re, legend label varlabels(_cons Constant) title(Modal Status WS earnings) aic bic 
esttab ws_tpearn_mode*re ws_tjb_msum_mode*, legend label varlabels(_cons Constant) title(Modal status All models WS earnings ) aic bic 


/*------------------------------------ End of Earnings Models  ------------------------------------*/





