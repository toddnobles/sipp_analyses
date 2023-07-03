webdoc init modeling_earnings_profit, replace logall
webdoc toc 5

/***
<html>
<head><title>Preliminary models of earnings, profit and business value </title></head>
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

label variable erace "Race"
label define race_label	 1 "White" 2 "Black" 3 "Asian" 4 "Residual"
label values erace race_label 

frame copy default profits, replace
frame copy default earnings, replace
frame copy default bizvalue, replace 

/***
<html>
<body>
<h2>Earnings Models</h2>
***/

**# WS vs Unemp to WS
/***
<html>
<body>
<h3>WS vs Unemp to WS</h3>
***/

**# SE vs Unemp to SE 
/***
<html>
<body>
<h3>SE vs Unemp to SE</h3>
***/

**# WS to SE vs Unemp to SE 
/***
<html>
<body>
<h3>WS to SE vs Unemp to SE</h3>
***/


/***
<html>
<body>
<h2>Profit Models</h2>
<p> 
(2) those who started as self employed versus those who entered 
	self employment from unemployed, 
(3) those who entered self employment from being unemployed versus 
	those who entered self employment from a wage and salary job
</p>
***/

frame change profits
egen unique_yr_tag= tag(ssuid_spanel_pnum_id swave) // creating person-year flag 
keep if unique_yr_tag // now we're down to one row per person per year an
list ssuid_spanel_pnum_id status_1 status_2 status_3 months_* tjb_prft tbsjval in 1/50, sepby(ssuid_spanel_pnum_id)

// flags for our samples of interest 
gen se_only =1 if status_1 == 2 & status_2 == . 
replace se_only = 0 if se_only == .
gen ws_se =1 if status_1 == 1 & status_2 == 2
replace ws_se = 0 if ws_se == .
gen unemp_se=1 if status_1 == 4 & status_2 ==2 
replace unemp_se = 0 if unemp_se == . 


// recoding profits 
gen profposi=tjb_prftb>0 if tjb_prftb<. // 
tab profpos, missing
gen prof10k=tjb_prftb>=10000 if tjb_prftb<.
tab prof10k, missing

**# Profit: SE vs unemp to SE 
/***
<html>
<body>
<h3>Profit: SE vs unemp to SE</h3>
***/

preserve
// getting to sample of interest
keep if se_only ==1 | unemp_se ==1

sum tjb_prftb profpos prof10k

foreach x in  tjb_prftb  {
	egen min_`x' = min(`x')
	replace min_`x' = min_`x' *-1
	gen ln_`x' = ln(`x' + min_`x'+1)
} 

sum tjb_prftb profpos prof10k ln_tjb_prftb


global controls= "sex age age2 immigrant parent industry2"

xtset ssuid_spanel_pnum_id swave 

// comparison group here is se_only 
eststo, title("M1"): quietly xtlogit profpos i.unemp_se
eststo, title("M2"): quietly xtlogit profpos i.unemp_se i.educ3 i.erace $controls

eststo, title("M1"): quietly xtlogit prof10k i.unemp_se
eststo, title("M2"): quietly xtlogit prof10k i.unemp_se i.educ3 i.erace $controls

eststo, title("M1"): quietly xtreg ln_tjb_prftb i.unemp_se
eststo, title("M2"): quietly xtreg ln_tjb_prftb i.unemp_se i.educ3 i.erace $controls

esttab, legend label collabels(none) varlabels(_cons Constant) title(Profit SE vs Unemp to SE)
eststo clear
restore 

**# Profit: WS to SE vs unemp to SE  
/***
<html>
<body>
<h3>Profit: WS to SE vs unemp to SE </h3>  
***/
preserve

// getting to sample of interest
keep if ws_se ==1 | unemp_se ==1

sum tjb_prftb profpos prof10k

foreach x in  tjb_prftb  {
	egen min_`x' = min(`x')
	replace min_`x' = min_`x' *-1
	gen ln_`x' = ln(`x' + min_`x'+1)
} 

sum tjb_prftb profpos prof10k ln_tjb_prftb


xtset ssuid_spanel_pnum_id swave 

// comparison group here is ws_se 
eststo, title("M1"): quietly xtlogit profpos i.unemp_se 
eststo, title("M2"): quietly xtlogit profpos i.unemp_se i.educ3 i.erace $controls

eststo, title("M1"): quietly xtlogit prof10k i.unemp_se
eststo, title("M2"): quietly xtlogit prof10k i.unemp_se i.educ3 i.erace $controls

eststo, title("M1"): quietly xtreg ln_tjb_prftb i.unemp_se
eststo, title("M2"): quietly xtreg ln_tjb_prftb i.unemp_se i.educ3 i.erace $controls 

esttab, stats(N) legend label collabels(none) varlabels(_cons Constant) title(Profit: WS to SE vs Unemp to SE)
eststo clear

restore

**# Business Value
/***
<html>
<body>
<h2>Business Value Models</h2>
***/
frame change bizvalue

egen unique_yr_tag= tag(ssuid_spanel_pnum_id swave) // creating person-year flag 
keep if unique_yr_tag // now we're down to one row per person per year an

// flags for our samples of interest 
gen se_only =1 if status_1 == 2 & status_2 == . 
replace se_only = 0 if se_only == .
gen ws_se =1 if status_1 == 1 & status_2 == 2
replace ws_se = 0 if ws_se == .
gen unemp_se=1 if status_1 == 4 & status_2 ==2 
replace unemp_se = 0 if unemp_se == . 


**# Business Value: SE vs unemp to SE
/***
<html>
<body>
<h3>Business Value: SE vs unemp to SE</h3>
***/
preserve
keep if se_only ==1 | unemp_se ==1
keep if tbsjval != . 

gen ln_tbsjval = ln(tbsjval)
hist tbsjval 
hist ln_tbsjval
xtset ssuid_spanel_pnum_id swave
eststo, title("M1"): quietly xtreg tbsjval i.unemp_se
eststo, title("M2"): quietly xtreg tbsjval i.unemp_se i.educ3 i.erace  $controls
eststo, title("M1"): quietly xtreg ln_tbsjval i.unemp_se
eststo, title("M2"): quietly xtreg ln_tbsjval i.unemp_se i.educ3 i.erace  $controls


esttab, legend label collabels(none) varlabels(_cons Constant) title(Business Value SE vs Unemp to SE)

eststo clear
restore


**# Business Value: WS to SE vs Unemp to SE
/***
<html>
<body>
<h3>Business Value: WS to SE vs Unemp to SE </h3>
***/
preserve
keep if unemp_se ==1 | ws_se == 1
keep if tbsjval != . 

gen ln_tbsjval = ln(tbsjval)
xtset ssuid_spanel_pnum_id swave
eststo, title("M1"): quietly xtreg tbsjval i.unemp_se 
eststo, title("M2"): quietly xtreg tbsjval i.unemp_se i.educ3 i.erace $controls 

eststo, title("M1"): quietly xtreg ln_tbsjval i.unemp_se 
eststo, title("M2"): quietly xtreg ln_tbsjval i.unemp_se i.educ3 i.erace $controls 
esttab, legend label collabels(none) varlabels(_cons Constant) title(Business Value WS to SE vs Unemp to SE)

eststo clear 
restore




