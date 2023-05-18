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

log using "./_logs/missing_jobid_investigation_`today'.log", text replace 


/*
* Author: Nobles, Todd
* Email: tnobles@gmail.com
* Date: 2023_05_05
* File: missing_jobid

Examining how prevalent recently discovered issue with missing job_id but positive earnings and workhours is. 
*/

cd "`datapath'"

**# Reading in data

/*------------------------------------------------------------------------------
1. The following section reads in the most recent three datasets and renames all vars
   to lower so that they match the earlier datasets
------------------------------------------------------------------------------

* "pu2019" //wave 2 of 2018 panel  collected in 2019
* "pu2020" //wave 3 of 2018 panel collected in 2020
* "pu2021" //wave 1 of 2021 panel collected in 2021


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
save `x'_lowercase_temp,replace 
}
*/
/*------------------------------------------------------------------------------
2. Now that all datasets are in th same format we set up our macros and create our 
	dataset of unique person-ids
------------------------------------------------------------------------------*/
clear all
macro drop _all
set more off 

local homepath "/Volumes/Extreme SSD/SIPP Data Files/"
local datapath "`homepath'/dtas"

cd "`datapath'"


// these are our downloaded datasets from SIPP (only edit is the final three are modified above to be lowercase var names)

global file1="pu2014w1"
global file2="pu2014w2"
global file3="pu2014w3_13"
global file4="pu2014w4"
global file5="pu2018"
global file6="pu2019_lowercase_temp"
global file7="pu2020_lowercase_temp"
global file8="pu2021_lowercase_temp"

global varbasic_ids="spanel shhadid swave monthcode ssuid pnum wpfinwgt"
global demographics="eeduc tage esex erace ems tceb ebornus eorigin"

global jobs1="ejb*_jborse ejb*_clwrk tjb*_empb ejb*_incpb ejb*_jobid ejb*_startwk ejb*_endwk tjb*_mwkhrs tjb*_ind tjb*_occ"
global jobs2="ejb*_typpay1 tjb*_gamt1 ejb*_bslryb *tbsj*val tjb*_prftb tbsj*debtval tjb*_msum" 
global jobs1_reshape="ejb@_jborse ejb@_clwrk tjb@_empb ejb@_incpb ejb@_jobid ejb@_startwk ejb@_endwk tjb@_mwkhrs tjb@_ind tjb@_occ"
global jobs2_reshape="ejb@_typpay1 tjb@_gamt1 ejb@_bslryb tbsj@val tjb@_prftb tbsj@debtval tjb@_msum"

pause on

foreach num of numlist 1/8 {
	
di "wave `num'"

use $varbasic_ids $jobs1 $jobs2  using ${file`num'}, clear

unique ssuid pnum if (ejb1_jobid == . & ejb2_jobid == . & ejb3_jobid == . & ejb4_jobid == . & ejb5_jobid == . & ejb6_jobid == . & ejb7_jobid == .) ///
       & (tjb1_mwkhrs != . | tjb2_mwkhrs != . |  tjb3_mwkhrs != . | tjb4_mwkhrs != . | tjb5_mwkhrs != . | tjb6_mwkhrs != . | tjb7_mwkhrs != . ) 

merge m:1 ssuid spanel pnum using unique_individuals, keep(1 3)	   
capture drop _merge

// listing examples of thoe who who don't have ejb_jobid but have other info 
di "examples of those who don't have ejb_jobid but have other info"
list ssuid pnum ssuid_spanel monthcode ejb1_jobid ejb2_jobid tjb1_mwkhrs tjb2_mwkhrs tjb1_msum tjb2_msum tage if (ejb1_jobid == . & ejb2_jobid == . & ejb3_jobid == . & ejb4_jobid == . & ejb5_jobid == . & ejb6_jobid == . & ejb7_jobid == .) & (tjb1_mwkhrs != . | tjb2_mwkhrs != . |  tjb3_mwkhrs != . | tjb4_mwkhrs != . | tjb5_mwkhrs != . | tjb6_mwkhrs != . | tjb7_mwkhrs != . ) in 1/500

// summary of tage here in wide format
di "summary of tage here in wide format for those that were missing ejb_jobid but had job data"
codebook tage if (ejb1_jobid == . & ejb2_jobid == . & ejb3_jobid == . & ejb4_jobid == . & ejb5_jobid == . & ejb6_jobid == . & ejb7_jobid == .) & (tjb1_mwkhrs != . | tjb2_mwkhrs != . |  tjb3_mwkhrs != . | tjb4_mwkhrs != . | tjb5_mwkhrs != . | tjb6_mwkhrs != . | tjb7_mwkhrs != . ) 

reshape long $jobs1_reshape $jobs2_reshape, i(ssuid_spanel_pnum_id monthcode) j(job)

// summary of tage here in reshaped form 
di "summary of tage now that we're in long form looking at codebook of age in instances where they're missing ejb_jobid but have other job information "
codebook tage if ejb_jobid ==. & tjb_mwkhrs !=. & tjb_msum != . & ejb_startwk !=. & ejb_endwk !=. & ejb_jborse !=.  

// may not get examples here for every file, given the 1/1500 option 
di "may not get examples here for every file given the 1/1500 filtering"
list ssuid_spanel_pnum_id ssuid pnum monthcode job ejb_jobid ejb_startwk ejb_endwk ejb_jborse tjb_mwkhrs tjb_msum if ///
     ejb_jobid ==. & tjb_mwkhrs !=. & tjb_msum != . & ejb_startwk !=. & ejb_endwk !=. & ejb_jborse !=.  in 1/1500
	 

save sipp2014_wv`num'_reshaped_work_temp, replace //obs here is person-job-month
}



// Combining the various datasets we've reshaped above into one dataset that contains all our years of data and is in long format for job level information
clear
save sipp_reshaped_work_comb_temp, replace emptyok 
foreach num of numlist 1/8 {
	use sipp2014_wv`num'_reshaped_work_temp, clear
	*keep if ejb_jobid != .
	append using sipp_reshaped_work_comb_temp
	save sipp_reshaped_work_comb_temp, replace // this dataset contains person-wave-month-job level rows
}

list ssuid_spanel_pnum_id ssuid pnum spanel swave monthcode job ejb_jobid tjb_mwkhrs tjb_msum ejb_start ejb_end tjb_occ tjb_ind ejb_jborse tjb_prftb tage if ejb_jobid == . & ejb_jborse != . in 1/15000

unique ssuid_spanel_pnum_id if  ejb_jobid ==. & tjb_mwkhrs !=. & tjb_msum != . & ejb_startwk !=. & ejb_endwk !=. & ejb_jborse !=. & tjb_mwkhrs >15

capture log close 




