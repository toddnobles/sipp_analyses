capture log close

clear all
set more off
set trace off
pause on
macro drop _all
set linesize 200

local homepath "/Users/toddnobles/Documents/SIPP Data Files/"
local datapath "`homepath'/dtas"

cd "`homepath'"


local c_time = c(current_time)
local today : display %tdCYND date(c(current_date), "DMY")

log using ".\_logs\prelim_`today'.log", text replace 


/*
* Author: Nobles, Todd
* Email: tnobles@gmail.com
* Date: 2023_03_06

* This uses the datasets output by _sipp2014_data_prep.do

*/

cd "`datapath'"

* Earnings distribtuion for self employed and  wage-salary workers 

use sipp2014to2021_wealthdebt, clear

cd "`homepath'"

//Descriptive statistics
drop if ejb_jborse==3
recode ejb_jborse (2=1 "self-employed") (nonmiss=0 "wage&salary"), into(selfemp)
tab selfemp, missing

codebook esex
recode esex (1=0 Male) (2=1 Female),gen(sex) 
codebook sex

//working with the black-white sample
//keep if idwave==1
keep if erace==1|erace==2 //this keeps the black and white sample only.
codebook erace

codebook eeduc 
tab eeduc 

label define educ_label 31 "Less than 1st grade" ///
32 "1st, 2nd, 3rd or 4th grade" ///
33 "5th or 6th grade" ///
34 "7th or 8th grade" ///
35 "9th grade" ///
36 "10th grade" ///
37 "11th grade" ///
38 "12th grade, no diploma" ///
39 "High School Graduate (diploma or GED or equivalent)" ///
40 "Some college credit, but less than 1 year (regular Jr.coll./coll./univ.)" ///
41 "1 or more years of college, no degree (regular Jr.coll./coll./univ.)" ///
42 "Associate's degree (2-year college)" ///
43 "Bachelor's degree (for example: BA, AB, BS)" ///
44 "Master's degree (for example: MA, MS, MBA, MSW)" ///
45 "Professional School degree (for example: MD (doctor), DDS (dentist), JD (lawyer))" ///
46 "Doctorate degree (for example: Ph.D., Ed.D.)" 
label values eeduc educ_label

recode eeduc (31/38=1 "Less than high school") ///
(39=2 "High school diploma or GED") ///
(40/41=3 "Some College") ///
(42=4 "Associate's degree (2-year college)") ///
(43=5 "College degree") ///
(44/46=6 "Graduate school degree"), gen(educ)
tab educ

recode educ (1/2=1 "High school or less") (nonmiss=0 "More than high school"), into(hsorles)
recode educ (3/4=1 "Some college or associate") (nonmiss=0 "allother"), into(somcolorasso)
recode educ (5=1 "College degree") (nonmiss=0 "allother"), into(college)
recode educ (6=1 "Graduate degree") (nonmiss=0 "allother"), into(graddeg)

codebook hsorles somcolorasso college graddeg
gen educ3=.
codebook educ3
replace educ3=1 if  hsorles==1
tab educ3 hsorles,missing

replace educ3=2 if somcolorasso==1
tab educ3 somcolorasso,missing

replace educ3=3 if college==1
tab educ3 college,missing

replace educ3=4 if graddeg==1
tab educ3 graddeg,missing

label define educ3_label 1"hsorles" 2"somcolorasso" 3"college" 4"graddeg"
label list educ3_label
label values educ3 educ3_label
codebook educ3

codebook hsorles somcolorasso college graddeg
codebook hsorles somcolorasso college graddeg,compact

sort id2 swave tpearn

// at this point in the file we have one row for each person/year combo (pending issue with shhadid)
// so no need to sum here we can just use each 
capture log close
log using earning_distribution_for_se&ws, text replace

//Earnings by education level and race and  WS and SE
/*
foreach x of varlist tptotinc tpearn {
    
tabstat `x', by(educ3) stat(n mean, sd, min max) //WS&SE
tabstat `x' if selfemp==0, by(educ3) stat(n mean, sd, min max) //WS
tabstat `x' if selfemp==1, by(educ3) stat(n mean, sd, min max) //SE

tabstat `x' if black==1, by(educ3) stat(n mean, sd, min max) //WS&SE, Black
tabstat `x' if black==0, by(educ3) stat(n mean, sd, min max) //WS&SE, White

tabstat `x' if black==1&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, black
tabstat `x' if black==0&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, White

tabstat `x' if black==1&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, black
tabstat `x' if black==0&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, white
}
*/

//sumearn, yearly earings
tabstat sumearn, by(educ3) stat(n mean, sd, min max) //WS&SE
tabstat sumearn if selfemp==0, by(educ3) stat(n mean, sd, min max) //WS
tabstat sumearn if selfemp==1, by(educ3) stat(n mean, sd, min max) //SE

tabstat sumearn if black==1, by(educ3) stat(n mean, sd, min max) //WS&SE, Black
tabstat sumearn if black==0, by(educ3) stat(n mean, sd, min max) //WS&SE, White

tabstat sumearn if black==1&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, black
tabstat sumearn if black==0&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, White

tabstat sumearn if black==1&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, black
tabstat sumearn if black==0&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, white


tabstat sumearn if black==1&selfemp==0, stat(n mean, median, sd, min max) //WS, black
tabstat sumearn if black==0&selfemp==0, stat(n mean, median, sd, min max) //WS, white

tabstat sumearn if black==1&selfemp==1, stat(n mean, median, sd, min max) //SE, black
tabstat sumearn if black==0&selfemp==1, stat(n mean, median, sd, min max) //SE, white

tabstat sumearn, stat(n mean, median, sd, min max) //WS&SE, Black+White
tabstat sumearn if selfemp==0, by(black) stat(n mean, median, sd, min max) //WS, by black and white
tabstat sumearn if selfemp==1, by(black) stat(n mean, median, sd, min max) //SE, by black and white


//Historgrams
gen lsumearn=ln(sumearn)
histogram sumearn, normal
histogram sumearn, percent bin(10) normal
histogram sumearn, fraction bin(10) normal
histogram sumearn, by(black) fraction bin(20) normal


histogram lsumearn, normal
histogram lsumearn, percent bin(10) normal
histogram lsumearn, fraction bin(10) normal
histogram lsumearn, by(black) fraction bin(50) normal
histogram lsumearn, by(black) fraction normal
histogram lsumearn, by(black) percent normal

histogram lsumearn if selfemp==0, by(black) percent normal
histogram lsumearn if selfemp==1, by(black) percent normal

histogram lsumearn if selfemp==1, by(black) bin(150) percent normal










/*
//tptotinc tjb_gamt1
tabstat tptotinc, by(educ3) stat(n mean, sd, min max) //WS&SE
tabstat tptotinc if selfemp==0, by(educ3) stat(n mean, sd, min max) //WS
tabstat tptotinc if selfemp==1, by(educ3) stat(n mean, sd, min max) //SE

tabstat tptotinc if black==1, by(educ3) stat(n mean, sd, min max) //WS&SE, Black
tabstat tptotinc if black==0, by(educ3) stat(n mean, sd, min max) //WS&SE, White

tabstat tptotinc if black==1&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, black
tabstat tptotinc if black==0&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, White

tabstat tptotinc if black==1&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, black
tabstat tptotinc if black==0&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, white

//tpearn
tabstat tpearn, by(educ3) stat(n mean, sd, min max) //WS&SE
tabstat tpearn if selfemp==0, by(educ3) stat(n mean, sd, min max) //WS
tabstat tpearn if selfemp==1, by(educ3) stat(n mean, sd, min max) //SE

tabstat tpearn if black==1, by(educ3) stat(n mean, sd, min max) //WS&SE, Black
tabstat tpearn if black==0, by(educ3) stat(n mean, sd, min max) //WS&SE, White

tabstat tpearn if black==1&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, black
tabstat tpearn if black==0&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, White

tabstat tpearn if black==1&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, black
tabstat tpearn if black==0&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, white



//tjb_msum
tabstat tjb_msum, by(educ3) stat(n mean, sd, min max) //WS&SE
tabstat tjb_msum if selfemp==0, by(educ3) stat(n mean, sd, min max) //WS
tabstat tjb_msum if selfemp==1, by(educ3) stat(n mean, sd, min max) //SE

tabstat tjb_msum if black==1, by(educ3) stat(n mean, sd, min max) //WS&SE, Black
tabstat tjb_msum if black==0, by(educ3) stat(n mean, sd, min max) //WS&SE, White

tabstat tjb_msum if black==1&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, black
tabstat tjb_msum if black==0&selfemp==0, by(educ3) stat(n mean, sd, min max) //WS, White

tabstat tjb_msum if black==1&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, black
tabstat tjb_msum if black==0&selfemp==1, by(educ3) stat(n mean, sd, min max) //SE, white







