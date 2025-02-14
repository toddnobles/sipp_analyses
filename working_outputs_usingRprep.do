
cd "/Users/toddnobles/Documents/sipp_analyses/"
set linesize 255
local logdate : di %tdCYND daily("$S_DATE", "DMY")
capture log close
log using working_outputs_usingRprep_`logdate'.log, text replace

**# Data import
/// This reads in the person_year data that removed those with illogical earnings/hours values and includes those who were Self-employed at least 50% of the months from month 13 onwards. 

use "person_year_se_clean5.dta", clear  

list in 1/5

**# Cleaning up demographic variables 
egen new_id = group(ssuid_spanel_pnum)
gen age = tage
gen age2=age^2
label variable age2 "Age squared"
label variable age "Age"
label variable profposi "Positive Profit"
label variable prof10k	"Profit >=10k"


global controls  = "age age2 i.immig_fct i.industry_fct i.calyear"


**# weighted unemp models 
// none of these actually converge with weights included. (unclear why)
mixed ln_tpearn i.unemp_f12_6 i.educ_fct $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)
eststo wt_se_earn_unemp_m1

mixed ln_tpearn i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct i.sex $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id) 
eststo wt_se_earn_unemp_m2

mixed ln_tpearn unemp_f12_6##race_eth_fct_cpsd i.educ_fct i.sex $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id) 
eststo wt_se_earn_unemp_m3

mixed ln_tpearn unemp_f12_6##sex_fct i.race_eth_fct_cpsd i.educ_fct $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id) 
eststo wt_se_earn_unemp_m4

**# non-weighted earnings ~ unemp models 
mixed ln_tpearn i.unemp_f12_6 i.educ_fct $controls || new_id:, iterate(15) vce(cluster new_id) 
eststo se_earn_unemp_m1

mixed ln_tpearn i.unemp_f12_6 i.race_eth_fct_cpsd i.educ_fct i.sex $controls  || new_id:, iterate(15) vce(cluster new_id) 
eststo se_earn_unemp_m2

mixed ln_tpearn unemp_f12_6##race_eth_fct_cpsd i.educ_fct i.sex $controls  || new_id:, iterate(15) vce(cluster new_id) 
eststo se_earn_unemp_m3

mixed ln_tpearn unemp_f12_6##sex_fct i.race_eth_fct_cpsd i.educ_fct $controls || new_id:, iterate(15) vce(cluster new_id) 
eststo se_earn_unemp_m4




**# Weighted earnings ~ status models 
mixed ln_tpearn i.y1_status_v2 i.educ_fct $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)
eststo wt_se_earn_mode_m1 

mixed ln_tpearn i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct  i.sex $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)  
eststo wt_se_earn_mode_m2

mixed ln_tpearn y1_status_v2##race_eth_fct_cpsd i.educ_fct i.sex $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id) 
eststo wt_se_earn_mode_m3

mixed ln_tpearn y1_status_v2##sex i.race_eth_fct_cpsd i.educ_fct  $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)
eststo wt_se_earn_mode_m4


**# non-weighted earnings ~ status models 
mixed ln_tpearn i.y1_status_v2 i.educ_fct $controls  || new_id:, iterate(15) vce(cluster new_id)
eststo se_earn_mode_m1 
mixed ln_tpearn i.y1_status_v2 i.race_eth_fct_cpsd i.educ_fct  i.sex $controls  || new_id:, iterate(15) vce(cluster new_id)  
eststo se_earn_mode_m2
mixed ln_tpearn y1_status_v2##race_eth_fct_cpsd i.educ_fct i.sex $controls  || new_id:, iterate(15) vce(cluster new_id) 
eststo se_earn_mode_m3
mixed ln_tpearn y1_status_v2##sex i.race_eth_fct_cpsd i.educ_fct  $controls  || new_id:, iterate(15) vce(cluster new_id)
eststo se_earn_mode_m4




**# Tables of the above unweighted models that actually converge 
esttab se_earn_unemp??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 3: Relationship between Unemployment and Log Annual Earnings (Self-Employed Sample)) ///
	varlabels(_cons Constant)   ///
	nonumbers mtitles("Self-Employed Sample" "" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell replace  
	
	
esttab se_earn_mode??? using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 4: Relationship between Initial Employment Status and Log Annual Earnings (Self-Employed Sample)) ///
	varlabels(_cons Constant)   ///
	nonumbers mtitles("Self-Employed Sample" "" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append 
	
	
**# Logistic regressions positive and 10k profit 
foreach y of varlist profposi prof10k   {
	foreach x of varlist unempf12_6 y1_status_v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"
		
		// weighted logits 
		melogit `y' i.`x' i.educ_collapsed $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id) 
		eststo wt_`y'_`xname'_1re

	    melogit `y' i.`x' i.educ_collapsed i.race_collapsed i.sex $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)  
		eststo wt_`y'_`xname'_2re
		
		melogit `y' `x'##race_collapsed i.educ_collapsed i.sex $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id) 
		eststo wt_`y'_`xname'_3re
		
		melogit `y' `x'##sex i.race_collapsed i.educ_collapsed $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)  
		eststo wt_`y'_`xname'_4re
		
		
		//unweighted logits 
		melogit `y' i.`x' i.educ_collapsed $controls  || new_id:, iterate(15) vce(cluster new_id) 
		eststo `y'_`xname'_1re

	    melogit `y' i.`x' i.educ_collapsed i.race_collapsed i.sex $controls || new_id:, iterate(15) vce(cluster new_id)  
		eststo `y'_`xname'_2re
		
		melogit `y' `x'##race_collapsed i.educ_collapsed i.sex $controls  || new_id:, iterate(15) vce(cluster new_id) 
		eststo `y'_`xname'_3re
		
		melogit `y' `x'##sex i.race_collapsed i.educ_collapsed $controls  || new_id:, iterate(15) vce(cluster new_id)  
		eststo `y'_`xname'_4re


		}
}


**# Logged Profit models, not included here 
/**foreach y of varlist ln_tjb_prftb  {
	foreach x of varlist unempf12_6 y1_status_v2  {
		
		local xname = substr("`x'",1,5)
		di "`y'_`xname'"

		
		mixed `y' i.`x' i.educ_fct $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)
		eststo `y'_`xname'_1re
		mixed `y' i.`x' i.race_eth_fct_cpsd i.educ_fct  i.sex $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)  
		eststo `y'_`xname'_2re
		mixed `y' `x'##race_eth_fct_cpsd i.educ_fct i.sex $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id) 
		eststo `y'_`xname'_3re
		mixed `y' `x'##sex i.race_eth_fct_cpsd i.educ_fct  $controls [pweight = wpfinwgt] || new_id:, iterate(15) vce(cluster new_id)
		eststo `y'_`xname'_4re

		
	}
}
**/


**# Table 5 Logistic Regressions Profit on Unemployment
*------------------------------------------------------------------------------|
esttab prof*unemp* using working_paper_outputs_`logdate'.rtf, ///
	legend label ///
	title(Table 5. Logistic Regressions Profit on Unemployment) ///
	varlabels(_cons Constant)   ///
	mtitles("Positive Profit" "" "" "" "Profit >= 10k"  "" ""	"") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  
	

**# Table 6 Logistic Regressions of Profit on Initial Employment Status
*------------------------------------------------------------------------------|
esttab prof*y1* using working_paper_outputs_`logdate'.rtf, ///
	legend label  ///
	title(Table 6. Logistic Regressions Profit on Initial Employment Status) ///
	varlabels(_cons Constant) ///
	mtitles("Positive Profit" "" "" "" "Profit >= 10k" "" "" "") ///
	addnote("t statistics in parentheses. * p < 0.05, ** p < 0.01, *** p < 0.001") ///
	compress onecell append  

	

log close 
	




