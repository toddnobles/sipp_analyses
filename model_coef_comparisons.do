// comparing coeffs between two panel models using suest command since no equivalent is available in R for our panel models

use "/Users/toddnobles/Documents/sipp_analyses/R checks/person_year.dta",  clear


gen age_sq = tage^2,


//industry_numeric = as.numeric(mode_industry)


encode ssuid_spanel_pnum, gen(ssuid_numeric)
* **Set the panel data structure**
xtset ssuid_numeric calyear



xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd  i.educ_fct  tage  age_sq i.sex_fct  i.immig_fct i.married i.parent_std i.calyear mode_industry, re
estimates store unemp_m3
	
xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd  i.educ_fct  tage  age_sq i.sex_fct  i.immig_fct i.married i.parent_std i.calyear mode_industry i.industry_experience, re
estimates store unemp_m4



/***
// Doesn't run because suest doesn't work for xtreg models 
//Combine the models using suest
suest unemp_m3 unemp_m4 

// Test whether the coefficients are different
test [m2_mean]Long_term_unemployed = [m3_mean]Long_term_unemployed
*/


// 1. Run Model 3 using regress with clustering 
regress ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear mode_industry
estimates store unemp_m3_reg

// 2. Run Model 4 using regress with clustering 
regress ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear mode_industry i.industry_experience
estimates store unemp_m4_reg

// 3. Combine estimation results 
suest unemp_m3_reg unemp_m4_reg, cluster(ssuid_numeric)

// 4. Test equality of the unemployment coefficient 
test [unemp_m3_reg_mean]2.unemp_f12_6 = [unemp_m4_reg_mean]2.unemp_f12_6




// psuedocode for the reshape interaction model approach 
/*
reshape long y, i(county time) j(subscript)
xtreg y i.subscript##(i.post##i.treat i.time), re
[code]
The test of beta1 = beta2 is then based on the coefficient of 2.subscript#1.post#1.treat.
*/
