log using "suest_test_results.txt", replace text

/* 
This script compares the coefficients between models where we add in the industry experience variable. Here we transferred to Stata from R in the main analysis hoping that suest would take an xtreg model as an input. It turns out that is not the case. Instead we use the suest command on similarly specified linear models and specify the clustering. The input file to begin the script here is output in the 3_working_paper_outputs.qmd script partway through. 
*/


use "/Users/toddnobles/Documents/sipp_analyses/R checks/person_year.dta",  clear

gen age_sq = tage^2,

encode ssuid_spanel_pnum, gen(ssuid_numeric)




**# Linear model approach 
// 1. Run Model 3 using regress 
regress ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear 
estimates store unemp_m3_reg

// 2. Run Model 4 using regress
regress ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear  i.industry_experience
estimates store unemp_m4_reg

// 3. Combine estimation results 
suest unemp_m3_reg unemp_m4_reg, cluster(ssuid_numeric)

// 4. Test equality of the unemployment coefficient 
test [unemp_m3_reg_mean]2.unemp_f12_6 = [unemp_m4_reg_mean]2.unemp_f12_6

/* Close the log */
log close

**# Other options

****************************************************************************
// Saving this here for record keeping, but this does not run as we'd hoped with the suest command on panel models.
/*

* **Set the panel data structure**
xtset ssuid_numeric calyear



xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd  i.educ_fct  tage  age_sq i.sex_fct  i.immig_fct i.married i.parent_std i.calyear , re
estimates store unemp_m3
	
xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd  i.educ_fct  tage  age_sq i.sex_fct  i.immig_fct i.married i.parent_std i.calyear  i.industry_experience, re
estimates store unemp_m4



/***
// Doesn't run because suest doesn't work for xtreg models 
//Combine the models using suest
suest unemp_m3 unemp_m4 

// Test whether the coefficients are different
test [m2_mean]Long_term_unemployed = [m3_mean]Long_term_unemployed
*/
*/


/*
****************************************************************************
// XTSUR is an option others mention online.



****************************************************************************
https://friosavila.github.io/chatgpt/suregfe_07_14_2023/ 




****************************************************************************
https://www.statalist.org/forums/forum/general-stata-discussion/general/1428299-alternative-to-suest-to-work-with-xtreg
// psuedocode for the reshape interaction model approach 

reshape long y, i(county time) j(subscript)
xtreg y i.subscript##(i.post##i.treat i.time), re
[code]
The test of beta1 = beta2 is then based on the coefficient of 2.subscript#1.post#1.treat.
*/

