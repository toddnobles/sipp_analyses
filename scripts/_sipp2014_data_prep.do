
//SIPP: https://www.census.gov/programs-surveys/sipp.html
// see https://www.census.gov/data-tools/demo/uccb/sippdict
// for codebook with topics
//https://www.census.gov/data-tools/demo/uccb/sippdict
//Note: variable in sipp2019-2021 are in upcase. convert them to lowercase before combining them.

clear all
cd "C:\Users\augusted\Dropbox\My PC (CU248DAUGUSTELT)\Documents\_research\auguste_mouw\SIPP\data_analysis\data_original"

capture log close
log using dataprep, text replace
set linesize 120
macro drop _all
set more off 


**Merging 2014 sipp waves 1-4 and 2018 sipp wave 1
clear all
macro drop _all
set more off 

global file1="pu2014w1"
global file2="pu2014w2"
global file3="pu2014w3_13"
global file4="pu2014w4"
global file5="pu2018"


//first, create a unique id variable 
clear
save id2, replace emptyok 
foreach num of numlist 1/5 {
use swave monthcode ssuid shhadid pnum using ${file`num'}, clear
compress
append using id2
save id2, replace
} 

egen id2=group(ssuid shhadid pnum)

sort id2 swave monthcode 
list in 1/100
sort id2
qby id2: keep if _n==1
save id2,replace

//creating working data set
global varbasic_ids="spanel shhadid swave monthcode ssuid pnum"
global demongraphics="eeduc tage esex erace ems tceb ebornus eorigin ebornus"

global jobs1="ejb*_jborse ejb*_clwrk tjb*_empb ejb*_incpb ejb*_jobid ejb*_startwk ejb*_endwk tjb*_mwkhrs tjb*_ind tjb*_occ"
global jobs1_reshape="ejb@_jborse ejb@_clwrk tjb@_empb ejb@_incpb ejb@_jobid ejb@_startwk ejb@_endwk tjb@_mwkhrs tjb@_ind tjb@_occ"
global jobs2="ejb*_typpay1 tjb*_gamt1 ejb*_bslryb *tbsj*val tjb*_prftb tbsj*debtval tjb*_msum" 
global jobs2_reshape="ejb@_typpay1 tjb@_gamt1 ejb@_bslryb tbsj@val tjb@_prftb tbsj@debtval tjb@_msum"

global wealth="tirakeoval tthr401val tirakeoval tthr401val tval_ast thval_ast tnetworth thnetworth tval_home thval_home teq_home theq_home tptotinc tpearn"
global debts="tdebt_ast thdebt_ast toeddebtval theq_home tdebt_cc thdebt_cc tdebt_ed thdebt_ed tdebt_home thdebt_home"  

//global debts_reshape="tbsj@debtval"
//global jobs2="ejb*_typpay1 tjb*_gamt1 ejb*_bslryb tftotinc tftotinct2 thtotinc thtotinct2 tpprpinc"
//global busval="*tbsj*val tjb*_prftb"
//global busval="*tbsj*val tbsi1val tbsi2val"
//global busval_reshape="tbsj@val tjb@_prftb"
//tptotinc=The sum of reported monthly earnings and income amounts received by an individual during the reference year.



//global busval="*tbsj*val tbsj2val tbsj3val tbsj4val tbsj5val tbsi1val tbsi2val"
//tpearn = total earning or loss from all jobs held
// eehc_ten, eresidenceid tehc_metro, : Tenure of the residence.
// ejb1_strtjan tjb1_strtyr: job starting time
//ejb1_jborse: This variable describes the type of work arrangement, whether work for an employer, self employed or other (Respondents who held a job during the reference month).
//tjb1_ind: Industry code (Respondents who worked for an employer, were self-employed or had another work arrangement)
//tjb1_occ: Occupation code (Respondents who worked for an employer, were self-employed or had another work arrangement)
// tjb1_gamt1:Gross dollar amount of ... actual gross pay before any taxes and other deductions? (Respondents who were paid an actual gross annual amount during the reference period)
// tjb1_empb: The maximum number of employees, including ..., working for ... at any given time (Respondents who were self-employed during the reference period).
// ejb1_incpb: Variable showing if business 1 was incorporated (Respondents who were self-employed during the reference period).
// ejb1_bslryb: Did/does ... draw a regular salary from ... - that is, take a regular paycheck, as opposed to just treating the profits as income? (Respondents who were self-employed and their businesses were not incorporated during the reference period).
// tftotinc: Sum of the reported monthly earning and income amounts received by all individuals in a family during the reference year.
// tftotinct2: Sum of all earnings and income received by a family, from all family members age 15 and older, including type 2 people in the family, for each month of the reference year.
// thtotinc: Sum of all earnings and income received by a household, from all household members age 15 and older for each month of the reference year
// thtotinct2: The sum of the reported monthly earnings and income amounts received by all individuals age 15 and older in the household, including up to ten type 2 individuals during the reference year.
// tpprpinc: The amount of total personal investment and property income during the reference year.
// ejb1_jobid: Unique identifier for a job which is consistent across waves.
// tjb1_prftb: Amount of profit a business made after correcting for any salary/wages that may have been paid to the owner (tjb1_prftb).


// eorigin: Is ... Spanish, Hispanic, or Latino?
// ebornus: Was born in the US?
// enatcit: How did ... become a U.S citizen?
// ebiomomus: Was ... biological mother born in the U.S.?
// ebiodadus: was ....biological dad born in the US?


foreach num of numlist 1/5 {
	
di "wave `num'"

use $varbasic_ids $demongraphics $jobs1 $jobs2 $wealth $debts using ${file`num'}, clear

capture drop _merge
merge m:1 ssuid shhadid pnum using id2, keep(1 3)
capture drop _merge
keep swave $varbasic_ids $jobs1 $jobs2 id2

reshape long $jobs1_reshape $jobs2_reshape, i(id2 monthcode) j(job)

tab ejb_jobid 
keep if ejb_jobid~=. // how di  you get 

sort id2 job month 
list id2 job month ejb_jobid tjb_occ ejb_startwk ejb_endwk tjb_mwkhrs in 1/100
list id2 job month ejb_jobid tjb_occ ejb_startwk ejb_endwk tjb_mwkhrs if id2==19

egen tot_job=count(ejb_jobid), by(id2 monthcode)
list id2 job month ejb_jobid tjb_occ ejb_startwk ejb_endwk tjb_mwkhrs if id2==27 | id2==33
save sipp2014_wv`num'_work, replace


use $varbasic_ids $demongraphics $wealth $debts using ${file`num'}, clear

// now create the other monthly data (which doesn't have to be rehaped by job)	
//keep $varbasic_ids $demongraphics $wealth $debts
capture drop _merge 
merge m:1 ssuid shhadid pnum using id2 , keep(1 3)
capture drop _merge 

compress 
save sipp2014_wv`num', replace
}

use sipp2014_wv1, clear
foreach num of numlist 2/5 {
    append using sipp2014_wv`num' 
}

save sipp2014_combined, replace 

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

// save a subset of basic control variales for the occ choice analysis.
// not time varying
use sipp2014_combined, clear
keep $demongraphics $varbasic_ids id2
sort id2
qby id2: keep if _n==1
compress
save sipp2014_basic_demographic, replace

use sipp2014_wv1_work, clear
foreach num of numlist 2/5 {
    append using sipp2014_wv`num'_work 
}

save sipp2014_work, replace 

// let's work on a primary job variable 
use sipp2014_work, clear

drop if tjb_mwkhrs<=14
gsort id2 swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby id2 swave monthcode: gen jb_main=_n==1

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main in 1/100

// how many cases of flip-flopping are there (where a jobid is main, then it isn't, then it is again)
sort id2 ejb_jobid swave monthcode
qby id2 ejb_jobid: gen jb_main_m1=jb_main[_n-1]
qby id2 ejb_jobid: gen jb_main_p1=jb_main[_n+1]
gen flip=jb_main_m1==1 & jb_main==0 & jb_main_p1==1
replace flip=1 if jb_main_m1==0 & jb_main==1 & jb_main_p1==0

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main jb_main_m1 jb_main_p1 flip in 1/100

tab flip

sort id2 jb_main swave monthcode
qby id2 jb_main: gen ch_main=ejb_jobid~=ejb_jobid[_n-1] & jb_main==1  
replace ch_main=. if jb_main==0

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main jb_main_m1 jb_main_p1 flip ch_main in 1/100

tab ch_main flip
sort id2 swave month

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if id2==48
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if id2==71

keep if jb_main==1

save sipp2014_work, replace 

use sipp2014_work, clear
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if id2==48
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if id2==71

//merging basic demographic: eeduc tage esex erace with work data
capture drop _merge 
merge m:1 ssuid shhadid pnum id2 using sipp2014_basic_demographic, keep(1 3)
capture drop _merg

tab ejb_jborse, missing

sort id2 swave monthcode 
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip in 1/100

sort id2 swave monthcode 
qby id2 swave: gen idwave=_n==1 //creating person-year (person-wave id)

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip idwave if idwave==0 in 1/100

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main erace idwave if idwave==1 in 1/100

tab  erace
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main erace idwave in 1/100

sort id2 swave esex
qby id2 swave esex: gen idwavesex=_n==1
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main erace idwave idwavesex in 1/100
brows if idwave==0&idwavesex==1
brows if idwave==1&idwavesex==1

sort id2 swave erace
qby id2 swave erace: gen idwaverace=_n==1
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main erace idwave idwaverace in 1/100
brows if idwave==0&idwaverace==1
brows if idwave==1&idwaverace==1

bysort id2: egen racestd = std(erace)
bysort id2: egen esexstd=std(esex)
list id2 erace if !missing(racestd), sepby(id2)
list id2 esexstd if !missing(esexstd), sepby(id2)
sort id2

sort id2 swave monthcode
keep if idwave==1
save sipp2014_work, replace 


//$varbasic_ids $demongraphics $wealth $debts
use sipp2014_combined, clear
compress
keep $varbasic_ids $wealth $debts id2
sort id2 swave
qby id2 swave: gen idwave=_n==1

list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth idwave if id2==200
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth idwave if id2==25
sort id2

keep if idwave==1 //this keeps person-year sample only (dropping person-month data). 
save sipp2014_wealthdebt, replace //this is person-year (person-wave) data sample

//merging work and wealth-debt data
use sipp2014_work, clear
sort id2 swave monthcode 
brows if idwave==0&idwaverace==1
brows if idwave==1&idwaverace==1

capture drop _merge
merge m:1 swave id2 using sipp2014_wealthdebt, keep(1 3)
//merge m:1 ssuid shhadid pnum id2 using sipp2014_wealthdebt, keep(1 3)
capture drop _merg

brows if idwave==0&idwaverace==1
brows if idwave==1&idwaverace==1

list ssuid shhadid pnum id2 if id2==4

list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==2
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==3
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==5
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==6
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==7|id2==8|id2==9

save sipp2014_wealthdebt, replace

**Working with the work, wealth and debt data
use sipp2014_wealthdebt, clear

sort id2 swave 

list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==2
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==3
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==5
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==7|id2==8|id2==9

codebook erace
tab erace

label define erace2 1"White only" 2"Black only" 3"Asian only" 4"other/Residual"
label values erace erace2

/*
recode erace (1=1 White) (nonmiss=0 nonwhite), into(white)
tab white 

recode erace (2=1 Black) (nonmiss=0 White), into(black)
tab black

recode erace (3=1 Asian) (nonmiss=0 nonasian), into(asian)
tab asian

recode erace (4=1 Others) (nonmiss=0 nonothers), into(other)
tab other
*/

tab erace if idwaverace==1
tab erace 

tab erace ejb_jborse, row
tab erace ejb_jborse if idwaverace==1, row

tab erace ejb_jborse, row
tab erace ejb_jborse if idwaverace==1, row

codebook esex
tab esex
tab esex ejb_jborse,col

tab esex ejb_jborse if idwave==1,col

list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse if idwave==1 in 1/100

list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse if idwave==1 in 1/1000

tab erace ejb_jborse if idwaverace==1, row
tab erace ejb_jborse if idwave==1, row

sort id2 swave
qby id2: gen id=_n==1
tab id

list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse id in 1/50
list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse if id==1 in 1/500

tab erace if id==1
rename tage age
tab erace ejb_jborse if id==1&age>=18&age<=64, row

keep if age>=18&age<=64

save sipp2014_wealthdebt, replace //This is person-year (person-wave) data sample: working data set.



**Merging SIPP2018w2-2021 waves

clear all
cd "C:\Users\augusted\Dropbox\My PC (CU248DAUGUSTELT)\Documents\_research\auguste_mouw\SIPP\data_analysis\data_original"

clear all
macro drop _all
set more off 

global file1="pu2019" //wage 2 of 2018 panel  collected in 2019
global file2="pu2020" //wage 3 of 2018 panel collected in 2020
global file3="pu2021" //wage 1 of 2021 panel collected in 2021


//first, create a unique id variable 
clear
save id2, replace emptyok 
foreach num of numlist 1/3 {
use SWAVE MONTHCODE SSUID SHHADID PNUM using ${file`num'}, clear
compress
append using id2
save id2, replace
} 

egen id2=group(SSUID SHHADID PNUM)

sort id2 SWAVE MONTHCODE 
list in 1/100
sort id2
qby id2: keep if _n==1
save id2,replace

//creating working data set
global varbasic_ids="SPANEL SHHADID SWAVE MONTHCODE SSUID PNUM"
global demongraphics="EEDUC TAGE ESEX ERACE EMS TCEB EBORNUS EORIGIN EBORNUS"

global jobs1="EJB*_JBORSE EJB*_CLWRK TJB*_EMPB EJB*_INCPB EJB*_JOBID EJB*_STARTWK EJB*_ENDWK TJB*_MWKHRS TJB*_IND TJB*_OCC"
global jobs1_reshape="EJB@_JBORSE EJB@_CLWRK TJB@_EMPB EJB@_INCPB EJB@_JOBID EJB@_STARTWK EJB@_ENDWK TJB@_MWKHRS TJB@_IND TJB@_OCC"
global jobs2="EJB*_TYPPAY1 TJB*_GAMT1 EJB*_BSLRYB *TBSJ*VAL TJB*_PRFTB TBSJ*DEBTVAL TJB*_MSUM" 
global jobs2_reshape="EJB@_TYPPAY1 TJB@_GAMT1 EJB@_BSLRYB TBSJ@VAL TJB@_PRFTB TBSJ@DEBTVAL TJB@_MSUM"

global wealth="TIRAKEOVAL TTHR401VAL TIRAKEOVAL TTHR401VAL TVAL_AST THVAL_AST TNETWORTH THNETWORTH TVAL_HOME THVAL_HOME TEQ_HOME THEQ_HOME TPTOTINC TPEARN"
global debts="TDEBT_AST THDEBT_AST TOEDDEBTVAL THEQ_HOME TDEBT_CC THDEBT_CC TDEBT_ED THDEBT_ED TDEBT_HOME THDEBT_HOME"  

foreach num of numlist 1/3 {
	
di "wave `num'"

use $varbasic_ids $demongraphics $jobs1 $jobs2 $wealth $debts using ${file`num'}, clear

capture drop _merge
merge m:1 SSUID SHHADID PNUM using id2, keep(1 3)
capture drop _merge
keep SWAVE $varbasic_ids $jobs1 $jobs2 id2

reshape long $jobs1_reshape $jobs2_reshape, i(id2 MONTHCODE) j(job)

tab EJB_JOBID 
keep if EJB_JOBID~=. // how di  you get 
/*
sort id2 job month 
list id2 job month ejb_jobid tjb_occ ejb_startwk ejb_endwk tjb_mwkhrs in 1/100
list id2 job month ejb_jobid tjb_occ ejb_startwk ejb_endwk tjb_mwkhrs if id2==19

egen tot_job=count(ejb_jobid), by(id2 monthcode)
list id2 job month ejb_jobid tjb_occ ejb_startwk ejb_endwk tjb_mwkhrs if id2==27 | id2==33
*/
save sipp2018_wv`num'_work, replace


use $varbasic_ids $demongraphics $wealth $debts using ${file`num'}, clear

// now create the other monthly data (which doesn't have to be rehaped by job)	
//keep $varbasic_ids $demongraphics $wealth $debts
capture drop _merge 
merge m:1 SSUID SHHADID PNUM using id2 , keep(1 3)
capture drop _merge 

compress 
save sipp2018_wv`num', replace
}

use sipp2018_wv1, clear
foreach num of numlist 2/3 {
    append using sipp2018_wv`num' 
}

rename _all,lower
save sipp2018_combined, replace

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
global varbasic_ids2="spanel shhadid swave monthcode ssuid pnum"
global demongraphics2="eeduc tage esex erace ems tceb ebornus eorigin ebornus"
global wealth2="tirakeoval tthr401val tirakeoval tthr401val tval_ast thval_ast tnetworth thnetworth tval_home thval_home teq_home theq_home tptotinc tpearn"
global debts2="tdebt_ast thdebt_ast toeddebtval theq_home tdebt_cc thdebt_cc tdebt_ed thdebt_ed tdebt_home thdebt_home" 

// save a subset of basic control variales for the occ choice analysis.
// not time varying
use sipp2018_combined, clear
keep $demongraphics2 $varbasic_ids2 id2
sort id2
qby id2: keep if _n==1
compress
save sipp2018_basic_demographic, replace

use sipp2018_wv1_work, clear
foreach num of numlist 2/3 {
    append using sipp2018_wv`num'_work 
}

rename _all,lower
save sipp2018_work, replace 

// let's work on a primary job variable 
use sipp2018_work, clear

drop if tjb_mwkhrs<=14
gsort id2 swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 
qby id2 swave monthcode: gen jb_main=_n==1

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main in 1/100

// how many cases of flip-flopping are there (where a jobid is main, then it isn't, then it is again)
sort id2 ejb_jobid swave monthcode
qby id2 ejb_jobid: gen jb_main_m1=jb_main[_n-1]
qby id2 ejb_jobid: gen jb_main_p1=jb_main[_n+1]
gen flip=jb_main_m1==1 & jb_main==0 & jb_main_p1==1
replace flip=1 if jb_main_m1==0 & jb_main==1 & jb_main_p1==0

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main jb_main_m1 jb_main_p1 flip in 1/100

tab flip

sort id2 jb_main swave monthcode
qby id2 jb_main: gen ch_main=ejb_jobid~=ejb_jobid[_n-1] & jb_main==1  
replace ch_main=. if jb_main==0

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main jb_main_m1 jb_main_p1 flip ch_main in 1/100

tab ch_main flip
sort id2 swave month

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if id2==48
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if id2==71

keep if jb_main==1

save sipp2018_work, replace 

use sipp2018_work, clear
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if id2==48
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if id2==71

//merging basic demographic: eeduc tage esex erace with work data
capture drop _merge 
merge m:1 ssuid shhadid pnum id2 using sipp2018_basic_demographic, keep(1 3)
capture drop _merg

tab ejb_jborse, missing

sort id2 swave monthcode 
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip in 1/100
sort id2 swave monthcode 
qby id2 swave: gen idwave=_n==1
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main flip if idwave==1 in 1/100

list id2 swave month job ejb_jobid tjb_mwkhrs jb_main erace idwave if idwave==1 in 1/100

tab  erace
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main erace idwave in 1/100

sort id2 swave esex
qby id2 swave esex: gen idwavesex=_n==1
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main erace idwave idwavesex in 1/100
brows if idwave==0&idwavesex==1
brows if idwave==1&idwavesex==1

sort id2 swave erace
qby id2 swave erace: gen idwaverace=_n==1
list id2 swave month job ejb_jobid tjb_mwkhrs jb_main erace idwave idwaverace in 1/100
brows if idwave==0&idwaverace==1
brows if idwave==1&idwaverace==1

bysort id2: egen racestd = std(erace)
bysort id2: egen esexstd=std(esex)
list id2 erace if !missing(racestd), sepby(id2)
list id2 esexstd if !missing(esexstd), sepby(id2)
sort id2

sort id2 swave monthcode
keep if idwave==1
save sipp2018_work, replace 


//$varbasic_ids $demongraphics $wealth $debts
use sipp2018_combined, clear
compress
keep $varbasic_ids2 $wealth2 $debts2 id2
sort id2 swave
qby id2 swave: gen idwave=_n==1

list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth idwave if id2==200

list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth idwave if id2==25
sort id2

keep if idwave==1 //this keeps person-year sample only (dropping person-month data). 
save sipp2018_wealthdebt, replace

use sipp2018_work, clear
sort id2 swave monthcode 

brows if idwave==0&idwaverace==1
brows if idwave==1&idwaverace==1

//merging work and wealth-debt data
capture drop _merge
merge m:1 swave id2 using sipp2018_wealthdebt, keep(1 3)
//merge m:1 ssuid shhadid pnum id2 using sipp2018_wealthdebt, keep(1 3)
capture drop _merg

brows if idwave==0&idwaverace==1
brows if idwave==1&idwaverace==1

list ssuid shhadid pnum id2 if id2==4

list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==2
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==3
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==5
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==6
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==7|id2==8|id2==9

save sipp2018_wealthdebt, replace

**Working with the work, wealth and debt data

use sipp2018_wealthdebt, clear

sort id2 swave 

list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==2
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==3
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==5
list id2 swave shhadid ssuid pnum monthcode thdebt_ed thnetworth if id2==7|id2==8|id2==9

codebook erace
tab erace

label define erace2 1"White only" 2"Black only" 3"Asian only" 4"other/Residual"
label values erace erace2

/*
recode erace (1=1 White) (nonmiss=0 nonwhite), into(white)
tab white 

recode erace (2=1 Black) (nonmiss=0 White), into(black)
tab black

recode erace (3=1 Asian) (nonmiss=0 nonasian), into(asian)
tab asian

recode erace (4=1 Others) (nonmiss=0 nonothers), into(other)
tab other
*/

tab erace if idwaverace==1
tab erace 

tab erace ejb_jborse, row
tab erace ejb_jborse if idwaverace==1, row

tab erace ejb_jborse, row
tab erace ejb_jborse if idwaverace==1, row

codebook esex
tab esex
tab esex ejb_jborse,col

tab esex ejb_jborse if idwave==1,col

list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse if idwave==1 in 1/100

list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse if idwave==1 in 1/1000

tab erace ejb_jborse if idwaverace==1, row
tab erace ejb_jborse if idwave==1, row

sort id2 swave
qby id2: gen id=_n==1
tab id

list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse id in 1/50
list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse if id==1 in 1/500

tab erace if id==1
rename tage age
tab erace ejb_jborse if id==1&age>=18&age<=64, row

keep if age>=18&age<=64

save sipp2018_wealthdebt, replace

****Appending sipp2018_wealthdebt and sipp2014_wealthdebt

use sipp2014_wealthdebt,clear
list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse id in 1/50

append using sipp2018_wealthdebt
list id2 swave shhadid ssuid pnum monthcode esex thdebt_ed thnetworth ejb_jborse id in 1/50
tab swave
tab spanel
tab erace ejb_jborse if idwaverace==1, row
tab erace ejb_jborse if idwave==1, row

tab swave if spanel==2018
tab spanel
tab swave if spanel==2019
tab swave if spanel==2020
tab swave if spanel==2021

save sipp2014to2021_wealthdebt,replace

use sipp2014to2021_wealthdebt, clear

egen id3=group(ssuid shhadid pnum)
list id2 id3 swave in 1/50 

/*
keep if ejb_jborse==2

codebook erace
keep if erace==1|erace==2 //this keeps the black and white sample only.
codebook erace
list id swave monthcode job ejb_jobid ejb_jborse tjb_mwkhrs if tjb_mwkhrs~=. in 1/1000,clean

codebook tjb_mwkhrs if tjb_mwkhrs<=10
tab tjb_mwkhrs if tjb_mwkhrs<=10
tab tjb_mwkhrs if tjb_mwkhrs<=15


//sort id swave job monthcode
//qby id swave job: gen first=_n==1
//tab first
//list id swave monthcode job first ejb_jobid ejb_jborse tbsjval in 1/100,clean


label define erace2 1"White only" 2"Black only" 3"Asian only" 4"other/Residual"
label values erace erace2
rename erace race
codebook race

gen black=.
replace black=1 if race==2
replace black=0 if race==1
label define black_label 1"Black" 0"White"
label values black black_label
codebook black
tab black
tab black, missing
codebook black

codebook esex
recode esex (1=0 Male) (2=1 Female),gen(sex) 
codebook sex

tab ebornus

recode ebornus (1=0 "was born in the US") (2=1 "was not born in the US"), gen(immigrant)
tab immigrant
tab ebornus

gen log_thnetworth=ln(thnetworth+1)

//global assets="tval_ast thval_ast tnetworth thnetworth tirakeoval tthr401val tval_home thval_home teq_home theq_home" 
//global debt2=" tdebt_ast thdebt_ast tbsjdebtval tdebt_cc thdebt_cc toeddebtval tdebt_ed thdebt_ed tdebt_home thdebt_home"

//global profdebt="tbsjval tjb_prftb toeddebtval tdebt_ed thdebt_ed"
global educ="somcolorasso college graddeg"
//global educ="hsorles somcolorasso college graddeg"
//global educ="somcoll asdeg college graddeg"
//global educ="hs somcoll asdeg college graddeg"
//global educ="nohs hs somcoll asdeg college graddeg"
//global control="sex age mari_status ebornus tceb"
global controls="sex age age2 mari_status immigrant parent log_thnetworth"
global educdebt="tdebt_ed thdebt_ed"
//global educdebt="toeddebtval tdebt_ed thdebt_ed"


capture log close

log using creating_industry_variables, text replace

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

 tab industry2
  tab industry2,nolabel
 
tab industry1 if industry1>=6070&industry1>=6460  
gen test1=industry1>=6070&industry1<=6460 if industry1<.
codebook test1

gen test2=industry1>=0570&industry1<=0760 if industry1<.

codebook test2
gen test3=test1==1&test2==1 if test1<.&test2<.
codebook test3
