

clear all

set linesize 200
macro drop _all
set more off

//Working with the work, wealth and debt data
use sipp_working, clear 

keep if idwave==1 // this drops the monthly observations.
keep if age>=18&age<=64&tjb_mwkhrs>=15

//egen id3=group(ssuid shhadid pnum)


//Descriptive statistics
drop if ejb_jborse==3
recode ejb_jborse (2=1 "Self-employed") (nonmiss=0 "wage&salary"), into(selfemp)
tab selfemp, missing

gen age2=age^2
label variable age2 "Age squared"

recode ebornus (1=0 "Born in the US") (2=1 "Immigrant"), gen(immigrant)
tab immigrant
tab ebornus

tab ems
rename ems mari_status
label variable mari_status "Marital status"

recode tceb (1/7=1 "Have a child or more") (0=0 "Have no children"), gen(parent)
tab tceb
tab parent

codebook tjb_ind
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

recode eeduc (31/39=1 "high school or less") ///
(40/41=2 "Some College") ///
(42=3 "Associate's degree (2-year college)") ///
(43=4 "College degree") ///
(44/46=5 "Graduate school degree"), gen(educg)
tab educg

recode educ (1/2=1 "High school or less") (nonmiss=0 "More than high school"), into(hsorles)
recode educ (3/4=1 "Some college/Associate") (nonmiss=0 "allother"), into(somcolorasso)
recode educ (5=1 "College degree") (nonmiss=0 "allother"), into(college)
recode educ (6=1 "Graduate degree") (nonmiss=0 "allother"), into(graddeg)

recode educ (5/6=1 "College & Grad") (nonmiss=0 "allother"), into(cg)
tab cg

codebook hsorles somcolorasso college graddeg

**Recoding educ into four categories: hsorles somcolorasso college graddeg
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

label define educ3_label 1"High school or less" 2"Some college/Associate" 3"College degree" 4"Graduate degree"
label list educ3_label
label values educ3 educ3_label
codebook educ3

codebook hsorles somcolorasso college graddeg cg
codebook hsorles somcolorasso college graddeg cg,compact

//recoding esex to Male=0, Female=1
codebook esex
recode esex (1=0 Male) (2=1 Female),gen(sex) 
codebook sex

//working with the black-white sample
/*label define erace2 1"White only" 2"Black only" 3"Asian only" 4"other/Residual"
label values erace erace2
codebook erace
tab erace
*/

keep if erace==1|erace==2 //this keeps the black and white sample only.
codebook erace
tab erace
tab erace,missing

recode erace (2=1 Black) (nonmiss=0 White), into(black)
tab black
codebook black

//keep if idwave==1

sort id2 swave 
qby id2: egen numwave=total(idwave) //number of wave per id2 (person)

keep if numwave>1
sum tdebt_ed thnetworth tnetworth


//global educ="hsorles somcolorasso college graddeg"

//working with Self-employed sample only

keep if selfemp==1

//creating profit dummy variables
sum tbsjval tjb_prftb

list id2 swave shhadid ssuid pnum monthcode esex black tbsjval tjb_prftb in 1/50

tab tjb_prftb if tjb_prftb==.
tab black if tjb_prftb==.
tab black if tjb_prftb<0

gen profposi=tjb_prftb>0 if tjb_prftb<.
tab profposi,missing
gen prof10k=tjb_prftb>=10000 if tjb_prftb<.
tab prof10k, missing


gen log_thnetworth=ln(thnetworth+1)
label variable log_thnetworth "Household NetWorth(Logged)"
gen log_thdebt_ed=ln(thdebt_ed+1)
label variable log_thdebt_ed "Household Student Loan Debt(Logged)"

gen log_tdebt_ed=ln(tdebt_ed+1) //individual level student debt
gen log_prof=ln(tjb_prftb+1928284)
gen log_bvalue=ln(tbsjval)

sum tjb_prftb tbsjval log_prof log_bvalue

//global assets="tval_ast thval_ast tnetworth thnetworth tirakeoval tthr401val tval_home thval_home teq_home theq_home" 
//global debt2="tdebt_ast thdebt_ast tbsjdebtval tdebt_cc thdebt_cc toeddebtval tdebt_ed thdebt_ed tdebt_home thdebt_home"

global profdebt="tbsjval tjb_prftb toeddebtval tdebt_ed thdebt_ed"
global educ="i.educ3"
global educ2="hsorles somcolorasso college graddeg"
//global educ="somcoll asdeg college graddeg"
//global educ="hs somcoll asdeg college graddeg"
//global educ="nohs hs somcoll asdeg college graddeg"
//global control="sex age mari_status ebornus tceb"
global controls="sex age age2 mari_status immigrant parent industry2 spanel"
global educdebt="tdebt_ed thdebt_ed"
//global educdebt="toeddebtval tdebt_ed thdebt_ed"

foreach x of varlist profposi prof10k {
pwcorr `x' $educdebt,sig
}


foreach x of varlist black log_thdebt_ed log_thnetworth $educ2 $controls {
drop if missing(`x')
}


xtset id2 swave

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Controlling for survey year: "spanel" variable from global "controls" above. 
The result are the same as the ones from the models without the year control.
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

capture log close
log using reg_xtlogit_profit.re_newdata_15hrs_reported, text replace

****Model with race and debt interaction first and then adding wealth variables

foreach x of varlist profposi prof10k {
	
xtlogit  `x' i.black $educ $controls, re vce(robust)
eststo `x'_1

xtlogit  `x' i.black $educ log_thdebt_ed $controls, re vce(robust)
eststo `x'_2

xtlogit  `x' i.black $educ log_thdebt_ed log_thnetworth $controls, re vce(robust)
eststo `x'_3

}

esttab profposi* prof10k* using reg_xtlogit_profit.re_newdata_inlaborforce_15hrs_reported.csv, label ///
star (* 0.05 ** 0.01 *** 0.001) compres title("Positive Profit and Profit of $10K or More") ///
mtitles("profposi" "profposi" "profposi" "prof10k" "prof10k" "prof10k") replace

/*esttab profposi* prof10k* using reg_probit_re_profit_reported.csv, label ///
star (* 0.05 ** 0.01 *** 0.001) compres title("Positive Profit and Profit of $10K or More") ///
mtitles("profposi" "profposi" "profposi" "profposi" "prof10k" "prof10k" "prof10k" "prof10k") replace
*/


**BLack and white sample separately. Note: create graph by education group by race. 
**Racial differences are strongly significant in these models. 

eststo clear

foreach x of varlist profposi prof10k {
    
xtlogit `x' $educ $controls if black==1, re vce(robust)
eststo `x'b_1

xtlogit `x' $educ $controls if black==0, re vce(robust)
eststo `x'w_2

xtlogit `x'  $educ log_thdebt_ed $controls if black==1, re vce(robust)
eststo `x'b_3

xtlogit `x'  $educ log_thdebt_ed $controls if black==0, re vce(robust)
eststo `x'w_4

xtlogit `x' $educ log_thdebt_ed log_thnetworth $controls if black==1, re vce(robust)
eststo `x'b_5

xtlogit `x' $educ log_thdebt_ed log_thnetworth $controls if black==0, re vce(robust)
eststo `x'w_6

}

esttab profposib* profposiw* using reg_xtlogit_profit.re_newdata_inlaborforce_15hrs_reported.csv, label ///
star (* 0.05 ** 0.01 *** 0.001) compres title("Positive Profit and Profit of $10K or More") ///
mtitles("profposib" "profposib" "profposib" "profposiw" "profposiw" "profposiw" ) append

esttab prof10kb* prof10kw* using reg_xtlogit_profit.re_newdata_inlaborforce_15hrs_reported.csv, label ///
star (* 0.05 ** 0.01 *** 0.001) compres title("Positive Profit and Profit of $10K or More") ///
mtitles("prof10kb" "prof10kb" "prof10kb" "prof10kw" "prof10kw" "prof10kw" ) append


eststo clear


**By education category: Racial difference are significant for college graduate in these results. But not as strong for the other education groups. 
eststo clear

foreach y of varlist $educ2 {
foreach x of varlist profposi prof10k {

di _n "DV=" "`y'" //This prints out the variable name.

xtlogit `x' i.black $controls if `y'==1, re vce(robust)
eststo `y'`x'_1

xtlogit `x' i.black log_thdebt_ed $controls if `y'==1, re vce(robust)
eststo `y'`x'_2

xtlogit `x' i.black log_thdebt_ed log_thnetworth $controls if `y'==1, re vce(robust)
eststo `y'`x'_3

}
}

esttab hsorlesprofposi* somcolorassoprofposi* using reg_xtlogit_profit.re_newdata_inlaborforce_15hrs_reported.csv, label ///
star (* 0.05 ** 0.01 *** 0.001) compres title("Positive Profit for High School or less & some college/associate") ///
mtitles("hsorlesprofposi" "hsorlesprofposi" "hsorlesprofposi" "somcolorassoprofposi" "somcolorassoprofposi" "somcolorassoprofposi") append

esttab collegeprofposi* graddegprofposi* using reg_xtlogit_profit.re_newdata_inlaborforce_15hrs_reported.csv, label  ///
star (* 0.05 ** 0.01 *** 0.001) compres title("Positive Profit fcollege & graduate degree") ///
mtitles("collegeprofposi" "collegeprofposi" "collegeprofposi" "graddegprofposi" "graddegprofposi" "graddegprofposi") append


esttab hsorlesprof10k* somcolorassoprof10k* using reg_xtlogit_profit.re_newdata_inlaborforce_15hrs_reported.csv, label  ///
star (* 0.05 ** 0.01 *** 0.001) compres title("10k Profit for High School or less & some college/associate") ///
mtitles("hsorlesprof10k" "hsorlesprof10k" "hsorlesprof10k" "somcolorassoprof10k" "somcolorassoprof10k" "somcolorassoprof10k") append

esttab collegeprof10k* graddegprof10k* using reg_xtlogit_profit.re_newdata_inlaborforce_15hrs_reported.csv, label  ///
star (* 0.05 ** 0.01 *** 0.001) compres title("10k Profit for college & graduate degree") ///
mtitles("collegeprof10k" "collegeprof10k" "collegeprof10k" "graddegprof10k" "graddegprof10k" "graddegprof10k") append

eststo clear

log close



/*
/*ttest tbsjval if first==1,by(black)
ttest tjb_prftb if first==1,by(black)

foreach x of varlist $asseth $debt2{
di _n "DV=" "`x'" //This prints out the variable name.
ttest `x' if first==1,by(black)
} //Black-white differences in home equity and values, and personal and household education debt are statistically significant.
*/


/*

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
