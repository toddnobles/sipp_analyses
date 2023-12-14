
/*
frame change month_job_level

collapse (sum) tjb_msum tjb_prftb (mean) tjb_mwkhrs pct_months_main_job_self_emp, ///
			by(ssuid_spanel_pnum_id spanel swave monthcode ejb_jborse wpfinwgt)
recode ejb_jborse (2=1 "self-employed") (nonmiss=0 "wage&salary"), into(selfemp)
*recode jb_main (1=1 "main") (0=0 "secondary"), into(primary_job)
drop ejb_jborse

save sipp_reshaped_work_comb_collapsed, replace //obs here is person-jobtype-month
*/



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
