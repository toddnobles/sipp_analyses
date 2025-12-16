clear all 

use "H:\person_year_earnings_premium.dta"
//net install mdqr, from("https://raw.githubusercontent.com/bmelly/Stata/main/")

encode ssuid_spanel_pnum, gen(num_id)

xtset num_id calyear

* Run the random-effects quantile regression model
xtmdqr ln_tpearn_annual age , re quantiles(0.5) 