capture log close

clear all
set more off
set trace off
pause on
macro drop _all

local homepath "/Volumes/Extreme SSD/SIPP Data Files/"
local datapath "`homepath'/dtas"

cd "`homepath'"


local c_time = c(current_time)
local today : display %tdCYND date(c(current_date), "DMY")

log using "./_logs/initial_data_prep_`today'.log", text replace 


/*
* Author: Nobles, Todd
* Email: tnobles@gmail.com
* Date: 2023_04_04
* File: initial_data_prep.do

* The borrows heavily from reg_probit_re_se.do and _sipp2014_data_prep.do both by Daniel Auguste

This script start with reading in the raw SIPP files, extracting the relevant work/income variables, reshaping the person-month-job variables to align with the person-month variables and then produces several working datasets. Previous version was named prelim.do.

Changelog
20230404: - added analysis to look into demographics of people who were only self-employed, wage&salary, or combo 
20230503: adding period of unemployment to monthly data
20230511: imputing job id when we have other job data present such as hours worked, wages, and type of employment. adds a total of ~200k person-job-month rows 
*/

cd "`datapath'"

**# Reading in data

/*------------------------------------------------------------------------------
1. The following section reads in the most recent three datasets and renames all vars
   to lower so that they match the earlier datasets
------------------------------------------------------------------------------*/

* "pu2019" //wage 2 of 2018 panel  collected in 2019
* "pu2020" //wage 3 of 2018 panel collected in 2020
* "pu2021" //wage 1 of 2021 panel collected in 2021


//creating working data set
global varbasic_ids="SPANEL SHHADID SWAVE MONTHCODE SSUID PNUM WPFINWGT"
global demographics="EEDUC TAGE ESEX ERACE EMS TCEB EBORNUS EORIGIN"

global jobs1="EJB*_JBORSE EJB*_CLWRK TJB*_EMPB EJB*_INCPB EJB*_JOBID EJB*_STARTWK EJB*_ENDWK TJB*_MWKHRS TJB*_IND TJB*_OCC"
global jobs1_reshape="EJB@_JBORSE EJB@_CLWRK TJB@_EMPB EJB@_INCPB EJB@_JOBID EJB@_STARTWK EJB@_ENDWK TJB@_MWKHRS TJB@_IND TJB@_OCC"
global jobs2="EJB*_TYPPAY1 TJB*_GAMT1 EJB*_BSLRYB *TBSJ*VAL TJB*_PRFTB TBSJ*DEBTVAL TJB*_MSUM" 
global jobs2_reshape="EJB@_TYPPAY1 TJB@_GAMT1 EJB@_BSLRYB TBSJ@VAL TJB@_PRFTB TBSJ@DEBTVAL TJB@_MSUM"

global wealth="TIRAKEOVAL TTHR401VAL TIRAKEOVAL TTHR401VAL TVAL_AST THVAL_AST TNETWORTH THNETWORTH TVAL_HOME THVAL_HOME TEQ_HOME THEQ_HOME TPTOTINC TPEARN TEQ_BUS ENJFLAG"
global debts="TDEBT_AST THDEBT_AST TOEDDEBTVAL THEQ_HOME TDEBT_CC THDEBT_CC TDEBT_ED THDEBT_ED TDEBT_HOME THDEBT_HOME TDEBT_BUS"   

local file_list "pu2019 pu2020 pu2021"
foreach x of local file_list {
	
use $varbasic_ids $demographics $jobs1 $jobs2 $wealth $debts using `x', clear

rename *, lower
save `x'_lowercase,replace 
}

**# Creating unique id list 

/*------------------------------------------------------------------------------
2. Now that all datasets are in th same format we set up our macros and create our 
	dataset of unique person-ids
------------------------------------------------------------------------------*/
clear all
macro drop _all
set more off 

global file1="pu2014w1"
global file2="pu2014w2"
global file3="pu2014w3_13"
global file4="pu2014w4"
global file5="pu2018"
global file6="pu2019_lowercase"
global file7="pu2020_lowercase"
global file8="pu2021_lowercase"

global varbasic_ids="spanel shhadid swave monthcode ssuid pnum wpfinwgt"
global demographics="eeduc tage esex erace ems tceb ebornus eorigin"

//This section creates our unique list of person level IDs
clear
save id2, replace emptyok 
foreach num of numlist 1/8 {
use $varbasic_ids $demographics using ${file`num'}, clear
compress
append using id2
save id2, replace
} 

 
egen ssuid_spanel_pnum_id = group(ssuid spanel pnum)

sort ssuid_spanel_pnum_id swave monthcode 

preserve
qby ssuid_spanel_pnum_id: keep if _n==1
keep ssuid_spanel_pnum_id ssuid spanel pnum $demographics


recode esex (1=0 Male) (2=1 Female),gen(sex) 
label variable sex "sex"


//recode education
codebook eeduc 
recode eeduc (31/39=1 "High school or less") ///
(40/42=2 "Some college or associate") ///
(43=3 "Bachelors degree") ///
(44/46=4 "Graduate  degree"), gen(educ3)
tab educ3

label define educ3_label 1"hsorles" 2"somcolorasso" 3"college" 4"graddeg"
label list educ3_label
label values educ3 educ3_label
codebook educ3
label variable educ3 "education"


//recode immigrant 
recode ebornus (1=0 "born in US") (2=1 "not born in US"), gen(immigrant)
tab immigrant
label variable immigrant "immigrant"
tab ebornus
save unique_individuals,replace // list of unique individuals with basic demographics but not time-varying age here
restore

preserve
keep if monthcode == 12
keep ssuid_spanel_pnum_id spanel swave monthcode wpfinwgt // person-year weights
save person-year-weights.dta, replace
restore 


**# Reshaping from wide jobs to long 

/*------------------------------------------------------------------------------
3. Here we reshape a number of jobs variables to get them from wide to long 
------------------------------------------------------------------------------*/

global jobs1="ejb*_jborse ejb*_clwrk tjb*_empb ejb*_incpb ejb*_jobid ejb*_startwk ejb*_endwk tjb*_mwkhrs tjb*_ind tjb*_occ"
global jobs1_reshape="ejb@_jborse ejb@_clwrk tjb@_empb ejb@_incpb ejb@_jobid ejb@_startwk ejb@_endwk tjb@_mwkhrs tjb@_ind tjb@_occ"
global jobs2="ejb*_typpay1 tjb*_gamt1 ejb*_bslryb *tbsj*val tjb*_prftb tbsj*debtval tjb*_msum" 
global jobs2_reshape="ejb@_typpay1 tjb@_gamt1 ejb@_bslryb tbsj@val tjb@_prftb tbsj@debtval tjb@_msum"

global wealth="tirakeoval tthr401val tirakeoval tthr401val tval_ast thval_ast tnetworth thnetworth tval_home thval_home teq_home theq_home tptotinc tpearn teq_bus enjflag"
global debts="tdebt_ast thdebt_ast toeddebtval theq_home tdebt_cc thdebt_cc tdebt_ed thdebt_ed tdebt_home thdebt_home tdebt_bus"  

// imputed jobs version 
foreach num of numlist 1/8 {
	
di "wave `num'"

use $varbasic_ids $jobs1 $jobs2  using ${file`num'}, clear

	
capture drop _merge
merge m:1 ssuid spanel pnum using unique_individuals, keep(1 3)
capture drop _merge
keep $varbasic_ids $jobs1 $jobs2 ssuid_spanel_pnum_id

foreach x of numlist 1/7 {
	replace ejb`x'_jobid = `x' if ejb`x'_jobid == . & tjb`x'_mwkhrs !=. & (tjb`x'_msum !=. | tjb`x'_prftb != .) 
}

reshape long $jobs1_reshape $jobs2_reshape, i(ssuid_spanel_pnum_id monthcode) j(job)

save sipp2014_wv`num'_reshaped_work_imputed, replace //obs here is person-job-month


}


// non-imputed job ids 
foreach num of numlist 1/8 {
	
di "wave `num'"

use $varbasic_ids $jobs1 $jobs2  using ${file`num'}, clear

	
capture drop _merge
merge m:1 ssuid spanel pnum using unique_individuals, keep(1 3)
capture drop _merge
keep $varbasic_ids $jobs1 $jobs2 ssuid_spanel_pnum_id

reshape long $jobs1_reshape $jobs2_reshape, i(ssuid_spanel_pnum_id monthcode) j(job)

save sipp2014_wv`num'_reshaped_work, replace //obs here is person-job-month


}


// Combining the various datasets we've reshaped above into one dataset that contains all our years of data and is in long format for job level information

// combining non-imputed files (as we get them from SIPP )
clear
save sipp_reshaped_work_comb, replace emptyok 
foreach num of numlist 1/8 {
	use sipp2014_wv`num'_reshaped_work, clear
	keep if ejb_jobid != .
	append using sipp_reshaped_work_comb
	save sipp_reshaped_work_comb, replace // this dataset contains person-wave-month-job level rows
}

// combining imputed files
clear
save sipp_reshaped_work_comb_imputed, replace emptyok 
foreach num of numlist 1/8 {
	use sipp2014_wv`num'_reshaped_work_imputed, clear
	keep if ejb_jobid != .
	append using sipp_reshaped_work_comb_imputed
	save sipp_reshaped_work_comb_imputed, replace // this dataset contains person-wave-month-job level rows
}


//2362583 obs before redoing 
// 2569865 obs after imputing jobid 

**# Descriptive analyses of who is self-employed

/*------------------------------------------------------------------------------
3.1 Descriptive analysis to determine demograhpics of those who are self-employed vs wage&salary vs both
------------------------------------------------------------------------------*/

use sipp_reshaped_work_comb_imputed, clear  // this dataset contains person-wave-month-job level rows for all years of data we have 

merge m:1 ssuid_spanel_pnum_id using unique_individuals, keep(1 3) // bringing in demographic info. Age here is a snapshot from one of our records, someone could have aged out towards the later years, but shouldn't mess with results too much 


/*------------------------------------------------------------------------------
3.1.1 recoding demographic vars and filtering to pop of interest
------------------------------------------------------------------------------*/
//working with the black-white sample
keep if erace==1|erace==2 //this keeps the black and white sample only.
codebook erace

// recode race
recode erace (2=1 Black) (nonmiss=0 White), into(black)
label variable black "race"


// filtering to population of interest
keep if tage>=18 & tage<=64
drop if ejb_jborse == 3 


gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // note we did not pre-filter to only jobs with certain number of hours 

// how many cases of flip-flopping are there (where a jobid is main, then it isn't, then it is again)
sort ssuid_spanel_pnum_id ejb_jobid swave monthcode
qby ssuid_spanel_pnum_id ejb_jobid: gen jb_main_m1=jb_main[_n-1]
qby ssuid_spanel_pnum_id ejb_jobid: gen jb_main_p1=jb_main[_n+1]
gen flip=jb_main_m1==1 & jb_main==0 & jb_main_p1==1
replace flip=1 if jb_main_m1==0 & jb_main==1 & jb_main_p1==0

sort ssuid_spanel_pnum_id spanel swave monthcode job
order ssuid_spanel_pnum_id spanel swave monthcode job ejb_jborse tjb_msum tjb_mwkhrs jb_main

frame copy default month_job_level, replace // storing dataframe we can return to


**# Tables of ANY self employent ever
*------------------------------------------------------------------------------/
// making a flag for if they were self-employed at any time during our data
bysort ssuid_spanel_pnum_id: gen any_self_emp = 1 if ejb_jborse == 2
by ssuid_spanel_pnum_id: carryforward any_self_emp, replace //carrying forward so this flag is constant throughout all of their obs
gsort ssuid_spanel_pnum_id -spanel -swave -monthcode -job
by ssuid_spanel_pnum_id: carryforward any_self_emp, replace back

// getting down to one row per unique id
by ssuid_spanel_pnum_id: keep if _n == 1
replace any_self_emp = 0 if any_self_emp == . 

// from raw percentages, there's a smaller share of working age black respondents engaged in self-employment than working age white respondents
tabulate any_self_emp black, missing col
tabulate any_self_emp educ3, missing col
table (educ3) (any_self_emp black), totals(any_self_emp) statistic(percent, across(any_self_emp))

table (educ3 black) (any_self_emp) (result), statistic(percent, across(any_self_emp)) statistic(frequency)

frame copy month_job_level subtask 
frame change subtask


**# Tables of any self-employment within each year 
*------------------------------------------------------------------------------/
// making a flag for if they were self-employed at any time during a year
bysort ssuid_spanel_pnum_id: gen any_self_emp = 1 if ejb_jborse == 2
bysort ssuid_spanel_pnum_id spanel swave: carryforward any_self_emp, replace //carrying forward so this flag is constant throughout all of their obs (minus one which is accounted for in the collapse below)


collapse (mean) any_self_emp, by(ssuid_spanel_pnum_id spanel swave black sex educ3)
replace any_self_emp = 0 if any_self_emp == .


// note tables here are person-year, that's why the counts are much higher than the previous. Story is the same though. 
tabulate any_self_emp black, missing col
tabulate any_self_emp educ3, missing col
table (educ3) (any_self_emp black), totals(any_self_emp) statistic(percent, across(any_self_emp))



**# Tables of main job as self-employed
*------------------------------------------------------------------------------/
frame copy month_job_level subtask3
frame change subtask3

keep if jb_main == 1 & tjb_mwkhrs >= 15

bysort ssuid_spanel_pnum_id: generate  diff = ejb_jborse[1] != ejb_jborse[_N] // getting flag for if type of employment of main job chagnes over time
su diff, detail 

unique ssuid_spanel_pnum_id if diff ==1
list spanel swave monthcode job ejb_jborse jb_main if ssuid_spanel_pnum_id ==1039 // this person shifted mid year to self-emp as main job-month

// we'll test a few ways of categorizing someone as self-employed at the yearly level here. 
// first off categorizing them as self-employed if they started the year as self-emp
bysort ssuid_spanel_pnum_id spanel swave: gen year_start = 1 if _n ==1 

tab ejb_jborse black if year_start == 1, missing col 
table (educ3) (ejb_jborse black) if year_start ==1 , totals(ejb_jborse) statistic(percent, across(ejb_jborse)) 

// generally the same story as the flag above for self-employment at any time during the year


// one other way to look at it is by the percent of months (per year) they were self-employed
gen main_self_emp = 1 if ejb_jborse==2 & jb_main == 1
bysort ssuid_spanel_pnum_id spanel swave : egen months_main_self_emp = sum(main_self_emp)
bysort ssuid_spanel_pnum_id spanel swave: gen months_present = _N
gen pct_months_main_job_self_emp = months_main_self_emp/months_present

collapse (mean) pct_months_main_job_self_emp, by(ssuid_spanel_pnum_id spanel swave black educ3 sex) // collapsing down to one record per person per year
egen gp = group(spanel swave), label(gp, replace)
tabstat pct_months, by(gp)

tabstat pct_months_main_job_self_emp, by(black) stat(mean sd min median max)

tabstat pct_months_main_job_self_emp if black==1, by(educ3) 
tabstat pct_months_main_job_self_emp if black ==0, by(educ3)

// Any difference between those with no self-employment, those with some, and those with only some. This is at person-year level 
gen self_emp_group = "w&s only" if pct_months_main_job_self_emp ==0 
replace self_emp_group = "self-emp only" if pct_months_main_job_self_emp == 1
replace self_emp_group = "both" if pct_months_main_job_self_emp >0 & pct_months_main_job_self_emp <1
codebook self_emp_group

table  (black) (self_emp_group), statistic(percent, across(black))
table (sex) (self_emp_group), statistic(percent, across(sex))
table (educ3) (self_emp_group), statistic(percent, across(educ3))



// final way might be to do it by the amount of income they get from any job
frame change month_job_level
frame copy month_job_level subtask4
frame change subtask4

list ssuid_spanel_pnum_id ejb_jborse job tjb_msum in 1/14

collapse (sum) tjb_msum, by(ssuid_spanel_pnum_id spanel swave ejb_jborse black educ3)
duplicates report ssuid_spanel_pnum_id spanel swave
reshape wide tjb_msum*, i(ssuid_spanel_pnum_id spanel swave black educ3) j(ejb_jborse) 
rename tjb_msum1 tjb_msum_ws 
rename tjb_msum2 tjb_msum_se 
replace tjb_msum_ws = 0 if tjb_msum_ws ==. 
replace tjb_msum_se = 0 if tjb_msum_se == .

gen self_employed = 1 if tjb_msum_se > tjb_msum_ws 
replace self_employed = 0 if tjb_msum_se < tjb_msum_ws
// missings here are where they were both zeros
table (educ3) (self_employed black) , totals(self_employed) statistic(percent, across(self_employed)) 



**# Discussion Point 1
// to discuss how we want to categorize someone as self-employed at the yearly level given that this shifts for some folks throughout the year with the way we've constructed main job. 



**# Here I'll move ahead with if their main job in the first month of the wave 
//was self-employed then they're self-employed for the wave.

frame copy month_job_level self_emp_flag, replace 
frame change self_emp_flag

keep if jb_main == 1 & tjb_mwkhrs >= 15


bysort ssuid_spanel_pnum_id spanel swave: keep if _n ==1 
keep ssuid_spanel_pnum_id spanel swave ejb_jborse 
recode ejb_jborse (2=1 Self_Employed) (1=0 Wage_Salary), into(self_emp_year_start)
save self_empl_flag, replace 
// now we have one record per person per year that gives us their year's self-employment status. 



**# Summary of home and business equity and  home and business debt

clear
save sipp_monthly_combined, replace emptyok
foreach num of numlist 1/8 {
	
di "wave `num'"

use $varbasic_ids $demographics $wealth $debts using ${file`num'}, clear

// now create the other monthly data (which doesn't have to be rehaped by job)	
capture drop _merge 
merge m:1 ssuid spanel pnum using unique_individuals , keep(1 3)
capture drop _merge 

compress 
save sipp_wv`num'_monthly, replace

append using sipp_monthly_combined
save sipp_monthly_combined, replace  
}

frame change default
use sipp_monthly_combined, clear // loading monthly data
keep if erace == 1 | erace == 2 
recode erace (2=1 Black) (nonmiss=0 White), into(black)
label variable black "race"

merge m:1 ssuid_spanel_pnum_id spanel swave using self_empl_flag, keep(3)
keep if tage>=18 & tage<=64


/*foreach x in  teq_bus teq_home   {
	egen min_`x' = min(`x')
	replace min_`x' = min_`x' *-1
	gen ln_`x' = ln(`x' + min_`x'+1)
} 
*/


// The following are all constant throughout the wave so we use the 12th month per this example here https://www.census.gov/data/academy/webinars/2019/sipp-series/assets-income-poverty.html

**# Home debt

tabstat tdebt_home if monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat tdebt_home if black == 1 & monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
tabstat tdebt_home if black == 0 & monthcode ==12, by(educ3) stat(n, mean, sd, min, median, max)

tabstat tdebt_home if monthcode == 12, by(self_emp_year_start) stat(n, mean, sd, min, median, max)

tabstat tdebt_home if monthcode == 12 & black == 1, by(self_emp_year_start) stat(n, mean, sd, min, median, max)
tabstat tdebt_home if monthcode == 12 & black == 0, by(self_emp_year_start) stat(n, mean, sd, min, median, max)


**# Home Equity 

tabstat teq_home if monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
pwmean teq_home if  monthcode == 12, over(educ3) pveffects mcompare(tukey)

tabstat teq_home if black == 1 & monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
pwmean teq_home if black == 1 & monthcode == 12, over(educ3) pveffects mcompare(tukey)
tabstat teq_home if black == 0 & monthcode == 12, by(educ3) stat(n, mean, sd, min, median, max)
pwmean teq_home if black == 0 & monthcode == 12, over(educ3) pveffects mcompare(tukey)


ttest teq_home if monthcode == 12, by(self_emp_year_start)
ttest teq_home if monthcode == 12 & black ==1, by(self_emp_year_start)
ttest teq_home if black == 0 & monthcode ==12, by(self_emp_year_start)



**# Busines Equity 
tabstat teq_bus if self_emp_year_start==1 & monthcode ==12, by(educ3) stat(n, mean, sd, min, median, max)
pwmean teq_bus if monthcode == 12 & self_emp_year_start == 1, over(educ3) pveffects mcompare(tukey)
tabstat teq_bus if black == 1 & self_emp_year_start ==1 & monthcode ==12, by(educ3) stat(n, mean, sd, min, median, max)
pwmean teq_bus if black == 1 & monthcode == 12 & self_emp_year_start == 1, over(educ3) pveffects mcompare(tukey)
tabstat teq_bus if black == 0 & self_emp_year_start ==1 & monthcode ==12, by(educ3) stat(n, mean, sd, min, median, max)
pwmean tdebt_bus if black == 0 & monthcode == 12 & self_emp_year_start == 1, over(educ3) pveffects mcompare(tukey)


**# Business Debt
tabstat tdebt_bus if monthcode ==12 & self_emp_year_start ==1, by(educ3) stat(n, mean, sd, min, median, max)

pwmean tdebt_bus if monthcode == 12 & self_emp_year_start == 1, over(educ3) pveffects mcompare(tukey)

tabstat tdebt_bus if black == 1 & monthcode ==12 & self_emp_year_start ==1, by(educ3) stat(n, mean, sd, min, median, max)

pwmean tdebt_bus if black == 1 & monthcode == 12 & self_emp_year_start == 1, over(educ3) pveffects mcompare(tukey)

tabstat tdebt_bus if black == 0 & monthcode ==12 & self_emp_year_start ==1, by(educ3) stat(n, mean, sd, min, median, max)
pwmean tdebt_bus if black == 0 & monthcode == 12 & self_emp_year_start == 1, over(educ3) pveffects mcompare(tukey)



**# Business value for business that are jobs (TBSJVAL)
frame copy month_job_level subtask5, replace 
frame change subtask5

list ssuid_spanel_pnum_id monthcode job tbsjval if ejb_jborse == 2 in 1/1000 

bysort ejb_jborse: su tbsjval // how are these 35 people citing business value for jobs that aren't self employment?

egen tag = tag(ssuid_spanel_pnum_id spanel swave job tbsjval)
bysort ssuid_spanel_pnum_id spanel swave job: egen tag_sum = sum(tag)
su tag_sum // confirms that bus val stays constant within job
drop tag_sum
bysort ssuid_spanel_pnum_id spanel swave: egen tag_sum = sum(tag)
su tag_sum // some folks reporting up to 5 jobs in a year, but how many?

duplicates report ssuid_spanel_pnum_id spanel swave if tag ==1

// at this point we're still at where someone could have multiple jobs listed in the data. Each business can have different value, so we collapse down to monthly business value 
bysort ssuid_spanel_pnum_id spanel swave monthcode: egen month_tot_tbsjval = sum(tbsjval)

bysort ssuid_spanel_pnum_id spanel swave monthcode: keep if _n ==1 
// now we have person-month level file here. The business values will be constant within swaves so we can summarize using the same monthcode ==12 again here. 

drop _merge
merge m:1 ssuid_spanel_pnum_id spanel swave using self_empl_flag, keep(3)
keep if tage>=18 & tage<=64

tabstat month_tot_tbsjval if monthcode ==12 & self_emp_year_start ==1, by(educ3) stat(n, mean, sd, min, median, max)
tabstat month_tot_tbsjval if black == 1 & monthcode ==12 & self_emp_year_start ==1, by(educ3) stat(n, mean, sd, min, median, max)
tabstat month_tot_tbsjval if black == 0 & monthcode ==12 & self_emp_year_start ==1, by(educ3) stat(n, mean, sd, min, median, max)















