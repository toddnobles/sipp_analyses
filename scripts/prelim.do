capture log close

clear all
set more off
set trace off
pause on
macro drop _all

local homepath "/Users/toddnobles/Documents/SIPP Data Files/"
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
*/

cd "`datapath'"

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

global wealth="TIRAKEOVAL TTHR401VAL TIRAKEOVAL TTHR401VAL TVAL_AST THVAL_AST TNETWORTH THNETWORTH TVAL_HOME THVAL_HOME TEQ_HOME THEQ_HOME TPTOTINC TPEARN"
global debts="TDEBT_AST THDEBT_AST TOEDDEBTVAL THEQ_HOME TDEBT_CC THDEBT_CC TDEBT_ED THDEBT_ED TDEBT_HOME THDEBT_HOME"   

local file_list "pu2019 pu2020 pu2021"
foreach x of local file_list {
	
use $varbasic_ids $demographics $jobs1 $jobs2 $wealth $debts using `x', clear

rename *, lower
save `x'_lowercase,replace 
}


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
keep ssuid_spanel_pnum_id ssuid spanel pnum 
save unique_individuals,replace // list of unique individuals
restore

preserve
keep if monthcode == 12
keep ssuid_spanel_pnum_id spanel swave monthcode wpfinwgt // person-year weights
save person-year-weights.dta, replace
restore 



/*------------------------------------------------------------------------------
3. Here we reshape a number of jobs variables to get them from wide to long 
------------------------------------------------------------------------------*/

global jobs1="ejb*_jborse ejb*_clwrk tjb*_empb ejb*_incpb ejb*_jobid ejb*_startwk ejb*_endwk tjb*_mwkhrs tjb*_ind tjb*_occ"
global jobs1_reshape="ejb@_jborse ejb@_clwrk tjb@_empb ejb@_incpb ejb@_jobid ejb@_startwk ejb@_endwk tjb@_mwkhrs tjb@_ind tjb@_occ"
global jobs2="ejb*_typpay1 tjb*_gamt1 ejb*_bslryb *tbsj*val tjb*_prftb tbsj*debtval tjb*_msum" 
global jobs2_reshape="ejb@_typpay1 tjb@_gamt1 ejb@_bslryb tbsj@val tjb@_prftb tbsj@debtval tjb@_msum"

global wealth="tirakeoval tthr401val tirakeoval tthr401val tval_ast thval_ast tnetworth thnetworth tval_home thval_home teq_home theq_home tptotinc tpearn"
global debts="tdebt_ast thdebt_ast toeddebtval theq_home tdebt_cc thdebt_cc tdebt_ed thdebt_ed tdebt_home thdebt_home"  


foreach num of numlist 1/8 {
	
di "wave `num'"

use $varbasic_ids $jobs1 $jobs2  using ${file`num'}, clear

	
capture drop _merge
merge m:1 ssuid spanel pnum using unique_individuals, keep(1 3)
capture drop _merge
keep $varbasic_ids $jobs1 $jobs2 ssuid_spanel_pnum_id

reshape long $jobs1_reshape $jobs2_reshape, i(ssuid_spanel_pnum_id monthcode) j(job)

tab ejb_jobid, missing
keep if ejb_jobid~=. 

gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1

// how many cases of flip-flopping are there (where a jobid is main, then it isn't, then it is again)
sort ssuid_spanel_pnum_id ejb_jobid swave monthcode
qby ssuid_spanel_pnum_id ejb_jobid: gen jb_main_m1=jb_main[_n-1]
qby ssuid_spanel_pnum_id ejb_jobid: gen jb_main_p1=jb_main[_n+1]
gen flip=jb_main_m1==1 & jb_main==0 & jb_main_p1==1
replace flip=1 if jb_main_m1==0 & jb_main==1 & jb_main_p1==0


save sipp2014_wv`num'_reshaped_work, replace //obs here is person-job-month


}



// Combining the various datasets we've reshaped above into one dataset that contains all our years of data and is in long format for job level information
clear
save sipp_reshaped_work_comb, replace emptyok 
foreach num of numlist 1/8 {
	use sipp2014_wv`num'_reshaped_work, clear
	append using sipp_reshaped_work_comb
	save sipp_reshaped_work_comb, replace // this dataset contains person-wave-month-job level rows
}

use sipp_reshaped_work_comb, clear  // this dataset contains person-wave-month-job level rows 


// we're not interested in 
drop if ejb_jborse==3 // get rid of other employment 

//is their main job self-employment? we want an overall person level flag for this

gen main_self_emp = 1 if ejb_jborse==2 & jb_main == 1
bysort ssuid_spanel_pnum_id: egen months_main_self_emp = sum(main_self_emp)
bysort ssuid_spanel_pnum_id: gen months_in_data = _N
gen pct_months_main_job_self_emp = months_main_self_emp/months_in_data

bysort ejb_jborse: su tbsjval // how are these people citing business value for jobs that aren't self employment
 
preserve
egen tag = tag(ssuid_spanel_pnum_id spanel swave job tbsjval)
bysort ssuid_spanel_pnum_id spanel swave job: egen tag_sum = sum(tag)
su tag_sum
keep if tag 
collapse (sum) tbsjval, by(ssuid_spanel_pnum_id spanel swave) 
save tbsjval_by_year, replace
restore



collapse (sum) tjb_msum tjb_prftb (mean) tjb_mwkhrs pct_months_main_job_self_emp, ///
			by(ssuid_spanel_pnum_id spanel swave monthcode ejb_jborse wpfinwgt)
recode ejb_jborse (2=1 "self-employed") (nonmiss=0 "wage&salary"), into(selfemp)
*recode jb_main (1=1 "main") (0=0 "secondary"), into(primary_job)
drop ejb_jborse

save sipp_reshaped_work_comb_collapsed, replace //obs here is person-jobtype-month


/*------------------------------------------------------------------------------
4. Now we handle the variables that come properly shaped (still working in person-month)
	format here
------------------------------------------------------------------------------*/
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

/*------------------------------------------------------------------------------
5. Combining our two working datasets here to get one file that has all income vars of interest
	Each row is a person-month and we have 
	- income variables calcualted by SIPP of tpearn and tptotinc along with 
	- income variables calculated above that capture earnings from selfeomployment and wage&salary
------------------------------------------------------------------------------*/
use sipp_reshaped_work_comb_collapsed, clear


// how many people reported business profit but didnt report msum 
unique ssuid_spanel_pnum_id if selfemp==1 & tjb_msum ==0 & tjb_prftb >0 & tjb_mwkhrs >0

drop tjb_mwkhrs

reshape wide tjb_msum* tjb_prftb*, i(ssuid_spanel_pnum_id monthcode spanel swave pct_months_main_job_self_emp) j(selfemp) 

rename tjb_msum0 tjb_msum_ws
rename tjb_msum1 tjb_msum_se

summarize tjb_prftb*
drop tjb_prftb0 // this is always zero

merge 1:1 ssuid_spanel_pnum_id swave monthcode using sipp_monthly_combined, keep(1 3)

save sipp_income, replace 



/*------------------------------------------------------------------------------
6. Labeling and recoding demographic vars 
------------------------------------------------------------------------------*/
capture log close 

local homepath "/Users/toddnobles/Documents/SIPP Data Files/"
local datapath "`homepath'/dtas"
local outputpath "`homepath'/outputs"

cd "`homepath'"
log using "./_logs/earnings_distributions.log", text replace 

cd "`datapath'"

use sipp_income, clear

// recode sex
codebook esex
recode esex (1=0 Male) (2=1 Female),gen(sex) 
codebook sex

//working with the black-white sample
keep if erace==1|erace==2 //this keeps the black and white sample only.
codebook erace

codebook eeduc 
tab eeduc 


//recode education
label define educ_label 31 "Less than 1st grade" ///
32 "1st, 2nd, 3rd or 4th grade" ///
33 "5th or 6th grade" ///
34 "7th or 8th grade" ///
35 "9th grade" ///
36 "10th grade" ///
37 "11th grade" ///
38 "12th grade, no diploma" ///
39 "High School Graduate (diploma or GED or equivalent)" ///
40 "Some college credit, but less than 1 year (regular Jr.coll./coll./univ.)" ///
41 "1 or more years of college, no degree (regular Jr.coll./coll./univ.)" ///
42 "Associate's degree (2-year college)" ///
43 "Bachelor's degree (for example: BA, AB, BS)" ///
44 "Master's degree (for example: MA, MS, MBA, MSW)" ///
45 "Professional School degree (for example: MD (doctor), DDS (dentist), JD (lawyer))" ///
46 "Doctorate degree (for example: Ph.D., Ed.D.)" 
label values eeduc educ_label

recode eeduc (31/38=1 "Less than high school") ///
(39=2 "High school diploma or GED") ///
(40/41=3 "Some College") ///
(42=4 "Associate's degree (2-year college)") ///
(43=5 "College degree") ///
(44/46=6 "Graduate school degree"), gen(educ)
tab educ

recode educ (1/2=1 "High school or less") (nonmiss=0 "More than high school"), into(hsorles)
recode educ (3/4=1 "Some college or associate") (nonmiss=0 "allother"), into(somcolorasso)
recode educ (5=1 "College degree") (nonmiss=0 "allother"), into(college)
recode educ (6=1 "Graduate degree") (nonmiss=0 "allother"), into(graddeg)

codebook hsorles somcolorasso college graddeg
gen educ3=.
codebook educ3
replace educ3=1 if  hsorles==1
tab educ3 hsorles,missing

replace educ3=2 if somcolorasso==1
tab educ3 somcolorasso,missing

replace educ3=3 if college==1
tab educ3 college,missing

replace educ3=4 if graddeg==1
tab educ3 graddeg,missing

label define educ3_label 1"hsorles" 2"somcolorasso" 3"college" 4"graddeg"
label list educ3_label
label values educ3 educ3_label
codebook educ3

// code race
recode erace (2=1 Black) (nonmiss=0 White), into(black)

//recode immigrant 
recode ebornus (1=0 "born in US") (2=1 "not born in US"), gen(immigrant)
tab immigrant
tab ebornus

tab ems
rename ems mari_status

recode tceb (1/7=1 "Have a child or more") (0=0 "Have no children"), gen(parent)
tab tceb
tab parent

// creating age2 
gen age2 = tage^2 

keep if tage>=18 & tage<=64

save monthly_working.dta, replace 


cd "`outputpath'"
/*------------------------------------------------------------------------------
7. Monthly income
------------------------------------------------------------------------------*/
** 

// looking first at tjb_msum vars 
egen gp=group(black educ3), label 

tabstat tjb_msum_se tjb_msum_ws, by(black) stat(n mean sd median min max) 
tabstat  tjb_msum_ws, by(gp) stat(n mean sd median min max) 
tabstat tjb_msum_se, by(gp) stat(n mean sd median min max)

tabstat tjb_msum_se tjb_msum_ws if black==1, by(educ3) stat(n mean, sd, min max)  // black by educ
tabstat tjb_msum_se tjb_msum_ws if black==0, by(educ3) stat(n mean, sd, min max) // white by educ

// logged versions

gen ln_tjb_msum_se = ln(tjb_msum_se + 1)
gen ln_tjb_msum_ws = ln(tjb_msum_ws + 1)


tabstat ln_tjb_msum_se ln_tjb_msum_ws, by(black) stat(n mean sd median min max) 
tabstat ln_tjb_msum_se ln_tjb_msum_ws, by(gp) stat(n mean sd median min max)

tabstat ln_tjb_msum_se ln_tjb_msum_ws if black==1, by(educ3) stat(n mean, sd, min max) // black by educ
tabstat ln_tjb_msum_se ln_tjb_msum_ws if black==0, by(educ3) stat(n mean, sd, min max) // white by educ

//Graphs

twoway histogram ln_tjb_msum_se, by(black, title("Distribution of Log Monthly Self-Employment Earnings", size(small))) 
graph export se_monthly_by_race, as(png)


twoway histogram ln_tjb_msum_ws, by(black, title("Distribution of Log Monthly Wage Earnings", size(small))) 
graph export ws_monthly_by_race, as(png)

twoway histogram ln_tjb_msum_ws, by(educ3 black ,title("Distribution of Log Monthly Wage Earnings", size(small))) 
graph export ws_monthly_by_race_educ, as(png)

twoway histogram ln_tjb_msum_ws, by(educ3 black ,title("Distribution of Log Monthly Self-Employment Earnings", size(small))) 
graph export se_monthly_by_race_educ, as(png)


drop _merge

vioplot ln_tjb_msum_ws, over(educ3) over(black) title(W&S Monthly Income)
graph export ws_monthly_by_race_educ_vioplot, as(png)

tabstat ln_tjb_msum_ws, by(gp) stat(n mean sd min median max)

tabstat ln_tjb_msum_se, by(gp) stat(n mean sd min median max)


vioplot ln_tjb_msum_se, over(educ3) over(black) title(SE Monthly Income)
graph export se_monthly_by_race_educ_vioplot, as(png)




/*------------------------------------------------------------------------------
8. Annual income
------------------------------------------------------------------------------*/

collapse (sum) tjb_msum* tpearn tptotinc, by(ssuid_spanel_pnum_id spanel swave sex educ3 black pct_months_main_job_self_emp) 
merge 1:1 ssuid_spanel_pnum_id swave using person-year-weights, keep(3)
gen ln_tjb_msum_se = ln(tjb_msum_se)
gen ln_tjb_msum_ws = ln(tjb_msum_ws)
egen min_tpearn = min(tpearn) 
replace min_tpearn = min_tpearn * -1
gen ln_tpearn = ln(tpearn + min_tpearn + 1)
egen min_tptotinc = min(tptotinc) 
replace min_tptotinc = min_tptotinc * -1
gen ln_tptotinc = ln(tptotinc + min_tptotinc + 1)

// looking first at tjb_msum vars 
egen gp=group(black educ3), label(gp, replace)

tabstat tjb_msum_se tjb_msum_ws, by(black) stat(n mean sd median min max)
tabstat tjb_msum_ws, by(gp) stat(n mean sd median min max)
tabstat tjb_msum_se, by(gp) stat(n mean sd median min max)


tabstat tjb_msum_se tjb_msum_ws if black==1, by(educ3) stat(n mean, sd, min max) // black by educ
tabstat tjb_msum_se tjb_msum_ws if black==0, by(educ3) stat(n mean, sd, min max) // white by educ

vioplot ln_tjb_msum_se, over(educ3) over(black) title(Self_employment Annual income (logged))
graph export se_annual_by_race_educ_vioplot, as(png)

vioplot ln_tjb_msum_ws, over(educ3) over(black) title(W&S Annual Income (logged))
graph export ws_annual_by_race_educ_vioplot, as(png)


//looking at tpearn 

bysort black: summarize tpearn
bysort black: summarize ln_tpearn



/*-----------------------------------------------------------------------------/
Keeping only those with greater than half of their months with self employment
------------------------------------------------------------------------------*/
keep if pct_months_main_job_self_emp >=.5 

bysort educ3 black: summarize  ln_tpearn 


vioplot ln_tpearn, over(educ3) over(black) title(Total Job Earnings for those with >50% SE)
graph export ln_tpearn_annual_by_race_educ_vioplot_gt50se, as(png)
vioplot tpearn if tpearn <300000, over(educ3) over(black) title(Total Job Earnings for those with >50% SE) note(filtered to remove upper extremes >300k)
graph export ln_tpearn_annual_by_race_educ_vioplot_gt50se_rmoutlier, as(png)

vioplot tpearn, over(blac) over(educ3) 





/*-----------------------------------------------------------------------------/
Keeping only those with full-time self-employment
------------------------------------------------------------------------------*/
keep if pct_months_main_job_self_emp ==1 
tabstat ln_tpearn, by(black) stat(n mean sd min max)
tabstat ln_tpearn, by(black) stat(n mean sd min max), [aweight = wpfinwgt]

vioplot ln_tpearn, over(educ3) over(black) title(Total Job Earnings for those with Primary SE)
graph export ln_tpearn_annual_by_race_educ_vioplot_100se, as(png)
vioplot ln_tpearn, over(black) over(educ)
graph export ln_tpearn_annual_by_race_educ_vioplot_100se, as(png)

tabstat ln_tpearn, by(gp) stat(mean, sd, median, min, max)

vioplot tpearn, over(educ3) over(black) title(Total Job Earnings for those with Primary SE)
graph export tpearn_annual_by_race_educ_vioplot_100se, as(png)

tabstat tpearn, by(gp) stat(mean, sd, median, min, max)
vioplot tpearn if tpearn <300000, over(educ3) over(black) title(Total Job Earnings for those  with Primary SE) note(filtered to remove upper extremes >300k)
graph export tpearn_annual_by_race_educ_vioplot_100se_rmoutlier, as(png)


/*-----------------------------------------------------------------------------/
Modeling prep 
------------------------------------------------------------------------------*/
use monthly_working, clear

// getting to annual 
collapse (sum) tjb_msum* tpearn tptotinc tjb_prftb (mean) thnetworth tnetworth tdebt_ed thdebt_ed, by(ssuid_spanel_pnum_id spanel swave sex educ3 black pct_months_main_job_self_emp tage age immigrant parent) 
merge 1:1 ssuid_spanel_pnum_id swave using person-year-weights, keep(3)

keep if pct_months_main_job_self_emp ==1  /// looking only at those with some self elf-employment each month  

drop _merge

merge 1:1 ssuid_spanel_pnum_id spanel swave using tbsjval_by_year, keep(1 3)
gen ln_tjb_msum_se = ln(tjb_msum_se)
// gen ln_tjb_msum_ws = ln(tjb_msum_ws)


foreach x in  tjb_prftb tpearn tptotinc thnetworth tnetworth tdebt_ed thdebt_ed {
	egen min_`x' = min(`x')
	replace min_`x' = min_`x' *-1
	gen ln_`x' = ln(`x' + min_`x'+1)
} 

su ln*


/*-----------------------------------------------------------------------------/
Modeling earnings 
------------------------------------------------------------------------------*/

capture log close

log using reg_tpearn_full_self_employed, text replace

xtset ssuid_spanel_pnum_id swave 

asdoc xtreg ln_tpearn i.black i.sex, re vce(robust) , nest replace label 
eststo fs1
//outreg2 using my_reg.doc, replace 

asdoc xtreg ln_tpearn i.black i.sex i.educ3  i.parent i.immigrant tage age2, re vce(robust) , nest label 
eststo fs2
//outreg2 using my_reg.doc, append


asdoc xtreg ln_tpearn i.black ln_thnetworth ln_thdebt_ed i.sex i.educ3  i.parent i.immigrant tage age2, re vce(robust) , nest label 
eststo fs3
//outreg2 using my_reg.doc, append




estout fs*, cells(b(star fmt(3)) se(par fmt(2))) ///
legend label varlabels(_cons constant)           

eststo clear




/*-----------------------------------------------------------------------------/
Modeling business profitability  
------------------------------------------------------------------------------*/
asdoc xtreg ln_tjb_prftb i.black i.sex, re vce(robust), nest reset label 
eststo fs1 

asdoc xtreg ln_tjb_prftb i.black i.sex i.educ3  i.parent i.immigrant tage age2, re vce(robust), nest label 
eststo fs2

asdoc xtreg ln_tjb_prftb i.black ln_thnetworth ln_thdebt_ed i.sex i.educ3  i.parent i.immigrant tage age2, re vce(robust), nest label 
eststo fs3


estout fs*, cells(b(star fmt(3)) se(par fmt(2))) ///
legend label varlabels(_cons constant)           ///
   stats(bic)
eststo clear




/*-----------------------------------------------------------------------------/
Modeling business value  
------------------------------------------------------------------------------*/
asdoc xtreg ln_tbsjval i.black i.sex, re vce(robust), nest reset label
eststo fs1

asdoc xtreg ln_tbsjval i.black i.sex i.educ3  i.parent i.immigrant tage age2, re vce(robust), nest label 
eststo fs2

asdoc xtreg ln_tbsjval i.black ln_thnetworth ln_thdebt_ed i.sex i.educ3  i.parent i.immigrant tage age2, re vce(robust), nest label 
eststo fs3


estout fs*, cells(b(star fmt(3)) se(par fmt(2))) ///
legend label varlabels(_cons constant)           ///
   stats(bic)
eststo clear



xtreg ln_tbsjval i.black ln_thnetworth ln_thdebt_ed i.sex i.educ3  i.parent i.immigrant tage age2, re vce(robust)
ovfplot
