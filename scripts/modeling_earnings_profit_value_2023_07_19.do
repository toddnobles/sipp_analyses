webdoc init modeling_earnings_profit_2023_07_19, replace logall
webdoc toc 5

/***
<html>
<title>Preliminary models of earnings, profit and business value </title>

<p> Goals of analysis: 
Models (Earnings): Run models 1 and 2 for each comparison groups: 
(1) those who started as wage and salary versus those who entered wage and salary from unemployment, 
(2) those who started as self employed versus those who entered self employment from unemployed, 
(3) those who entered self employment from being unemployed versus those who entered self employment from a wage and salary job

M1:
Earnings = those who started as wage and salary versus those who entered wage and salary from unemployment (base model)

M2:
M1+ controls (demographic characteristics + industry + year)

Models (Profit and business value)
M1: 
profit/business value  (base model)

M2:
M1+ controls (demographic characteristics + industry + year </p>
***/
clear all 
local homepath "/Volumes/Extreme SSD/SIPP Data Files/"

local datapath "`homepath'/dtas"

cd "`datapath'"
set linesize 255


/***
<html>
<body>
<h2>Data Prep</h2>
<p> Note: These analyses are only considering the first three statuses. These capture the vast majority of respondents, but flagging here that we are not capturing more complex instances. For example, if we're intersted in the those who enter self-employment from unemployment, we are only capture those whose statuses in our data go from Unemployed to SE. We are currently not capturing the more complex case where someone went from WS to Unemp to SE. For context that particular status trajectory captures 202 people. 

Note: This dataset being read in is created in the middle of the employment_pathway_earnings.do script. For profitability we can operate at yearly level as this value is reported at yearly level. 
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


gen month_over = monthcode if swave == 1
replace month_over = monthcode + 12 if swave == 2
replace month_over = monthcode + 24 if swave ==3 
replace month_over = monthcode + 36 if swave == 4 



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
<p>max_consec_unemp_f12 gives us the length of longest unemployment spell during the first 12 months. months_unemp_f12 gives us the total number of months unemployed during first 12 months</p>
***/

frame change earnings 
bysort ssuid_spanel_pnum_id: gen months_in_data = _N
drop if months_in_data < 12 // do we actually want this? 
bysort ssuid_spanel_pnum_id: egen months_unemp_f12=  count(month_over) if (employment_type1 == 4 & month_over <=12) // doesn't account for non-consecutive issues 

gen unemp_month = 1 if employment_type1 == 4  
replace unemp_month = . if month_over >12

tsset ssuid_spanel_pnum_id month_over
tsspell unemp_month 
replace _seq = . if month_over > 12 
replace _seq = . if employment_type != 4
by ssuid_spanel_pnum_id: egen max_consec_unemp_f12= max(_seq)
replace max_consec_unemp_f12 = 0 if max_consec_unemp_f12 == . 
list month_over employment_type months_unemp_f12 unemp_month _s* _end max_*  if ssuid_spanel_pnum_id  ==   199821 
tsset, clear 

preserve
keep if unique_tag
count if max_consec_unemp_f12 >=1
count if max_consec_unemp_f12 >=3 
count if max_consec_unemp_f12 >=6
tab max_consec_unemp_f12 months_unemp_f12
restore  

gen unemp_f12_1 = 1 if max_consec_unemp_f12 >=1
gen unemp_f12_3 = 1 if max_consec_unemp_f12 >=3
gen unemp_f12_6 = 1 if max_consec_unemp_f12 >=6 

foreach var of varlist unemp_f12_1 unemp_f12_3 unemp_f12_6{
	replace `var' = 0 if `var' == . 
}

/***
<html>
<body>
<h3>Quantifying self-employment after the first 12 months </h3>
<p></p>
***/

drop if tjb_mwkhrs < 15
drop months_in_data 
bysort ssuid_spanel_pnum_id: gen months_in_data = _N
bysort ssuid_spanel_pnum_id (month_over): egen months_after_12 = count(month_over) if month_over>12
gsort ssuid_spanel_pnum_id -month_over 
by ssuid_spanel_pnum_id: carryforward months_after_12, replace 
replace months_after_12 = 0 if months_after_12 == .
 
gen self_emp = 1 if month_over >12 & employment_type1 == 2
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
bysort ssuid_spanel_pnum_id (month_over): gen change = employment_type1 != employment_type1[_n-1] & _n >1 & month_over<=12
bysort ssuid_spanel_pnum_id (month_over): gen first_status_f12 = employment_type1 if _n==1 

gsort ssuid_spanel_pnum_id -change spanel swave monthcode

by ssuid_spanel_pnum_id: gen second_status_f12 = employment_type1 if change ==1 & _n ==1
by ssuid_spanel_pnum_id: gen third_status_f12 = employment_type1 if change ==1 & _n ==2
by ssuid_spanel_pnum_id: gen fourth_status_f12 = employment_type1 if change ==1 & _n ==3
by ssuid_spanel_pnum_id: gen fifth_status_f12 = employment_type1 if change ==1 & _n ==4
by ssuid_spanel_pnum_id: gen sixth_status_f12 = employment_type1 if change ==1 & _n ==5
by ssuid_spanel_pnum_id: gen seventh_status_f12 = employment_type1 if change ==1 & _n ==6 

// no one has more than 7 statuses in first 12 months 
// let's see what their last status is in month 12
bysort ssuid_spanel_pnum_id (month_over): gen first_status_f12 = employment_type1 if _n==1 



list ssuid_spanel_pnum_id spanel swave monthcode employment_type1 change *status if ssuid_spanel_pnum_id == 199771

/***
<html>
<body>
<h3>Comparing Self-employed who experienced unemployment versus those who did not</h3>
<p></p>
***/

// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=. 

xtset ssuid_spanel_pnum_id  month_over

 
foreach y of varlist tjb_msum tpearn ln_tpearn {
	foreach x of varlist i.unemp_f12_1 i.unemp_f12_3 i.unemp_f12_6
    
quietly xtreg `y' i.unemp_f12_1, vce(robust)  mle
eststo se_`y'1_`x'_re

quietly xtreg `y' i.se_only i.educ3 i.initial_race $controls, vce(robust) mle
eststo se_`y'2_x'_re

*quietly xtreg `y' i.se_only, fe vce(robust) 
*eststo se_`y'1_x'_fe

*quietly xtreg `y' i.se_only i.educ3 i.initial_race $controls, fe vce(robust)
*eststo se_`y'2_x'_fe
}



