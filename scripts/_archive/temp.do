* Uncomment this large section to recreate datasets that include the ejb_rendb and ejb*rsend which are the reasons that people ended business and ended employment . Additional work needed to account for the fact that the ejb_rendb vars are labled as tjb_rendb vars in 2014w3 and 2014w4. Unclear why that is given their range of values is the same as the ejb. 
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

global jobs1="EJB*_JBORSE EJB*_CLWRK TJB*_EMPB EJB*_INCPB EJB*_JOBID EJB*_STARTWK EJB*_ENDWK EJB*_RSEND TJB*_MWKHRS TJB*_IND TJB*_OCC" // added reason left job
global jobs1_reshape="EJB@_JBORSE EJB@_CLWRK TJB@_EMPB EJB@_INCPB EJB@_JOBID EJB@_STARTWK EJB@_ENDWK EJB@_RSEND TJB@_MWKHRS TJB@_IND TJB@_OCC"
global jobs2="EJB*_TYPPAY1 TJB*_GAMT1 EJB*_BSLRYB *TBSJ*VAL TJB*_PRFTB TBSJ*DEBTVAL TJB*_MSUM EJB*_RENDB" // adding reason end business
global jobs2_reshape="EJB@_TYPPAY1 TJB@_GAMT1 EJB@_BSLRYB TBSJ@VAL TJB@_PRFTB TBSJ@DEBTVAL TJB@_MSUM EJB@_RENDB"

global wealth="TIRAKEOVAL TTHR401VAL TIRAKEOVAL TTHR401VAL TVAL_AST THVAL_AST TNETWORTH THNETWORTH TVAL_HOME THVAL_HOME TEQ_HOME THEQ_HOME TPTOTINC TPEARN TEQ_BUS"
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

global jobs1="ejb*_jborse ejb*_clwrk tjb*_empb ejb*_incpb ejb*_jobid ejb*_startwk ejb*_endwk ejb*_rsend tjb*_mwkhrs tjb*_ind tjb*_occ"
global jobs1_reshape="ejb@_jborse ejb@_clwrk tjb@_empb ejb@_incpb ejb@_jobid ejb@_startwk ejb@_endwk  ejb@_rsend tjb@_mwkhrs tjb@_ind tjb@_occ"
global jobs2="ejb*_typpay1 tjb*_gamt1 ejb*_bslryb *tbsj*val tjb*_prftb tbsj*debtval tjb*_msum ejb*_rendb" 
global jobs2_reshape="ejb@_typpay1 tjb@_gamt1 ejb@_bslryb tbsj@val tjb@_prftb tbsj@debtval tjb@_msum ejb@_rendb"

global wealth="tirakeoval tthr401val tirakeoval tthr401val tval_ast thval_ast tnetworth thnetworth tval_home thval_home teq_home theq_home tptotinc tpearn teq_bus"
global debts="tdebt_ast thdebt_ast toeddebtval theq_home tdebt_cc thdebt_cc tdebt_ed thdebt_ed tdebt_home thdebt_home tdebt_bus"  


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
 -- testing an edited line 


// Combining the various datasets we've reshaped above into one dataset that contains all our years of data and is in long format for job level information
clear
save sipp_reshaped_work_comb, replace emptyok 
foreach num of numlist 1/8 {
	use sipp2014_wv`num'_reshaped_work, clear
	keep if ejb_jobid != .
	append using sipp_reshaped_work_comb
	save sipp_reshaped_work_comb, replace // this dataset contains person-wave-month-job level rows
}

*/
