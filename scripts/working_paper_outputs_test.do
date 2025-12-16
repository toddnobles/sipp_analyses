use "person_year.dta", clear 


encode ssuid_spanel_pnum, gen(ssuid_numeric)
* **Set the panel data structure**
xtset ssuid_numeric calyear

xtreg ln_tpearn_annual i.y1_status_v2, re
estimates store m1

xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear, re
estimates store m2 

* **Model 3: Add 'mode_industry' to Model 2**
xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry, re
estimates store m3

* **Model 4: Add 'industry_experience' to Model 3*
xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry i.industry_experience, re
estimates store m4 

* **Model 5: Add interaction between 'industry_experience' and 'y1_status_v2' to Model 4**
xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.mode_industry i..industry_experience##i.y1_status_v2, re
estimates store m5 

* **Model 6: Remove 'mode_industry' from Model 5**
xtreg ln_tpearn_annual i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct tage age_sq i.sex_fct i.immig_fct i.married i.parent_std i.calyear i.industry_experience##i.y1_status_v2, re
estimates store m6


estimates table m1 m2 m3 m4 m5 m6, star
