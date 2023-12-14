webdoc init modeling_earnings_profit, replace logall
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


frame copy default profits, replace
frame copy default earnings, replace
frame copy default bizvalue, replace 


global controls= "i.sex i.initial_hisp age age2 immigrant parent industry2"


/***
<html>
<body>
<h2>Earnings Models</h2>
***/
frame change earnings 

gen month_over = monthcode if swave == 1
replace month_over = monthcode + 12 if swave == 2
replace month_over = monthcode + 24 if swave ==3 
replace month_over = monthcode + 36 if swave == 4 

/***
<html>
<body>
<h3> creating flags that signal which type of employment change occurred </h4>
***/

bysort ssuid_spanel_pnum_id (month_over): gen unemp_se = 1 if employment_type1[_n] ==2 & employment_type1[_n-1] == 4 // unemp_se 
bysort ssuid_spanel_pnum_id (month_over): gen unemp_ws = 1 if employment_type1[_n] ==1 & employment_type1[_n-1] == 4 // unemp_ws
bysort ssuid_spanel_pnum_id (month_over): gen ws_se = 1 if employment_type1[_n] == 2 & employment_type1[_n-1] == 1 // ws_se 
bysort ssuid_spanel_pnum_id (month_over): gen se_ws = 1 if employment_type1[_n] == 1 & employment_type1[_n-1] == 2 // se_ws 

list employment_type status_1_lim-status_10_lim tpearn tjb_msum unemp_ws unemp_se ws_se se_ws change if ssuid_spanel_pnum_id== 199553 

// ws_se period 
bysort ssuid_spanel_pnum_id (month_over): carryforward ws_se, gen(ws_se_period) dynamic_condition(employment_type1[_n] == employment_type1[_n-1])
// unemp_se period 
bysort ssuid_spanel_pnum_id (month_over): carryforward unemp_se, gen(unemp_se_period) dynamic_condition(employment_type1[_n] == employment_type1[_n-1])
// unemp_ws period 
bysort ssuid_spanel_pnum_id (month_over): carryforward unemp_ws, gen(unemp_ws_period) dynamic_condition(employment_type1[_n] == employment_type1[_n-1])


gen se_only =1 if status_1 == 2 & status_2 == . 
replace se_only = 0 if se_only == .
gen ws_only = 1 if status_1 ==1 & status_2 == . 
replace ws_only = 0 if ws_only == . 

bysort ssuid_spanel_pnum_id: egen ever_unemp_ws = sum(unemp_ws) // flag for ever transitioning from unemp to ws 
bysort ssuid_spanel_pnum_id: egen ever_unemp_se = sum(unemp_se) // flag for ever transitioning from unemp to se 

/***
<html>
<body>
<h4>Snapshot of working dataset thus far</h4>
***/

list employment_type unemp_se_period ws_se_period unemp_ws_period  se_only ws_only tpearn tjb_msum if ssuid_spanel_pnum_id== 199553 


/***
<html>
<body>
<h5>Question: At this point, do we want to drop those months where someone is working less than 15 hours?  </h5>
***/


**# WS vs Unemp to WS
/***
<html>
<body>
<h3>WS vs Unemp to WS</h3>
***/
preserve
keep if ws_only == 1 | ever_unemp_ws >0 // keeping  those who were always w&S or those who at some point went from unemployed to w&s

// now need to limit this second group to only the appropriate months they meet these status qualifications
keep if ws_only ==1 | unemp_ws_period == 1 
tab ws_only unemp_ws_period, missing

* list ssuid_spanel_pnum_id month_over employment_type  tpearn tjb_msum  in 50/500, sepby(ssuid_spanel_pnum_id)

// modifying tpearn for these folks 
su tpearn tjb_msum, detail

gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=. 

xtset ssuid_spanel_pnum_id  month_over

// comparison group here is ws_only  
 
foreach x of varlist tjb_msum tpearn ln_tpearn {
    
quietly xtreg `x' i.ws_only, vce(robust)  mle
eststo ws_`x'1_re

quietly xtreg `x' i.ws_only i.educ3 i.initial_race $controls, vce(robust) mle
eststo ws_`x'2_re
 /*
quietly xtreg `x' i.ws_only, fe vce(robust) 
eststo ws_`x'1_fe

quietly xtreg `x' i.ws_only i.educ3 i.initial_race $controls, fe vce(robust)
eststo ws_`x'2_fe
*/
}

restore

**# SE vs Unemp to SE 
/***
<html>
<body>
<h3>SE vs Unemp to SE</h3>
***/
preserve

keep if se_only == 1 | ever_unemp_se >0 // keeping those who were always se or those who at some point went from unemployed to se 

// now limiting the unemp_se group to only the appropriate monts they were self-employed 
keep if se_only ==1 | unemp_se_period == 1 

tab se_only unemp_se_period, missing

// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=. 

xtset ssuid_spanel_pnum_id  month_over

// comparison group here is those who went from unemp to se 
 
foreach x of varlist tjb_msum tpearn ln_tpearn {
    
quietly xtreg `x' i.se_only, vce(robust)  mle
eststo se_`x'1_re

quietly xtreg `x' i.se_only i.educ3 i.initial_race $controls, vce(robust) mle
eststo se_`x'2_re

*quietly xtreg `x' i.se_only, fe vce(robust) 
*eststo se_`x'1_fe

*quietly xtreg `x' i.se_only i.educ3 i.initial_race $controls, fe vce(robust)
*eststo se_`x'2_fe
}

restore 
**# WS to SE vs Unemp to SE 
/***
<html>
<body>
<h3>WS to SE vs Unemp to SE</h3>
***/
preserve

keep if ws_se_period == 1 | unemp_se_period == 1
tab ws_se_period unemp_se_period, missing
replace ws_se_period = 0 if ws_se_period == . 

list employment_type unemp_se_period ws_se_period unemp_ws_period  se_only ws_only tpearn tjb_msum if ssuid_spanel_pnum_id== 199553 

// modifying tpearn for these folks 
gen ln_tjb_msum = ln(tjb_msum+1) if tjb_msum != . 
egen min_tpearn = min(tpearn)
replace min_tpearn = min_tpearn *-1
gen ln_tpearn = ln(tpearn + min_tpearn+1) if tpearn !=. 

xtset ssuid_spanel_pnum_id  month_over

// comparison group here is unemp_se   
 
foreach x of varlist tjb_msum tpearn ln_tpearn {
    
quietly xtreg `x' i.ws_se_period, vce(robust)  mle
eststo wsse_`x'1_re

quietly xtreg `x' i.ws_se_period i.educ3 i.initial_race $controls, vce(robust) mle
eststo wsse_`x'2_re

quietly xtreg `x' i.ws_se_period, fe vce(robust) 
eststo wsse_`x'1_fe

quietly xtreg `x' i.ws_se_period i.educ3 i.initial_race $controls, fe vce(robust)
eststo wsse_`x'2_fe

}

restore 

**# Earnings Tables
/***
<html>
<body>
<h2>Earnings Tables</h2>
***/

/***
<html>
<body>
<h3>Earnings: WS vs Unemp to WS: FE </h3>
***/
* esttab ws_*_fe, legend label collabels(none) varlabels(_cons Constant) title(Earnings WS vs Unemp to WS: FE) aic bic 

/***
<html>
<body>
<h3>Earnings: WS vs Unemp to WS: RE </h3>
***/
esttab ws_tjb_msum*_re ws_tpearn*_re ws_ln_tpearn*_re , legend label varlabels(_cons Constant) title(Earnings WS vs Unemp to WS: RE) aic bic 

/***
<html>
<body>
<h3>Earnings: se vs Unemp to se Fixed Effects </h3>
***/
*esttab se_*_fe, legend label collabels(none) varlabels(_cons Constant) title(Earnings se vs Unemp to se Fixed Effects) aic bic 

/***
<html>
<body>
<h3>Earnings: se vs Unemp to se Random Effects </h3>
***/
esttab se_tjb_msum*_re se_tpearn*_re se_ln_tpearn*_re , legend label varlabels(_cons Constant) title(Earnings se vs Unemp to se Random Effects) aic bic 

/***
<html>
<body>
<h3>Earnings: ws to se vs Unemp to se Fixed Effects </h3>
***/
esttab wsse*fe, legend label collabels(none) varlabels(_cons Constant) title(Earnings ws to se vs Unemp to se Fixed effects) aic bic 

/***
<html>
<body>
<h3>Earnings: ws to se vs Unemp to se Random Effects </h3>
***/

esttab wsse_tjb_msum*_re wsse_tpearn*_re wsse_ln_tpearn*_re , legend label varlabels(_cons Constant) title(Earnings ws to se vs Unemp to se Random effects) aic bic 

eststo clear 


















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
// due to using imputed jobs dataset we have to make sure these values are carried throughout the year properly. The value is constant within reference period by definition in sipp codebook. 
list swave monthcode tjb_prftb tbsjval if ssuid_spanel_pnum_id  ==  198178, sepby(swave)
gsort ssuid_spanel_pnum_id swave -tjb_prftb
by ssuid_spanel_pnum_id swave: carryforward tjb_prftb, replace 
gsort ssuid_spanel_pnum_id swave -tbsjval
by ssuid_spanel_pnum_id swave: carryforward tbsjval, replace 
list swave monthcode tjb_prftb tbsjval if ssuid_spanel_pnum_id  ==  198178, sepby(swave)

// now can create unique year tag given that we have prft and bus val  equal for every row per person per wave 
egen unique_yr_tag= tag(ssuid_spanel_pnum_id swave) // creating person-year flag 
list ssuid_spanel_pnum_id status_1 status_2 status_3 months_s1-months_s3 tjb_prft tbsjval in 1/50, sepby(ssuid_spanel_pnum_id)


/***
<html>
<body>
<h3> creating flags that signal which type of employment change occurred </h4>
***/
bysort ssuid_spanel_pnum_id (swave monthcode ): gen unemp_se = 1 if employment_type1[_n] ==2 & employment_type1[_n-1] == 4 // unemp_se 
bysort ssuid_spanel_pnum_id (swave monthcode): gen unemp_ws = 1 if employment_type1[_n] ==1 & employment_type1[_n-1] == 4 // unemp_ws
bysort ssuid_spanel_pnum_id (swave monthcode): gen ws_se = 1 if employment_type1[_n] == 2 & employment_type1[_n-1] == 1 // ws_se 
bysort ssuid_spanel_pnum_id (swave monthcode): gen se_ws = 1 if employment_type1[_n] == 1 & employment_type1[_n-1] == 2 // se_ws 

list employment_type status_1_lim-status_10_lim tpearn tjb_msum unemp_ws unemp_se ws_se se_ws if ssuid_spanel_pnum_id== 199553 

// ws_se period 
bysort ssuid_spanel_pnum_id (swave monthcode): carryforward ws_se, gen(ws_se_period) dynamic_condition(employment_type1[_n] == employment_type1[_n-1])
// unemp_se period 
bysort ssuid_spanel_pnum_id (swave monthcode): carryforward unemp_se, gen(unemp_se_period) dynamic_condition(employment_type1[_n] == employment_type1[_n-1])

// flags for our samples of interest 
gen se_only =1 if status_1 == 2 & status_2 == . 
replace se_only = 0 if se_only == .

bysort ssuid_spanel_pnum_id: egen ever_unemp_se = sum(unemp_se) // flag for ever transitioning from unemp to se 


// id of potential concern 2400 example 




// recoding profits 
gen profposi=tjb_prftb>0 if tjb_prftb<. // 
tab profpos, missing
gen prof10k=tjb_prftb>=10000 if tjb_prftb<.
tab prof10k, missing



keep if unique_yr_tag // now we're down to one row per person per year an

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



xtset ssuid_spanel_pnum_id swave 

// comparison group here is se_only 
eststo, title("M1"): quietly xtlogit profpos i.unemp_se, vce(robust)
eststo, title("M2"): quietly xtlogit profpos i.unemp_se i.educ3 i.initial_race $controls, vce(robust)

eststo, title("M1"): quietly xtlogit prof10k i.unemp_se, vce(robust)
eststo, title("M2"): quietly xtlogit prof10k i.unemp_se i.educ3 i.initial_race $controls, vce(robust)

eststo, title("M1"): quietly xtreg ln_tjb_prftb i.unemp_se, vce(robust)
eststo, title("M2"): quietly xtreg ln_tjb_prftb i.unemp_se i.educ3 i.initial_race $controls, vce(robust)



esttab, legend label collabels(none) varlabels(_cons Constant) title(Profit SE vs Unemp to SE)
eststo clear

eststo, title("M2 FE"): quietly xtlogit profpos i.unemp_se i.educ3 i.initial_race $controls,  fe
eststo, title("M2 FE"): quietly xtlogit prof10k i.unemp_se i.educ3 i.initial_race $controls,  fe
eststo, title("M2 FE"): quietly xtreg ln_tjb_prftb i.unemp_se i.educ3 i.initial_race $controls,  fe
esttab, legend label  varlabels(_cons Constant) title(Profit SE vs Unemp to SE Fixed Effects)
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
eststo, title("M1"): quietly xtlogit profpos i.unemp_se, vce(robust)
eststo, title("M2"): quietly xtlogit profpos i.unemp_se i.educ3 i.initial_race $controls, vce(robust)

eststo, title("M1"): quietly xtlogit prof10k i.unemp_se, vce(robust)
eststo, title("M2"): quietly xtlogit prof10k i.unemp_se i.educ3 i.initial_race $controls, vce(robust)

eststo, title("M1"): quietly xtreg ln_tjb_prftb i.unemp_se, vce(robust)
eststo, title("M2"): quietly xtreg ln_tjb_prftb i.unemp_se i.educ3 i.initial_race $controls, vce(robust) 

esttab, stats(N) legend label collabels(none) varlabels(_cons Constant) title(Profit: WS to SE vs Unemp to SE)
eststo clear

eststo, title("M2 FE"): quietly xtlogit profpos i.unemp_se i.educ3 i.initial_race $controls, fe
eststo, title("M2 FE"): quietly xtlogit prof10k i.unemp_se i.educ3 i.initial_race $controls, fe
eststo, title("M2 FE"): quietly xtreg ln_tjb_prftb i.unemp_se i.educ3 i.initial_race $controls, fe
esttab, legend label  varlabels(_cons Constant) title(Profit WS to SE vs Unemp to SE Fixed Effects)

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
eststo, title("M1"): quietly xtreg tbsjval i.unemp_se, vce(robust)
eststo, title("M2"): quietly xtreg tbsjval i.unemp_se i.educ3 i.initial_race  $controls, vce(robust)
eststo, title("M1"): quietly xtreg ln_tbsjval i.unemp_se, vce(robust)
eststo, title("M2"): quietly xtreg ln_tbsjval i.unemp_se i.educ3 i.initial_race  $controls, vce(robust)

eststo, title("M2"): quietly xtreg tbsjval i.unemp_se i.educ3 i.initial_race  $controls, fe 
eststo, title("M2"): quietly xtreg ln_tbsjval i.unemp_se i.educ3 i.initial_race  $controls, fe 


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
eststo, title("M1"): quietly xtreg tbsjval i.unemp_se, vce(robust) 
eststo, title("M2"): quietly xtreg tbsjval i.unemp_se i.educ3 i.initial_race $controls, vce(robust) 

eststo, title("M1"): quietly xtreg ln_tbsjval i.unemp_se, vce(robust) 
eststo, title("M2"): quietly xtreg ln_tbsjval i.unemp_se i.educ3 i.initial_race $controls, vce(robust)

 
eststo, title("M2"): quietly xtreg tbsjval i.unemp_se i.educ3 i.initial_race $controls,  fe 
eststo, title("M2"): quietly xtreg ln_tbsjval i.unemp_se i.educ3 i.initial_race $controls,  fe 

esttab, legend label collabels(none) varlabels(_cons Constant) title(Business Value WS to SE vs Unemp to SE)

eststo clear 
restore


*/

