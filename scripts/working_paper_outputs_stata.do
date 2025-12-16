use "person_year.dta", clear 


encode ssuid_spanel_pnum, gen(ssuid_numeric)
* **Set the panel data structure**
xtset ssuid_numeric calyear


**# Unemployed 6 months over first 12 models 
xtreg ln_tpearn_annual i.unemp_f12_6, re
estimates store unemp_m1

xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear, re
estimates store unemp_m2 

* **Model 3: Add 'mode_industry' to Model 2**
xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry, re
estimates store unemp_m3

* **Model 4: Add 'industry_experience' to Model 3*
xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry i.industry_experience, re
estimates store unemp_m4 

* **Model 5: Add interaction between 'industry_experience' and 'unemp_f12_6' to Model 4**
xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry i..industry_experience##i.unemp_f12_6, re
estimates store unemp_m5 

* **Model 6: Remove 'mode_industry' from Model 5**
xtreg ln_tpearn_annual i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.industry_experience##i.unemp_f12_6, re
estimates store unemp_m6

estimates table unemp_m1 unemp_m2 unemp_m3 unemp_m4 unemp_m5 unemp_m6, star






**# Status Models 

xtreg ln_tpearn_annual i.y1_status_v2, re
estimates store status_m1

xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear, re
estimates store status_m2 

* **Model 3: Add 'mode_industry' to Model 2**
xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry, re
estimates store status_m3

* **Model 4: Add 'industry_experience' to Model 3*
xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry i.industry_experience, re
estimates store status_m4 

* **Model 5: Add interaction between 'industry_experience' and 'y1_status_v2' to Model 4**
xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry i..industry_experience##i.y1_status_v2, re
estimates store status_m5 

* **Model 6: Remove 'mode_industry' from Model 5**
xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.industry_experience##i.y1_status_v2, re
estimates store status_m6


estimates table status_m1 status_m2 status_m3 status_m4 status_m5 status_m6, star
