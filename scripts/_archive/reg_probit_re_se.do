
clear all

set linesize 200
macro drop _all
set more off

//Working with the work, wealth and debt data
use sipp2014to2021_wealthdebt, clear

egen id3=group(ssuid shhadid pnum)

/*
sort id2 swave 

list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==2
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==3
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==5
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==7|id2==8|id2==9
*/
codebook erace
tab erace

/*
list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse id in 1/50
list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse if id==1 in 1/500
*/

//Descriptive statistics
drop if ejb_jborse==3
recode ejb_jborse (2=1 "self-employed") (nonmiss=0 "wage&salary"), into(selfemp)
tab selfemp, missing

gen age2=age^2

recode ebornus (1=0 "was born in the US") (2=1 "was not born in the US"), gen(immigrant)
tab immigrant
tab ebornus

tab ems
rename ems mari_status

recode tceb (1/7=1 "Have a child or more") (0=0 "Have no children"), gen(parent)
tab tceb
tab parent

codebook tjb_ind
table tjb_ind
destring tjb_ind, generate(industry1)
des tjb_ind industry1

recode industry1 (0010/0560=1  "Agriculture, Forestry, Fishing and Hunting, and Mining") ///
(0770/1060=2  Construction) ///
(1070/4060=3 Manufacturing) ///
(4070/4660=4  "Wholesale Trade") ///
(4670/6060=5  "Retail Trade") ///
(6070/6460 0570/0760=6 "Transportation and Warehousing, and Utilities") ///
(6470/6860=7  Information) ///
(6870/7260=8  "Finance and Insurance,  and Real Estate and Rental and Leasing") ///
(7270/7790=9  "Professional, Scientific, and Management, and  Administrative and Waste Management Services") ///
(7860/8490=10  "Educational Services, and Health Care and Social Assistance") ///
(8560/8690=11  "Arts, Entertainment, and Recreation, and  Accommodation and Food Services") ///
(8770/9290=12  "Other Services (except Public Administration)") ///
(9370/9590=13  "Public Administration") ///
(9890=15 Military), gen(industry2)

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

recode educ (5/6=1 "College & Grad") (nonmiss=0 "allother"), into(cg)
tab cg

codebook hsorles somcolorasso college graddeg cg
codebook hsorles somcolorasso college graddeg cg,compact

codebook esex
recode esex (1=0 Male) (2=1 Female),gen(sex) 
codebook sex

//working with the black-white sample
//label define erace2 1"White only" 2"Black only" 3"Asian only" 4"other/Residual"
//label values erace erace2
codebook erace
tab erace

keep if erace==1|erace==2 //this keeps the black and white sample only.
codebook erace
tab erace
tab erace,missing

recode erace (2=1 Black) (nonmiss=0 White), into(black)
tab black
codebook black

//global assets="tval_ast thval_ast tnetworth thnetworth tirakeoval tthr401val tval_home thval_home teq_home theq_home" 
//global debt2=" tdebt_ast thdebt_ast tbsjdebtval tdebt_cc thdebt_cc toeddebtval tdebt_ed thdebt_ed tdebt_home thdebt_home"

//global profdebt="tbsjval tjb_prftb toeddebtval tdebt_ed thdebt_ed"
global educ="somcolorasso college graddeg"
global educ2="hsorles somcolorasso college graddeg"
global educ3="hsorles somcolorasso college cg"
global educ4="hsorles college graddeg"
global educ5="hsorles college"

//global educ="somcoll asdeg college graddeg"
//global educ="hs somcoll asdeg college graddeg"
//global educ="nohs hs somcoll asdeg college graddeg"
//global control="sex age mari_status ebornus tceb"
//global controls="sex age age2"
global controls="sex age age2 mari_status immigrant parent industry2"
global controls2="sex age age2 mari_status immigrant parent"
global educdebt="tdebt_ed thdebt_ed"
//global educdebt="toeddebtval tdebt_ed thdebt_ed"


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


sort id3 swave 
qby id3 swave: egen sumearn= total(tjb_msum)

codebook hsorles somcolorasso college graddeg sumearn,compact

sort id3 swave 
qby id3: egen numwave=total(idwave) //number of wave per id2 (person)

keep if numwave>1 //keeping only id2 with two waves or more.
sum tdebt_ed thnetworth tnetworth

gen log_thnetworth=ln(thnetworth+27100001)
gen log_tnetworth=ln(tnetworth+16400001)
gen log_tdebt_ed=ln(tdebt_ed+1)
gen log_thdebt_ed=ln(thdebt_ed+1)

sum tdebt_ed thdebt_ed thnetworth tnetworth log_thdebt_ed log_thnetworth

/*
foreach x of varlist black log_thdebt_ed log_thnetworth $educ $controls {
drop if missing(`x')
}
*/

foreach x of varlist black log_thdebt_ed log_thnetworth $educ5 $controls {
drop if missing(`x')
}

xtset id3 swave


***full models and models for black and white separately, including wealth in full model, after model with the controls
//log file
capture log close
log using reg_probit_re2, text replace

xtprobit selfemp i.black log_thdebt_ed, re vce(robust)
eststo fs1

xtprobit selfemp i.black log_thdebt_ed $educ $controls, re vce(robust)
eststo fs2

xtprobit selfemp i.black log_thdebt_ed log_thnetworth $educ $controls, re vce(robust)
eststo fs3

xtprobit selfemp log_thdebt_ed if black==1, re vce(robust)
eststo fs4

xtprobit selfemp log_thdebt_ed $educ $controls if black==1, re vce(robust)
eststo fs5

xtprobit selfemp log_thdebt_ed log_thnetworth $educ $controls if black==1, re vce(robust)
eststo fs6

xtprobit selfemp log_thdebt_ed if black==0, re vce(robust)
eststo fs7

xtprobit selfemp log_thdebt_ed $educ $controls if black==0, re vce(robust)
eststo fs8

xtprobit selfemp log_thdebt_ed log_thnetworth $educ $controls if black==0, re vce(robust)
eststo fs9

esttab fs* using reg_full_black-white-separately2.csv, ///
star (* 0.05 ** 0.01 *** 0.001) compres title(Student Debt and Household Net worth, Probit regressions) ///
mtitles("All" "All" "All" "Black" "Black" "Black" "White" "White" "White") replace

eststo clear

/*
***full models and models for black and white separately, including wealth before model with the controls
//log file
capture log close
log using reg_probit_re, text replace

xtprobit selfemp i.black log_thdebt_ed, re vce(robust)
eststo fs1

xtprobit selfemp i.black log_thdebt_ed log_thnetworth, re vce(robust)
eststo fs2

xtprobit selfemp i.black log_thdebt_ed log_thnetworth $educ $controls, re vce(robust)
eststo fs3

xtprobit selfemp log_thdebt_ed if black==1, re vce(robust)
eststo fs4

xtprobit selfemp log_thdebt_ed log_thnetworth if black==1, re vce(robust)
eststo fs5

xtprobit selfemp log_thdebt_ed log_thnetworth $educ $controls if black==1, re vce(robust)
eststo fs6

xtprobit selfemp log_thdebt_ed if black==0, re vce(robust)
eststo fs7

xtprobit selfemp log_thdebt_ed log_thnetworth if black==0, re vce(robust)
eststo fs8

xtprobit selfemp log_thdebt_ed log_thnetworth $educ $controls if black==0, re vce(robust)
eststo fs9

esttab fs* using reg_full_black-white-separately.csv, ///
star (* 0.05 ** 0.01 *** 0.001) compres title(Student Debt and Household Net worth, Probit regressions) ///
mtitles("All" "All" "All" "Black" "Black" "Black" "White" "White" "White") replace

eststo clear
*/

**Graph business owners by wealth and student debt
capture log close
log using _graph_owner_probit, text replace

xtprobit selfemp i.black##c.log_thdebt_ed log_thnetworth $educ $controls, re vce(robust)
margins black, at(log_thdebt_ed=(0(2)13.50))
marginsplot, xlabel(0(3)13) xtitle("Household Value of Student Loan Debt, Logged") ytitle("Predicted Probability of" "Business Ownership")
graph save ownerXstuddebt_probit, replace

xtprobit selfemp i.black##c.log_thnetworth log_thdebt_ed $educ $controls, re vce(robust)
margins black, at(log_thnetworth=(0(2)18))
marginsplot, xlabel(0(3)18) xtitle("Household Value of Networth, Logged") ytitle("Predicted Probability of" "Business Ownership")
graph save ownerXwealth_probit, replace

graph use ownerXstuddebt_probit
graph use ownerXwealth_probit

log close






***Model by education categories
//capture log close
//log using reg_probit_by_educ, text replace
//log using reg_probit_by_educ, append

capture log close
log using reg_probit_re3, text replace

** Analysis by education categories
**full sample
foreach x of varlist $educ5 {
di _n "DV=" "`x'" //This prints out the variable name.
//xtprobit selfemp i.black if `x'==1, re vce(robust)
//eststo `x'_1
xtprobit selfemp i.black log_thdebt_ed log_thnetwort if `x'==1, re vce(robust)
//eststo `x'_1
xtprobit selfemp i.black log_thdebt_ed log_thnetworth $controls if `x'==1, re vce(robust)
//eststo `x'_2
}

/*
esttab hsorles* somcolorasso* college* graddeg* using reg_probit_by_education.csv, ///
star (* 0.05 ** 0.01 *** 0.001) compres title(Black+White: Student Debt, Household Networth, probit) ///
mtitles("hsorles" "hsorles" "somcolorass" "somcolorass" "college" "college" "graddeg" "graddeg") replace

eststo clear
*/

**Black sample
foreach x of varlist $educ5 {
di _n "DV=" "`x'" //This prints out the variable name.
xtprobit selfemp log_thdebt_ed log_thnetwort if `x'==1&black==1, re vce(robust)
eststo `x'_1
xtprobit selfemp log_thdebt_ed log_thnetworth $controls if `x'==1&black==1, re vce(robust)
eststo `x'_2
}

/*
esttab hsorles* somcolorasso* college* cg* using reg_probit_by_education.csv, ///
star (* 0.05 ** 0.01 *** 0.001) compres title(Black: Student Debt, Household Networth, probit) ///
mtitles("hsorles" "hsorles" "somcolorass" "somcolorass" "college" "college" "cg" "cg") append


esttab hsorles* somcolorasso* college* graddeg* using reg_probit_by_education.csv, ///
star (* 0.05 ** 0.01 *** 0.001) compres title(Black: Student Debt, Household Networth, probit) ///
mtitles("hsorles" "hsorles" "somcolorass" "somcolorass" "college" "college" "graddeg" "graddeg") append
*/
eststo clear

**white sample
foreach x of varlist $educ5 {
di _n "DV=" "`x'" //This prints out the variable name.
xtprobit selfemp log_thdebt_ed log_thnetwort if `x'==1&black==0, re vce(robust)
eststo `x'_1
xtprobit selfemp log_thdebt_ed log_thnetworth $controls if `x'==1&black==0, re vce(robust) //doen't converge for white.
eststo `x'_2

eststo clear


/*
***College and grad degrees together

**full sample
foreach x of varlist $educ3 {
di _n "DV=" "`x'" //This prints out the variable name.
//xtprobit selfemp i.black if `x'==1, re vce(robust)
//eststo `x'_1
xtprobit selfemp i.black log_thdebt_ed log_thnetwort if `x'==1, re vce(robust)
//eststo `x'_1
xtprobit selfemp i.black log_thdebt_ed log_thnetworth $controls if `x'==1, re vce(robust)
//eststo `x'_2
}

**Black sample
foreach x of varlist $educ3 {
di _n "DV=" "`x'" //This prints out the variable name.
xtprobit selfemp log_thdebt_ed log_thnetwort if `x'==1&black==1, re vce(robust)
eststo `x'_1
xtprobit selfemp log_thdebt_ed log_thnetworth $controls if `x'==1&black==1, re vce(robust)
eststo `x'_2
}

eststo clear

**white sample
foreach x of varlist $educ3 {
di _n "DV=" "`x'" //This prints out the variable name.
xtprobit selfemp log_thdebt_ed log_thnetwort if `x'==1&black==0, re vce(robust)
eststo `x'_1
xtprobit selfemp log_thdebt_ed log_thnetworth $controls2 if `x'==1&black==0, re vce(robust) //doen't converge for white.
eststo `x'_2

eststo clear

log close


**Note: conduct analysis for the business value and profit.
/*
xtprobit selfemp i.black, re vce(robust) //this model converges (1)
xtprobit selfemp i.black log_thdebt_ed, re vce(robust) //this model converges (1)
xtprobit selfemp i.black log_thdebt_ed log_thnetworth, re vce(robust) //this model converges (1)
xtprobit selfemp i.black log_thdebt_ed log_thnetworth somcolorasso college graddeg, re vce(robust) //this model converges (1)

xtprobit selfemp i.black log_thdebt_ed log_thnetworth somcolorasso college graddeg sex, re vce(robust) //this model converges (1)

xtprobit selfemp i.black log_thdebt_ed log_thnetworth somcolorasso college graddeg sex age, re vce(robust) //this model converges (1)

xtprobit selfemp i.black log_thdebt_ed log_thnetworth somcolorasso college graddeg sex age age2, re vce(robust) 

xtprobit selfemp i.black log_thdebt_ed log_thnetworth somcolorasso college graddeg sex age age2 mari_status, re vce(robust) 

xtprobit selfemp i.black log_thdebt_ed log_thnetworth somcolorasso college graddeg sex age age2 mari_status immigrant, re vce(robust) 

xtprobit selfemp i.black log_thdebt_ed log_thnetworth somcolorasso college graddeg sex age age2 mari_status immigrant parent, re vce(robust) 

xtprobit selfemp i.black log_thdebt_ed log_thnetworth somcolorasso college graddeg sex age age2 mari_status immigrant parent industry2, re vce(robust) 

//sex age age2 mari_status immigrant parent industry2

/*
xtprobit selfemp i.black log_thdebt_ed $educ $controls, re vce(robust) //this model converges (2)
xtprobit selfemp i.black log_thnetworth $educ $controls, re vce(robust) //this model converges (3)
xtprobit selfemp i.black log_thdebt_ed log_thnetworth $educ $controls, re vce(robust) //this model does not coverge (4).

/*
xtprobit selfemp i.black $educ $controls, re vce(robust)
xtprobit selfemp i.black log_thdebt_ed $educ $controls, re vce(robust)
xtprobit selfemp i.black log_thnetworth $educ $controls, re
xtprobit selfemp i.black log_thdebt_ed log_tnetworth $educ $controls, re vce(robust)
xtprobit selfemp i.black log_thdebt_ed log_thnetworth $educ $controls, re vce(robust)


/*
logit selfemp $educ $controls if black==1, cluster(shhadid)
eststo fs2

logit selfemp $educ $controls log_thnetworth if black==1, cluster(shhadid)
eststo fs4

logit selfemp $educ $controls log_thdebt_ed if black==1, cluster(shhadid)
eststo fs5

logit selfemp $educ $controls log_thdebt_ed log_thnetworth if black==1, cluster(shhadid)
eststo fs6

logit selfemp $educ $controls if black==0, cluster(shhadid)
eststo fs7

logit selfemp $educ $controls log_thnetworth if black==0, cluster(shhadid)
eststo fs8

logit selfemp $educ $controls log_thdebt_ed if black==0, cluster(shhadid)
eststo fs9

logit selfemp $educ $controls log_thdebt_ed log_thnetworth if black==0, cluster(shhadid)
eststo fs10

esttab fs* using reg6_se&ws_tables_clustered_black_white_separately2.rtf, ///
star (* 0.05 ** 0.01 *** 0.001) compres title(Education, Student Debt and household total net worth, Log Odds) ///
mtitles("All" "Black" "Black" "Black" "Black" "White" "White" "White" "White") replace

eststo clear


log close

/*
//graphs
foreach x of varlist selfemp {
foreach y of varlist log_tdebt_ed log_thdebt_ed {
logit `x' i.black##c.`y' $educ $controls if `x'~=.&age>=18&age<=75, cluster(shhadid)
margins black, at(`y'=(0(2)13.50))
marginsplot, xlabel(0(3)13.50) xtitle("`y'_18-75&15hrs")
graph save _`y'_18-75&15hrs_clus, replace

logit `x' i.black##c.`y' $educ $controls if `x'~=.&age>=18&age<=64,cluster(shhadid)
margins black, at(`y'=(0(2)13.50))
marginsplot, xlabel(0(3)13.50) xtitle("`y'_18-64&15hrs")
graph save _`y'_18-64&15hrs_clus, replace

}
}


log close

foreach y of varlist log_tdebt_ed log_thdebt_ed {
graph use _`y'_18-75&10hrs_clus
graph use _`y'_18-64&10hrs_clus

graph use _`y'_18-75&15hrs_clus
graph use _`y'_18-64&15hrs_clus
}


/*
foreach x of varlist $educ {
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp black $controls log_tdebt_ed if selfemp~=.&age>=18&age<=75
eststo `x'_bw1
logit selfemp black $controls log_thdebt_ed if selfemp~=.&age>=18&age<=75
eststo `x'_bw1
}

esttab *fs* *bw* using reg2_se&ws.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(Black-white sample, 18-75 years old, 15hrs) append

**black sample
foreach x of varlist $educ {
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp $controls if selfemp~=.&black==1&age>=18&age<=75
eststo `x'_b1
logit selfemp $controls log_tdebt_ed if selfemp~=.&black==1&age>=18&age<=75
eststo `x'_b2
logit selfemp $controls log_thdebt_ed if selfemp~=.&black==1&age>=18&age<=75
eststo `x'_b3
}

esttab *b* using reg2_se&ws.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(Black Sample, 18-75 years old, 15hrs) append

**White sample
foreach x of varlist $educ {
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp $controls if selfemp~=.&black==0&age>=18&age<=75
eststo `x'_w1
logit selfemp $controls log_tdebt_ed if selfemp~=.&black==0&age>=18&age<=75
eststo `x'_w2
logit selfemp $controls log_thdebt_ed if selfemp~=.&black==0&age>=18&age<=75
eststo `x'_w3
}

esttab *w* using reg2_se&ws.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(White Sample, 18-75 years old, 15hrs) append


//18-64 years old

capture log close
log using reg2_se&ws_tables_18-64_15hrs, text replace


**full sample, 10hrs, working age population, 18-64 years oll.

logit selfemp black $educ $controls if selfemp~=.&age>=18&age<=64
eststo fsa1

logit selfemp black $educ $controls log_tdebt_ed if selfemp~=.&age>=18&age<=64
eststo fsa2

logit selfemp black $educ $controls log_thdebt_ed if selfemp~=.&age>=18&age<=64
eststo fsa3


foreach x of varlist $educ {
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp black $controls log_tdebt_ed if selfemp~=.&age>=18&age<=64
eststo `x'_bkw1
logit selfemp black $controls log_thdebt_ed if selfemp~=.&age>=18&age<=64
eststo `x'_bkw1
}

esttab *fsa* *bkw* using reg2_se&ws.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(Black-white sample, 18-64years old, 15hrs) append

**black sample
foreach x of varlist $educ {
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp $controls if selfemp~=.&black==1&age>=18&age<=64
eststo `x'_bk1
logit selfemp $controls log_tdebt_ed if selfemp~=.&black==1&age>=18&age<=64
eststo `x'_bk2
logit selfemp $controls log_thdebt_ed if selfemp~=.&black==1&age>=18&age<=64
eststo `x'_bk3
}

esttab *bk* using reg2_se&ws.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(Black Sample, 18-64 years old, 15hrs) append

**White sample
foreach x of varlist $educ {
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp $controls if selfemp~=.&black==0&age>=18&age<=64
eststo `x'_wh1
logit selfemp $controls log_tdebt_ed if selfemp~=.&black==0&age>=18&age<=64
eststo `x'_wh2
logit selfemp $controls log_thdebt_ed if selfemp~=.&black==0&age>=18&age<=64
eststo `x'_wh3
}

esttab *wh* using reg2_se&ws.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(White Sample, 18-64 years old, 15hrs) append

log close


/*

capture log close
log using reg_educ_black_10hrs, text replace

**Black 18-75 years old, 10hrs plus/week.

foreach x of varlist $educ {
foreach y of varlist $educdebt {
gen log_`y'=ln(`y'+1)
logit selfemp $controls if selfemp~=.&`x'==1&black==1&age>=18&age<=75
eststo `x'black1
logit selfemp $controls log_`y' if selfemp~=.&`x'==1&black==1&age>=18&age<=75
eststo `x'black2

drop log*
}
}

**white 18-75 years old, 10hrs plus/week.

foreach x of varlist $educ {
foreach y of varlist $educdebt {
gen log_`y'=ln(`y'+1)
logit selfemp $controls if selfemp~=.&`x'==1&black==1&age>=18&age<=75
eststo `x'white1
logit selfemp $controls log_`y' if selfemp~=.&`x'==1&black==1&age>=18&age<=75
eststo `x'white2

drop log*
}
}

esttab full *fulldebt *black* *white* using reg2_se&ws_tables.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(education and education debt) replace

/*
esttab *full *black* *white* using reg2_se&ws_tables.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(education and education debt) nonumbers mtitles("Model A" "Model B") replace


capture log close
log using reg6_educ_white_10hrs, text replace

**white, working age population, 18-64 years old.
foreach x of varlist $educ {
foreach y of varlist $educdebt {
//foreach z of varlist $assets {
gen log_`y'=ln(`y'+1)
//gen log2_`z'=ln(`z'+1)
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp $control log_`y' if selfemp~=.&`x'==1&black==0
//logit selfemp $control log_`y' log2_`z' if selfemp~=.&`x'==1&black==1
drop log*
}
}

capture log close
log using reg6_educ_full_15hrs, text replace

drop if tjb_mwkhrs<=14

**full sample, working age population, 18-64 years old.
foreach x of varlist $educ {
foreach y of varlist $educdebt {
//foreach z of varlist $assets {
gen log_`y'=ln(`y'+1)
//gen log2_`z'=ln(`z'+1)
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp $control log_`y' if selfemp~=.&`x'==1
//logit selfemp $control log_`y' log2_`z' if selfemp~=.&`x'==1
drop log*

}
}


capture log close
log using reg6_educ_black_15hrs, text replace

**Black,working age population, 18-64 years old.
foreach x of varlist $educ {
foreach y of varlist $educdebt {
//foreach z of varlist $assets {
gen log_`y'=ln(`y'+1)
//gen log2_`z'=ln(`z'+1)
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp $control log_`y' if selfemp~=.&`x'==1&black==1
//logit selfemp $control log_`y' log2_`z' if selfemp~=.&`x'==1&black==1
drop log*

}
}


capture log close
log using reg6_educ_white_15hrs, text replace

**white, working age population, 18-64 years old.
foreach x of varlist $educ {
foreach y of varlist $educdebt {
//foreach z of varlist $assets {
gen log_`y'=ln(`y'+1)
//gen log2_`z'=ln(`z'+1)
di _n "DV=" "`x'" //This prints out the variable name.
logit selfemp $control log_`y' if selfemp~=.&`x'==1&black==0
//logit selfemp $control log_`y' log2_`z' if selfemp~=.&`x'==1
drop log*

}
}

log close

	
/*

logit selfemp $educ $control black if selfemp~=.
eststo full

*black smaple
logit selfemp $educ $control if selfemp~=.&black==1
eststo black

*white sample
logit selfemp $educ $control if selfemp~=.&black==0
eststo white

esttab full black white using reg.rtf,star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(Effect of education and education debt by race) replace

//education debt
global educdebt="toeddebtval tdebt_ed thdebt_ed"
foreach x of varlist $educdebt {
	gen log_`x'=ln(`x'+1)
logit selfemp $educ $control black if selfemp~=.
eststo `x'_full_1
logit selfemp $educ $control black log_`x' if selfemp~=.
eststo `x'_full_2
logit selfemp $educ $control log_`x' if selfemp~=.
eststo `x'_full_3
logit selfemp $educ $control black log_`x' if selfemp~=.
eststo `x'_full_4
}

esttab *full* using reg.rtf, star (* 0.05 ** 0.01 *** 0.001) compres  ///
title(Effect of education and education debt by race) append

*black smaple
drop log*
foreach x of varlist $educdebt {
	gen log_`x'=ln(`x'+1)
logit selfemp $educ $control if selfemp~=.&black==1
eststo `x'_black_1
logit selfemp $educ $control log_`x' if selfemp~=.&black==1
eststo `x'_black_2


*white sample
logit selfemp $educ $control if selfemp~=.&black==0
eststo `x'_white_1
logit selfemp $educ $control log_`x' if selfemp~=.&black==0
eststo `x'_white_2
}

esttab *black* using reg.rtf, star (* 0.05 ** 0.01 *** 0.001) ///
title(Effect of education and education debt for black) append

esttab *white* using reg.rtf, star (* 0.05 ** 0.01 *** 0.001) ///
title(Effect of education and education debt for white) append

log close


/*
pwcorr tbsjval tjb_prftb $asseth if first==1, sig
pwcorr tbsjval tjb_prftb $debt2 if first==1, sig

pwcorr tbsjval tjb_prftb $asseth if first==1&black==1, sig
pwcorr tbsjval tjb_prftb $asseth if first==1&black==0, sig

pwcorr tbsjval tjb_prftb $debt2 if first==1&black==1, sig
pwcorr tbsjval tjb_prftb $debt2 if first==1&black==0, sig

estpost ttest tval_ast thval_ast, by(black)
esttab using test.rtf, stat(mean sd) wide replace

estpost ttest tval_ast thval_ast, by(black)
esttab using test.rtf, stat(mu_1 mu_2 b) replace



//Education debt negatively related to profit/loss in the full sample
//Education debt negatively related to profit/loss for white, but significantly related for black.
//debts against is positively associated with profit for both black abnd white.
//Understand why education debt is significantly associated wih profit for white, but for black.
//credit card debt not significant associate with profit.

/*
profit and debt on tot asset correlation:
Positive in full sample.
Not significant for black.
Positive and significant for white.

Profit and education debt correlation:
Negative and significant in full sample
Not singificant for black: Black education is not transformed into entrepreneurship. it maybe because black can't afford to enter entrepreneurship due to so much debts. If when you control for wealth if education debt will be significantly associated with business profit for black. 
Negative and significant for white

Profit and total assets and networth correlation:
Positive and significant in full sample.
Not significant for black.
Positive and significant for white.

Mean comparison between black and white:
Difference in personal level networth is not significantly
Difference in hosusehold level networth is statifically significant
Note: This difference between personal and household level networth is not noted in Failie's research
difference in person level Value of IRA and KEOGH accounts (tirakeoval) is statisiticall significant .
Difference in household level Value of 401k, 403b, 503b, and Thrift Savings Plan accounts (tthr401val) is statistically significant .
Difference in Person-level sum of value of primary residence (tval_home) is statistically significant .
difference in Household-level sum of value of primary residence(thval_home) is statifically significant.
difference in person-level sum of equity in primary residence (teq_home) is statistically significant . 
difference in Household-level sum of equity in primary residence is statistically significant(theq_home). 
Difference in Person-level sum of all debt (tdebt_ast) is statifically significant.
Difference in household-level sum of all debt (thdebt_ast) is statifically significant.
Difference in amount of student loans or educational expenses owed in own name only (toeddebtval) is not statistically significant.
Difference in person-level sum of value of educational debt (tdebt_ed) (TJSEDDEBTVAL TOEDDEBTVAL) is statifically significant.
Difference in household-level sum of amount owed on student loans and educational expenses (thdebt_ed) is statistically significant.
difference in Person-level sum of debt against primary residence (tdebt_home) is statiscally significant.
Difference in Household-level sum of debt against primary residence (thdebt_home) is statistically significant.
Difference in Amount of debt against the business owned as job (tbsjdebtval) is not statifically significant. 
*/


/*++++++++++++++++++++++++++++++++++++++++++++++++++
Maximum number of employees
Note: 1 employee(only self)= subsistance entrepreneurship
More than 25 employees=high groth entrepreneurship/opportunity driven entrep.
2 to 9 employees (see literature for classification)
10 to 25 employees (see literature for classification)
++++++++++++++++++++++++++++++++++++++++++++++++++++

codebook tjb1_empb
rename tjb1_empb numbemployees
labe define employee 1"Only self" 2"2 to 9 employees" ///
3"10 to 25 employees" 4"Greater than 25 employees"
label values numbemployees employee
codebook numbemployees

/*
tabstat tbsjval, stat(n mean sd min max) by(black)
tabstat tbsjval if first==1, stat(n mean sd min max) by(black)

codebook ejb_incpb
codebook ejb_incpb if first==1
list id swave monthcode job first ejb_jobid ejb_jborse ejb_incpb tbsjval if first==1 in 1/500,clean

list id swave monthcode job ejb_jobid ejb_jborse tbsjval in 1/100,clean
list id swave monthcode job ejb_jobid ejb_jborse tbsjval if first==1 & tbsjval==. in 1/200,clean

count if first==1 & tbsjval==.
count if first==1
dis 13197-1338
count if first==1 & tbsjval~=.

tabstat tbsjval if first==1, stat(n mean sd min max) by(black)
tabstat tbsjval if first==1& tbsjval~=., stat(n mean sd min max) by(black)
count if first==1 & tbsjval~=.&race<3

tabstat tbsjval if first==1& tbsjval~=.&race<3, stat(n mean sd min max) by(black)

list id swave monthcode job ejb_jobid ejb_jborse tbsjval black if first==1& tbsjval~=.&race<3 in 1/500,clean

brows id swave monthcode job ejb_jobid ejb_jborse tbsjval black if first==1& tbsjval~=.&race<3

//ttest varname [if] [in] , by(groupvar) [options1]


ttest tbsjval if first==1&tbsjval~=.,by(black)

global controls="educ2 age sex mari_status parent immigrant"
reg tbsjval black `controls' if first==1&tbsjval~=.&race<3

reg tbsjval if first==1&tbsjval~=.
reg tbsjval if first==1&tbsjval~=.&race<3
reg tbsjval black if first==1&tbsjval~=.&race<3
reg tbsjval black `controls' if first==1&tbsjval~=.&race<3

gen log_tbsjval=ln(tbsjval+1)

xtmixed log_tbsjval if first==1&tbsjval~=.&race<3||id:, cov(unstr) mle 
xtmixed log_tbsjval if first==1&tbsjval~=.&race<3||id: swave, cov(unstr) mle 
xtmixed log_tbsjval black if first==1&tbsjval~=.&race<3||id: swave, cov(unstr) mle 
xtmixed log_tbsjval black swave if first==1&tbsjval~=.&race<3||id: swave, cov(unstr) mle 
xtmixed log_tbsjval i.black##c.swave if first==1&tbsjval~=.&race<3||id: swave, cov(unstr) mle //interaction not significant
xtmixed log_tbsjval i.black##c.swave educ2 age sex mari_status parent immigrant if first==1&tbsjval~=.&race<3||id: swave, cov(unstr) mle //interaction not significant


/*
xtmixed log_tbsjval black if first==1&tbsjval~=.&race<3||id:, cov(unstr) mle 

xtmixed log_tbsj1val if log_tbsj1val~=.||id: swave, cov(unstr) mle 
xtmixed log_tbsj1val i.black##c.swave i.asian##c.swave if log_tbsj1val~=.&race!=4||id: swave, cov(unstr) mle 

/*
egen idwavejob=group(id swave job)
list id swave monthcode job ejb_jobid ejb_jborse tbsjval in 1/100,clean

qbys idwavejob swave: keep if _n==1
list id idwavejob swave monthcode job ejb_jobid ejb_jborse tbsjval in 1/100,clean
tabstat tbsjval, stat(n mean sd min max) by(black) 
reg tbsjval black
sum tbsjval
*/

/* Note: Fidure out how to keep multiple jobs per waves for the same person. 

gsort id -monthcode
qbys id swave: keep if _n==1

list id swave monthcode job ejb_jobid ejb_jborse tbsjval if id==120,clean

list id swave monthcode job ejb_jobid ejb_jborse tbsjval if tbsjval~=. in 1/150,clean


//Variable description
theq_home	Household-level sum of equity in primary residence (TEQ_HOME) [this is household-level data, therefore this value is copied to every member of the household].
tdebt_cc	Person-level sum of amount owed on credit card debt and store bills (TJSCCDEBTVAL, TOCCDEBTVAL)
thdebt_cc	Household-level sum of amount owed on credit card debt and store bills (TDEBT_CC) [this is household-level data, therefore this value is copied to every member of the household].
tdebt_ed	Person-level sum of value of educational debt (TJSEDDEBTVAL TOEDDEBTVAL)
thdebt_ed	Household-level sum of amount owed on student loans and educational expenses (TDEBT_ED) [this is household-level data, therefore this value is copied to every member of the household].


tval_home	Person-level sum of value of primary residence (either TPROPVAL or TMHVAL) in which the person is an owner of the residence.   The home's value is divided equally among its total number of owners.
thval_home	Household-level sum of value of primary residence (TVAL_HOME) [this is household-level data, therefore this value is copied to every member of the household].
tdebt_home	Person-level sum of debt against primary residence (sum of either TPRLOAN(i)AMT or TMHLOAN(i)AMT for i=1,2,3) in which the person is an owner of the residence.   The home's debt is divided equally among its total number of owners.
thdebt_home	Household-level sum of debt against primary residence (TDEBT_HOME) [this is household-level data, therefore this value is copied to every member of the household].
teq_home	Person-level sum of equity in primary residence (TVAL_HOME -TDEBT_HOME)
theq_home	Household-level sum of equity in primary residence (TEQ_HOME) [this is household-level data, therefore this value is copied to every member of the household].

ssuid
swave
shhadid
spanel
pnum
monthcode

eresidenceid //Processing-created residence id
tehc_st //Monthly state of residence
tehc_metro //Monthly metropolitan status of residence

eeduc //What is the highest level of school ... completed or the highest degree received by December of (reference year)?
tage //Age as of last birthday
esex //Sex of this person
erace //What race(s) does ... consider herself/himself to be?
ems //Is ... currently married, widowed, divorced, separated, or never married?
tceb //Children ever born/fathered



eorigin //Is ... Spanish, Hispanic, or Latino?
ebornus // Was born in the US?
enatcit //How did ... become a U.S citizen?
ebiomomus //Was ... biological mother born in the U.S.?
ebiodadus //was ....biological dad born in the US?

/*Self-employment*/

ejb1_jborse //This variable describes the type of work arrangement, whether work for an employer, self employed or other.
ejb1_clwrk //Class of worker
ejb1_incpb //Variable showing if business 1 was incorporated
tjb1_empb //What is the maximum number of employees, including ..., working for ... at any given time?

ejb1_endwk //(in 08 as tebdate1): Last week in the reference period where the job was held (Daniel's note: las week where the business was held. Daniel: this measures business exit.]
ejb1_rendb //(in 08 as erendb1): What is the main reason ... gave up or ended this business? 
ejb1_strtjan //(in 08 as tsbdate1): Identifies whether a job/business/work arrangement began in January of the reference year or started before the reference year (this can measure business entry to see who entry during COVID-19). [Business starting date]
ejb1_startwk //(in 08 as tsbdate1): This variable gives the value for the first week in the reference period that the person held this job/business. [business starting data]
tjb1_strtyr //(in 08 as tsbdate1): In what year did ... begin this job/business? [year the business starts]
ejb1_typpay1 //(in 08, but count find name. Excel is acting up). Whether wage/salary income was received (Respondents who had a job, a business that was either incorporated or the respondents drew a regular salary, or another work arrangement during the reference period). [whether the business pays a salary to the owner]
tjb1_gamt1 //(in 08). What is/was the gross dollar amount of ... actual gross pay before any taxes and other deductions? [The amount of salary earned from business].

/*bysiness ownership and values*/

/*ebus_inv_num //Number of businesses owned as an investment only.*/
ebsj1perown //Percent ownership of first business owned as a job as of the end of the reference period.
ebsj2perown //Percent ownership of second business owned as a job as of the end of the reference period.
ebsj3perown //Percent ownership of third business owned as a job as of the end of the reference period.
ebsj4perown //Percent ownership of fourth business owned as a job as of the end of the reference period.
ebsj5perown //Percent ownership of fifth business owned as a job as of the end of the reference period.
ebsi1perown //Percentage ownership of 1st business/es owned as investment only.
ebsi2perown //Percent ownership of second business owned as an investment only as of the end of the reference period.

/*Business values*/
tbsj1val //Value of first business owned as a job as of the last day of the reference period [not including debts against the business].
tbsj2val //Value of second business owned as a job as of the last day of the reference period [not including debts against the business].
tbsj3val //Value of third business owned as a job as of the last day of the reference period [not including debts against the business].
tbsj4val //Value of fourth business owned as a job as of the last day of the reference period [not including debts against the business].
tbsj5val //Value of fifth business owned as a job as of the last day of the reference period [not including debts against the business].
tbsi1val //Value of first business owned as an investment only as of the last day of the reference period [not including debts against the business].
tbsi2val	//Value of second business owned as an investment only as of the last day of the reference period [not including debts against the business].

/*Business debt*/
tbsj1debtval	//Amount of debt against the first business owned as job as of the end of the reference period.
tbsj2debtval	//Amount of debt against the second business owned as job as of the end of the reference period.
tbsj3debtval	//Amount of debt against the third business owned as job as of the end of the reference period.
tbsj4debtval	//Amount of debt against the fourth business owned as job as of the end of the reference period.
tbsj5debtval	//Amount of debt against the fifth business owned as job as of the end of the reference period.
tbsi1debtval	//Amount of debt against the first business owned as an investment only as of the end of the reference period.
tbsi2debtval	//Amount of debt against the second business owned as an investment only as of the end of the reference period.

/*wealth measures*/
eown_thr401 //Owned any 401k, 403b, 503b, or Thrift Savings Plan accounts during the reference period.
eown_pension //Participated in a defined-benefit pension or cash balance plan during the reference period.
eown_govs //Owned any government securities during the reference period [such as savings bonds, T-Bills, T-Bonds, T-Notes, and government sponsored enterprise (GSE) credit instruments such as Fannie Mae].
eown_irakeo //Owned any IRA or KEOGH accounts during the reference period.
tirakeoval //Value of IRA and KEOGH accounts as of the last day of the reference period.
tthr401val //Value of 401k, 403b, 503b, and Thrift Savings Plan accounts as of the last day of the reference period.
tval_ast //Person-level sum of all asset values (TVAL_BANK, TVAL_STMF, TVAL_BOND, TVAL_RENT, TVAL_RE, TVAL_OTH, TVAL_RET, TVAL_BUS, TVAL_HOME, TVAL_VEH, TVAL_ESAV).
thval_ast //Household-level sum of all asset values (TVAL_AST) [this is household-level data, therefore this value is copied to every member of the household].
tnetworth //Person-level net worth (TVAL_AST, -TDEBT_AST).
thnetworth //Household-level net worth [this is household-level data, therefore this value is copied to every member of the household].

/*Regular debts*/
edebt_cc	//Owed any money for credit cards or store bills during the reference period.
edebt_ed	//Owed any money for student loans or educational-related expenses during the reference period.
edebt_ot	//Owed any money for other debts during the reference period [such as medical bills not covered by insurance, loans obtained through a bank or credit union, money owed to private individuals, debt held against mutual funds or stocks].
ejsccdebt	//Owed any money for credit cards or store bills jointly with a spouse or civil union partner during the reference period.
tjsccdebtval	//Share of credit card debt or store bills owed jointly with a spouse or civil union partner as of the last day of the reference period.
eoccdebt	//Owed any money for credit cards or store bills in own name only during the reference period.
toccdebtval	//Amount of credit card and store bills owed in own name only as of the last day of the reference period.
ejseddebt	//Owed any money for student loans or educational expenses jointly with a spouse or civil union partner during the reference period.
tjseddebtval	//Share of student loans or educational expenses owed jointly with a spouse or civil union partner as of the last day of the reference period.
eoeddebt	//Owed any money for student loans or educational expenses in own name only during the reference period.
toeddebtval	//Amount of student loans or educational expenses owed in own name only as of the last day of the reference period.

tdebt_ast	//Person-level sum of all debt (TDEBT_SEC, TDEBT_USEC).
thdebt_ast	//Household-level sum of all debt (TDEBT_AST) [this is household-level data, therefore this value is copied to every member of the household].

tftotinc //total household income



/*
list id swave monthcode job ejb_jobid ejb_jborse tbsjval if tbsjval~=. in 1/100,clean
list id swave monthcode job ejb_jobid ejb_jborse tbsjval in 96/200,clean
list id swave monthcode job ejb_jobid ejb_jborse tbsjval if tbsjval~=. in 96/200,clean
list id swave monthcode job ejb_jobid ejb_jborse tbsjval in 1/100,clean

list id swave monthcode job ejb_jobid ejb_jborse tbsjval tjb_prftb if tjb_prftb<0 in 1/1000,clean
tab black if tjb_prftb<0
list id swave monthcode job ejb_jobid ejb_jborse first tbsjval tjb_prftb if tjb_prftb<0&first==1 in 1/1000,clean

ttest tjb_prftb if first==1&tbsjval~=.,by(black)

ttest tjb_prftb if first==1,by(black)


ttest tjb_prftb if first==1&tbsjval~=.&tjb_prftb>0,by(black) //statistically significant

ttest tjb_prftb if first==1&tjb_prftb>0,by(black) //statistically significant

list id swave monthcode job ejb_jobid ejb_jborse tjb_empb tbsjval tjb_prftb if first==1 in 1/100,clean
list id swave monthcode job ejb_jobid ejb_jborse tjb_empb tbsjval tjb_prftb if first==1 in 1/1000,clean

list id swave monthcode job ejb_jobid ejb_jborse tjb_empb tbsjval tjb_prftb tbsjdebtval if first==1 in 1/1000,clean

ttest tbsjdebtval if first==1&tbsjdebtval~=.&tbsjdebtval>0,by(black) //not significant

ttest tbsjdebtval if first==1,by(black) //not significant
reg tbsjdebtval i.race if first==1 //not significant

//number of employees: 

list id swave monthcode job ejb_jobid ejb_jborse tjb_empb tbsjval tjb_prftb if first==1 in 1/1000,clean

list id swave monthcode job ejb_jobid ejb_jborse tjb_empb tbsjval tjb_prftb first in 1/1000,clean


list id swave monthcode job ejb_jobid ejb_jborse tbsjval tdebt_ast thdebt_ast toeddebtval if first==1 in 1/50,clean

list id swave monthcode job ejb_jobid ejb_jborse tbsjval tdebt_ast thdebt_ast toeddebtval if first==1 in 1/100,clean

list id swave monthcode job ejb_jobid ejb_jborse tbsjval tdebt_ast thdebt_ast toeddebtval if first==1 in 1/1000,clean

list id swave monthcode job ejb_jobid ejb_jborse tbsjval tdebt_ast thdebt_ast toeddebtval ///
if first==1&toeddebtval~=. in 1/1000,clean

ttest toeddebtval if first==1&toeddebtval~=.,by(black) //not significant

ttest toeddebtval if first==1,by(black) //not significant

ttest tdebt_ast if first==1,by(black) // significant (total personal debts)

ttest thdebt_ast if first==1,by(black) //significant (total household debts)

ttest tdebt_ast if first==1&tdebt_ast~=.,by(black) // significant (total personal debts)

ttest thdebt_ast if first==1&thdebt_ast~=.,by(black) //significant (total household debts)

pwcorr tbsjval tdebt_ast thdebt_ast toeddebtval tbsjdebtval if first==1,sig

pwcorr tbsjval tdebt_ast thdebt_ast toeddebtval tbsjdebtval if first==1&black==1,sig //significant, except for educ debt and bus value.
pwcorr tbsjval tdebt_ast thdebt_ast toeddebtval tbsjdebtval if first==1&black==0,sig //significant, except for educ debt and bus value.


//Debts, asset and profit correlation
//Type of debts: Does credit card vs business debt make a difference for profit/loss

/*list id swave monthcode job ejb_jobid ejb_jborse tbsjval tjb_prftb first if first==1 in 1/100,clean //tjb_prftb:business profit/loss
ttest tjb_prftb if first==1,by(black) //difference is statistically significant

pwcorr tbsjval tjb_prftb tdebt_ast thdebt_ast toeddebtval tbsjdebtval ///
tval_ast thval_ast tnetworth thnetworth if first==1,sig //significant, except for educ debt and bus value.

pwcorr tbsjval tjb_prftb tdebt_ast thdebt_ast toeddebtval tbsjdebtval ///
tval_ast thval_ast tnetworth thnetworth if first==1&black==1,sig //significant, except for educ debt and bus value.

pwcorr tbsjval tjb_prftb tdebt_ast thdebt_ast toeddebtval tbsjdebtval ///
tval_ast thval_ast tnetworth thnetworth if first==1&black==0,sig //significant, except for educ debt and bus value.
*/

codebook tirakeoval tthr401val, compact

ttest tirakeoval if first==1,by(black) //difference is significant.
ttest tthr401val if first==1,by(black) //difference is significant.
pwcorr tbsjval tjb_prftb tirakeoval tthr401val if first==1,sig //significant, except for educ debt and bus value.

pwcorr tbsjval tjb_prftb tirakeoval tthr401val if first==1&black==1,sig //significant, except for educ debt and bus value.

pwcorr tbsjval tjb_prftb tirakeoval tthr401val if first==1&black==0,sig //significant, except for educ debt and bus value.

Correlation between Profit and Value of IRA and KEOGH accounts, and  Value of 401k, 403b, 503b, and Thrift:
Positive and significant in full sample.
Positive and significan for white sample.
Negative and significant for black sample.
*/
//list id swave monthcode job $asseth tbsjval tjb_prftb first if first==1 in 1/100,clean //tjb_prftb:business profit/loss

//list id swave monthcode job $debt2 tbsjval tjb_prftb first if first==1 in 1/100,clean //tjb_prftb:business profit/loss

/*ttest tbsjval if first==1,by(black)
ttest tjb_prftb if first==1,by(black)

foreach x of varlist $asseth $debt2{
di _n "DV=" "`x'" //This prints out the variable name.
ttest `x' if first==1,by(black)
} //Black-white differences in home equity and values, and personal and household education debt are statistically significant.
*/