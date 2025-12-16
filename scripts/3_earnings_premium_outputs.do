/* 
This script produces the outputs for the earnings premium models using the wage and salary sample created in 2_earnings_premium_data_prep.qmd script
*/


/*
DV Variable: Earning (continuous)
Controls: 
Gender, race/ethnicity, industry, education, age, age-squared, immigrant status, parental status, marital status
Sample: (Former SE and W&S workers sample)
*/
local today: display %tdCCYYNNDD date(c(current_date), "DMY")
display `today'

use "/Users/toddnobles/Documents/sipp_analyses/R checks/ws_sample_cleanest.dta", clear 

**# Encode ssuid_spanel_pnum 
encode (ssuid_spanel_pnum), gen(id_num)

**# Filter to remove those with y1_status_v2 == 4
drop if y1_status_v2 == 4

**# make new variable for y1_status with appropriate labels 
gen formerly_se = 1 if y1_status_v2 == 2
replace formerly_se = 0 if y1_status_v2 == 1 

gen married = 1 if ems == 1 | ems == 2
replace married = 2 if ems == 3 | ems == 4 | ems == 5
replace married = 3 if ems == 6
label define married_l 1 "Married" 2 "Divorced/Separated/Widowed" 3 "Never Married"
label values married married_l


gen age_sq = tage^2

/* Other controls 
	- race = race_eth_fct_cpsd
	- sex = sex_fct 
	- industry = industry_fct
	- education = educ_fct 
	- age = tage 
	- age_sq = age_sq
	- immigrant = immig_fct 
	- parent = parent_std
	- married = married 
*/

**# collapse to annual 

collapse (first) formerly_se tage age_sq race_eth_fct_cpsd industry_fct educ_fct immig_fct parent_std married sex_fct (sum) tpearn msum tptotinc, by(id_num calyear)

foreach v of varlist tpearn msum tptotinc {
	gen `v'_adj = .
	replace `v'_adj = `v' * 304.7/233.0 if calyear == 2013
	replace `v'_adj = `v' * 304.7/236.7 if calyear == 2014
	replace `v'_adj = `v' * 304.7/237.0 if calyear == 2015
	replace `v'_adj = `v' * 304.7/240.0 if calyear == 2016
	replace `v'_adj = `v' * 304.7/251.1 if calyear == 2018
	replace `v'_adj = `v' * 304.7/255.7 if calyear == 2019
	replace `v'_adj = `v' * 304.7/258.8 if calyear == 2020
	replace `v'_adj = `v' * 304.7/271.0 if calyear == 2021
	replace `v'_adj = `v' * 304.7/292.8 if calyear == 2022
	replace `v'_adj = `v' if calyear == 2023
}




egen min_tpearn_adj = min(tpearn_adj)
gen ln_tpearn_adj = ln(-1*min_tpearn_adj + 1 + tpearn_adj)



rename race_eth_fct_cpsd race


encode industry_fct, generate(industry_fct_numeric)

**# Set some value labels for clarity in the tables 
label define status_l 0 "Wage & Salary" 1 "Fomerly SE"
label define race_l 1 "White" 2 "Non-white"
label define immig_l 1 "US Born" 2 "Immigrant"
label define educ_l 1 "HS or less" 2 "Some College or Assoc" 3 "4-year Degree or More"
label define parent_l 0 "Not Parent" 1 "Parent"
label define sex_l 1 "Male" 2 "Female"

label values formerly_se status_l
label values race race_l
label values immig_fct immig_l
label values educ_fct educ_l
label values parent_std parent_l
label values married married_l
label values sex_fct sex_l 

label variable formerly_se "Formerly SE"
label variable race "Race"
label variable immig_fct "Immigrant"
label variable educ_fct "Education"
label variable parent "Parent"
label variable tage "Age"
label variable age_sq "Age Squared"
label variable married "Marital Status"
label variable industry_fct_numeric "Industry"



// Table 1 
label variable tpearn_adj "Earnings: TPEARN"
label variable msum_adj "Earnings: MSUM"
label variable tptotinc_adj "Earnings: TPTOTINC"
label variable sex_fct "Sex"

dtable tpearn_adj msum_adj tptotinc_adj tage i.race i.sex_fct i.married i.parent_std i.immig_fct, by(formerly_se, tests) sample(, statistics(freq) place(seplabels)) sformat("(N=%s)" frequency) column(by(hide)) nformat(%9.0f mean sd) 
collect export earnings_premium_`today'.xlsx, name(DTable) sheet("Table 1 Descriptives with tests", replace ) modify


// Table of median earnings

table (formerly_se), statistic(p25 tpearn_adj) statistic(p50 tpearn_adj) statistic(p75 tpearn_adj)
collect export earnings_premium_`today'.xlsx, name(Table) sheet("Median Earnings", replace ) modify 


// Table of variables to add descriptions to
dtable tpearn_adj msum_adj tptotinc_adj tage i.race i.sex_fct i.married i.parent_std i.immig_fct, sample(, statistics(freq) place(seplabels)) sformat("(N=%s)" frequency) nformat(%9.0f mean sd) 
collect export earnings_premium_`today'.xlsx, name(DTable) sheet("Variable Descriptions", replace ) modify


// Table 1 with percentile earnings 
dtable tpearn_adj msum_adj tptotinc_adj tage i.race i.sex_fct i.married i.parent_std i.immig_fct, ///
    sample(, statistics(frequency) place(seplabels)) ///
    continuous(tpearn_adj msum_adj tptotinc_adj tage, statistics(mean sd p25 p50 p75)) ///
    nformat(%9.0f mean sd p25 p50 p75) 
	
collect export earnings_premium_`today'.xlsx, name(DTable) sheet("Table 1 Descriptives pctiles", replace) modify



// Table 2: Descriptives for 'formerly_se' and 'race'
collect clear
table (formerly_se) (race), statistic(mean tpearn_adj)
 
collect clear
collect create race_desc
collect r(N_1) r(mu_1) r(N_2) r(mu_2) r(p) r(mu_diff) r(mu_combined): by formerly_se, sort : ttest tpearn_adj, by(race)
collect layout (formerly_se) (result)
collect remap result[N_1 mu_1] = White
collect remap result[N_2 mu_2] = Nonwhite
collect remap result[mu_diff p] = Difference
collect remap result[mu_combined] = Overall
collect style header White Nonwhite Difference Overall, title(name)
collect layout (formerly_se) (White Nonwhite Difference Overall_mean)
collect label levels White N_1 "N" mu_1 "Mean Earnings"
collect label levels Nonwhite N_2 "N" mu_2 "Mean Earnings"
collect label levels Difference p "p-value" mu_diff "Difference"
collect label levels Overall mu_combined "Overall Mean"
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect style cell White[mu_1] Nonwhite[mu_2] Difference[mu_diff], nformat(%5.0f)
collect style cell border_block, border(right, pattern(nil))
collect style cell cell_type[column-header]#White cell_type[column-header]#Nonwhite, border(bottom, pattern(single))
collect preview

collect export earnings_premium_`today'.xlsx, name(race_desc) sheet("Earnings Descriptives") modify cell(A7)


// Table 3: Descriptives for 'formerly_se' and 'sex_fct'
collect clear
collect create sex_desc
collect r(N_1) r(mu_1) r(N_2) r(mu_2) r(p) r(mu_diff) r(mu_combined): by formerly_se, sort : ttest tpearn_adj, by(sex_fct)
collect layout (formerly_se) (result)
collect remap result[N_1 mu_1] = Male
collect remap result[N_2 mu_2] = Female
collect remap result[mu_diff p] = Difference
collect remap result[mu_combined] = Overall
collect style header Male Female Difference Overall, title(name)
collect layout (formerly_se) (Male Female Difference Overall_mean)
collect label levels Male N_1 "N" mu_1 "Mean Earnings"
collect label levels Female N_2 "N" mu_2 "Mean Earnings"
collect label levels Difference p "p-value" mu_diff "Difference"
collect label levels Overall mu_combined "Overall Mean"
collect style column, dups(center) width(equal)
collect style cell, halign(center)
collect style cell Male[mu_1] Female[mu_2] Difference[mu_diff], nformat(%5.0f)
collect style cell border_block, border(right, pattern(nil))
collect style cell cell_type[column-header]#Male cell_type[column-header]#Female, border(bottom, pattern(single))
collect preview

collect export earnings_premium_`today'.xlsx, name(sex_desc) sheet("Earnings Descriptives") modify cell(A18)







local controls "tage age_sq i.immig_fct i.educ_fct i.parent_std i.married i.industry_fct_numeric"





**# Non-robust se OLS
reg ln_tpearn_adj i.formerly_se 
estimates store ols_0

reg ln_tpearn_adj i.formerly_se i.race i.sex_fct 
estimates store ols_1

reg ln_tpearn_adj i.formerly_se i.race i.sex_fct `controls'
estimates store ols_2

reg ln_tpearn_adj i.formerly_se##i.race i.sex_fct `controls'
estimates store ols_3

reg ln_tpearn_adj i.formerly_se##i.sex_fct  i.race `controls'
estimates store ols_4

**# Robust SE OLS
reg ln_tpearn_adj i.formerly_se
estimates store robust_0

reg ln_tpearn_adj i.formerly_se i.race i.sex_fct , robust
estimates store robust_1

reg ln_tpearn_adj i.formerly_se i.race i.sex_fct `controls', robust
estimates store robust_2

reg ln_tpearn_adj i.formerly_se##i.race i.sex_fct `controls', robust
estimates store robust_3

reg ln_tpearn_adj i.formerly_se##i.sex_fct  i.race `controls', robust
estimates store robust_4


**#  Quantile regression models
// 25th percentile
qreg ln_tpearn_adj i.formerly_se i.race i.sex_fct `controls', quantile(.25)  
estimates store qreg_25

qreg ln_tpearn_adj i.formerly_se##i.race i.sex_fct `controls', quantile(.25) 
estimates store qreg_int_25

qreg ln_tpearn_adj i.formerly_se##i.sex_fct i.race `controls', quantile(.25)
estimates store qreg_int_sex_25

//50th percentile, median
qreg ln_tpearn_adj i.formerly_se i.race i.sex_fct `controls', quantile(.5) 
estimates store qreg_50

qreg ln_tpearn_adj i.formerly_se##i.race i.sex_fct `controls', quantile(.5)
estimates store qreg_int_50

qreg ln_tpearn_adj i.formerly_se##i.sex_fct i.race `controls', quantile(.5)
estimates store qreg_int_sex_50

// 75th percentile
qreg ln_tpearn_adj i.formerly_se i.race i.sex_fct `controls', quantile(.75)  
estimates store qreg_75

qreg ln_tpearn_adj i.formerly_se##i.race i.sex_fct `controls', quantile(.75)  
estimates store qreg_int_75

qreg ln_tpearn_adj i.formerly_se##i.sex_fct i.race `controls', quantile(.75)
estimates store qreg_int_sex_75



**# Model tables 

// Exporting OLS regressions
etable, estimates(ols*) title(OLS regressions) showstars showstarsnote  column(estimates) varlabel export("earnings_premium_`today'.xlsx", replace sheet("OLS")) 


// Exporting Robust SE regressions
etable, estimates(robust*) title(Robust SE) showstars showstarsnote column(estimates) varlabel export("earnings_premium_`today'.xlsx", modify sheet("Robust SE")) 

// Exporting Quantile regressions
etable, estimates(qreg_25 qreg_50 qreg_75) title(Quantile Regressions) showstars showstarsnote column(estimates) varlabel export("earnings_premium_`today'.xlsx", modify sheet("Quantile"))

// Exporting Quantile with Interactions
etable, estimates(qreg_int*) title(Quantile Regressions with Interactions) showstars showstarsnote column(estimates) varlabel export("earnings_premium_`today'.xlsx", modify sheet("Quantile_Int"))



