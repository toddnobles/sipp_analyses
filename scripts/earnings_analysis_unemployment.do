webdoc init earnings_analysis_unemployment, replace logall
webdoc toc

/***
<html>
<head><title>Earnings Analysis (Unemployment)</title></head>
***/

local homepath "/Volumes/Extreme SSD/SIPP Data Files/"

local datapath "`homepath'/dtas"

cd "`datapath'"
set linesize 255

/***
<html>
<body>
<h1>Bringing in data</h1>
***/

use sipp_reshaped_work_comb_imputed, clear  
merge m:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined 
sort ssuid_spanel_pnum_id spanel swave monthcode 
bysort ssuid_spanel_pnum_id: egen _merge_avg = mean(_merge)

list ssuid_spanel_pnum_id if _merge_avg >2 & _merge_avg <3 in 1/100
list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tjb_mwkhrs tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==5


/***
<html>
<body>
<p> by bringing in the monthly data we get the full 12 months for this person. previously missing months 9 and 10 in the job only data set </p>
<p> examining how our job variables overlap with unemployment flag that we brought in reingesting data for sipp_monthly_combined </p>

***/

sort ssuid_spanel_pnum_id spanel swave monthcode ejb_startwk
/***
<html>
<body>
<p>  Wave 4 month 7 here we see that you can be marked as a jobless spell even if you get recorded as a job during the month given there can be gaps in start/end weeks that don't stretch a full month-job </p>
***/


/***
<html>
<body>
<h1>Filtering data and creating our flags</h1>
<body>
***/
keep if tage>=18 & tage<=64

codebook ejb_jborse

// note here we're not filtering to only records with tjb_mwkhrs > 15 hours of employment. We'll do that later for describing earnings 

**# main job
gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 

duplicates report ssuid_spanel_pnum_id swave monthcode tjb_mwkhrs ejb_jobid  // no ties actually broken 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

sort ssuid_spanel_pnum_id swave monthcode 

**# Switches based on job type (self-emp or paid)
keep if jb_main == 1 // this keeps main jobs and one record for months where they are fully unemployed
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==6 // need to handle people who were never employed

recode enjflag (1=1 unemployed) (2=0 no), into(unemployed_flag)
codebook enjflag 
codebook unemployed_flag

// dropping those who never worked in our dataset
bysort ssuid_spanel_pnum_id: egen sum_enjflag = sum(unemployed_flag)
bysort ssuid_spanel_pnum_id: gen num_records = _N
drop if sum_enjflag == num_records


replace tpearn = 0 if tpearn == .
replace tjb_msum = 0 if tjb_msum == .


/// now we can use sum_enjflag as our measure of if it is ever greater than zero then that person experienced unemployment at some point in our dataset
drop if (ejb_jborse == . | ejb_jborse == 3) // dropping employment types we're not interested in 
recode ejb_jborse (2=1 SE) (1=0 WS), into(selfemp)

**# Generating our earnings measures and flags
// comparing those who experienced unemployment versus those who didn't and their earnings 
gen ever_unemployed = 1 if sum_enjflag >0
replace ever_unemployed = 0 if sum_enjflag == 0
codebook ever_unemployed

// flag for ever self-employed 
bysort ssuid_spanel_pnum_id: egen sum_se_flag = sum(selfemp) // selfemp coded as 0 for W&S and 1 for SE 
gen ever_se = 1 if sum_se_flag >0
replace ever_se = 0 if sum_se_flag == 0 
codebook ever_se

bysort ssuid_spanel_pnum_id: egen mean_tpearn = mean(tpearn) 
bysort ssuid_spanel_pnum_id: egen mean_tpearn_se = mean(tpearn) if selfemp == 1
bysort ssuid_spanel_pnum_id (mean_tpearn_se): carryforward mean_tpearn_se, replace  
bysort ssuid_spanel_pnum_id: egen mean_tpearn_ws = mean(tpearn) if selfemp == 0 
bysort ssuid_spanel_pnum_id (mean_tpearn_ws): carryforward mean_tpearn_ws, replace 
egen unique_tag = tag(ssuid_spanel_pnum_id) // unique id

egen tag2 = tag(ssuid_spanel_pnum_id selfemp)
su tag2
bysort ssuid_spanel_pnum_id: egen tag2_sum = sum(tag2) // lets us quickly see who had multiple employment types in our data 

unique ssuid_spanel_pnum_id, by(sum_enjflag) // gives us a picture of how many people experienced unemployment and how many months they experienced it. So here ~4000 people were unemployed for one month or less, ~2100 experienced two "months" of unemployment (here someone is marked as unemployed for the month if they experienced as little as a week of unemployment that month)

/***
<html>
<body>
<h1>Tables of earnings</h1>
<body>
***/

/***
<html>
<body>
<h3>All monthly earnings </h3>
<p>In the first table below we see that those who ever experienced unemployment earned less on average (during their time of employment) than those who never experienced  unemployment. In the third and fourth tables we see that this holds looking within our subsamples of white and black respondents. </p>
<body>
***/
ttest mean_tpearn if unique_tag ==1, by(ever_unemployed)
table (erace) (ever_unemployed) if unique_tag ==1, statistic(mean mean_tpearn)
ttest mean_tpearn if unique_tag ==1 & erace ==1, by(ever_unemployed)
ttest mean_tpearn if unique_tag ==1 & erace ==2, by(ever_unemployed)

/***
<html>
<body>
<h3>Wage and salary earnings </h3>
<p> In the following tables we see that those who ever experienced unemployment and were at some point employed in Wage and Salary, experienced lower average earnings during their wage and salary months than those who never experienced unemployment. This trend holds within our subsamples of black and white respondents. </p>
<body>
***/
ttest mean_tpearn_ws if unique_tag ==1, by(ever_unemployed)
ttest mean_tpearn_ws if unique_tag ==1 & erace ==1, by(ever_unemployed)
ttest mean_tpearn_ws if unique_tag ==1 & erace ==2, by(ever_unemployed)

/***
<html>
<body>
<h3>Self employment earnings </h3>
<p> In the following tables we see that those who ever experienced unemployment and were at some point sefl-employed, experienced lower average earnings during their SE months than those who never experienced unemployment. This trend holds within our white subsample but not for our black subsample of respondents. </p>
<body>
***/
ttest mean_tpearn_se if unique_tag ==1 ,by(ever_unemployed)
ttest mean_tpearn_se if unique_tag ==1 & erace ==1, by(ever_unemployed)
ttest mean_tpearn_se if unique_tag ==1 & erace ==2, by(ever_unemployed)



/***
<html>
<body>
<h1>Tables of profitability, business size, earnings, business value for SE sample</h1>
<body>
<p> Because of this complexity in when someone is self-employed versus unemployed, we'll look at those who were ever self-employed and their profit, business size, earnings etc </p>
***/

/***
<html>
<body>
<h3>Profitability </h3>
<p> We see that for those who were self-employed at some point and never experienced unemployment, we see that those who experienced unemployment at some point had less profitable businesses on average. 
Note that we should be careful how we capture profitability given that it's calcualted after taking the owner self-pay out, so depending on what our self-employed folks take then we're capturing different things here.  </p>
<body>
***/

bysort ssuid_spanel_pnum_id: egen mean_tjb_prftb = mean(tjb_prftb) 

//list monthcode jb_main selfemp tpearn tjb_msum tjb_prftb ever_unemployed mean*   if ssuid_spanel_pnum_id==  32
//list monthcode jb_main selfemp tpearn tjb_msum tjb_prftb ever_unemployed mean*   if ssuid_spanel_pnum_id==  74

table (ever_unemployed) (ever_se) if unique_tag ==1, statistic(mean mean_tjb_prftb)
ttest mean_tjb_prftb if unique_tag ==1 & ever_se == 1, by(ever_unemployed)


/***
<html>
<body>
<h3>Business size </h3>
<body>
<p> Here we see that those who experienced self employment at some point were more likely than we would expect to have smaller businesses than those who were never unemployed. 

Note that this doesn't capture instances where switched businesses as their main job, so if someone started a small business and then started another larger business that became their main job, we would only capture their first business size. Likely not a meaningful issue for the purposes of these descriptives </p>
***/
/*
Response Code
1. 1 (Only self)
2. 2 to 9 employees
3. 10 to 25 employees
4. Greater than 25 employees
*/
drop _merge
tabchi ever_unemployed tjb_empb if unique_tag ==1 & ever_se == 1
// seems those who experienced unemployment are more likely to work as sole-proprietor or own smaller business than those who did not experience unemployment
tab tjb_empb if unique_tag ==1 & ever_se ==1
tab ever_unemployed tjb_empb if unique_tag ==1 & ever_se ==1, row



/***
<html>
<body>
<h3>Earnings </h3>
<p> same as earlier table with lower earnings associated with unemploymet </p> 
<body>
***/
ttest mean_tpearn_se if unique_tag == 1 & ever_se ==1, by(ever_unemployed)

/***
<html>
<body>
<h3>Business Value </h3>
<p> Note there is one person here ssuid_spanel_pnum_id == 67628 who has a data entry error where they report a business value for records that are not SE. We see that those who experienced unemployment had less valuable businesses on average.
<body>
***/
bysort ssuid_spanel_pnum_id: egen mean_tbsjval = mean(tbsjval) 

table (ever_unemployed) (ever_se) if unique_tag ==1, statistic(mean mean_tbsjval) 
ttest mean_tbsjval if unique_tag ==1 & ever_se == 1, by(ever_unemployed)


/***
<html>
<body>
<h1>SE who never experienced unemployment </h1>
<body>
<p> Looking only at SE who have never experienced unemployment, see distribution of those three variables for full SE never unemployed sample and then within races, between races (depending on sample sizes)
 </p>
***/


/***
<html>
<body>
<h3>Earnings </h3>
<body>
***/

su mean_tpearn if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, detail // average monthly earnings
hist mean_tpearn if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0
webdoc graph, hardcode
graph box mean_tpearn if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, nooutsides
webdoc graph, hardcode
 
/***
<html>
<body>
<h3>Self-employment only earnings </h3>
<body>
***/

su mean_tpearn_se if unique_tag == 1 & ever_se == 1 & ever_unemployed == 0, detail // average monthly earnings when self-employed
hist mean_tpearn_se if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0
webdoc graph, hardcode
graph box mean_tpearn_se if unique_tag ==1 & ever_se ==1 & ever_unemployed == 0, nooutsides 
webdoc graph, hardcode


/***
<html>
<body>
<h3>Profitability </h3>
<body>
***/

su mean_tjb_prftb if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0, detail // average monthly profit 
hist mean_tjb_prftb if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0
webdoc graph, hardcode
graph box mean_tjb_prftb if unique_tag ==1 & ever_se ==1 & ever_unemployed == 0, nooutsides 
webdoc graph, hardcode

/***
<html>
<body>
<h3>Business Value </h3>
<body>
***/

su mean_tbsjval if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0, detail // average business value  
hist mean_tbsjval if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0 & mean_tbsjval < 1000000
webdoc graph, hardcode

graph box mean_tbsjval if unique_tag ==1 & ever_se ==1 & ever_unemployed == 0, nooutsides 
webdoc graph, hardcode

tab tjb_empb if unique_tag ==1 & ever_se ==1 & ever_unemployed ==0 
hist tjb_empb if unique_tag == 1 & ever_se == 1 & ever_unemployed ==0
webdoc graph, hardcode

/***
<html>
<body>
<h1>Examining between race differences for those never unemployed  </h1>
<p> With our broad measure of ever_se we have adequate n-sizes for some comparisons here. </p>
<body>
***/
table (erace) (ever_unemployed) if unique_tag ==1 & ever_se == 1 

/***
<html>
<body>
<h4> Profitability: <h4> 
<p> Using white respondents as a reference group, the only statistically significant difference in profitability is between white and black respondents. </p>
<body>
***/
pwmean mean_tjb_prftb if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, over(erace)  mcompare(dunnett) pveffects cimeans

/***
<html>
<body>
<h4> earnings: <h4> 
<p> Using white respondents as a reference group, the only statistically significant difference in profitability is between white and black respondents. </p>
<body>
***/
pwmean mean_tpearn if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, over(erace)  mcompare(dunnett) pveffects cimeans

/***
<html>
<body>
<h4> SE earnings <h4>
<body>
***/
pwmean mean_tpearn_se if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, over(erace)  mcompare(dunnett) pveffects cimeans

/***
<html>
<body>
<h4> business value: <h4> 
<p> Using white respondents as a reference group, the only statistically significant difference in business value is between white and black respondents. </p>
<body>
***/
pwmean mean_tbsjval if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, over(erace)  mcompare(dunnett) pveffects cimeans


table (erace) if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, statistic( fvproportion tjb_empb)
capture drop _merge
tabchi erace tjb_empb if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0



/***
<html>
<body>
<h1>Within race diffrences between those who experienced unemployment vs those who didn't </h1>
<body>
***/
**# 

/***
<html>
<body>
<h3>Earnings </h3>
<body>
***/
hist mean_tpearn if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0, by(erace)
webdoc graph, hardcode
graph box mean_tpearn if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, nooutsides by(erace)
webdoc graph, hardcode

/***
<html>
<body>
<h3>Profitability</h3>
<p> Interestingly, the difference in profitablity is not statistically significantly different within black respondents comparing those who were unemployed vs not. This is for white respondents and is at the .1 level for asian respondents  
<body>
***/
hist mean_tjb_prftb if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0, by(erace)
webdoc graph, hardcode
graph box mean_tjb_prftb if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, nooutsides by(erace)
webdoc graph, hardcode
ttest mean_tjb_prftb if unique_tag ==1 & ever_se == 1 & erace ==1, by(ever_unemployed)
ttest mean_tjb_prftb if unique_tag ==1 & ever_se == 1 & erace ==2, by(ever_unemployed)
ttest mean_tjb_prftb if unique_tag ==1 & ever_se == 1 & erace ==3, by(ever_unemployed)


/***
<html>
<body>
<h3>Business Value </h3>
<p> Black respondents who experinced unemployment have avg business value that is not statistically different than their always employed peers. This is not true for White and Asian samples. </p> 
<body>
***/
hist mean_tbsjval if unique_tag == 1 & ever_se ==1 & ever_unemployed == 0 & mean_tbsjval < 1000000, by(erace) 
webdoc graph, hardcode
graph box mean_tbsjval if unique_tag ==1 & ever_se == 1 & ever_unemployed == 0, nooutsides by(erace)
webdoc graph, hardcode
ttest mean_tbsjval if unique_tag ==1 & ever_se == 1 & erace ==1, by(ever_unemployed)
ttest mean_tbsjval if unique_tag ==1 & ever_se == 1 & erace ==2, by(ever_unemployed)
ttest mean_tbsjval if unique_tag ==1 & ever_se == 1 & erace ==3, by(ever_unemployed)


/***
<html>
<body>
<h3>Business Size</h3>
<p> Again unemployment doesn't seem to have the same effect for our black subsample as it does in the white or asian subsample </p> 
<body>
***/
tabchi ever_unemployed tjb_empb if unique_tag ==1 & ever_se == 1 & erace ==1
tabchi ever_unemployed tjb_empb if unique_tag ==1 & ever_se == 1 & erace ==2
tabchi ever_unemployed tjb_empb if unique_tag ==1 & ever_se == 1 & erace ==3



/***
<html>
<p> based on the analyses below, we know that the most common employment paths are as follows </p>
***/

/*
   |   status_1     status_2     status_3     status_4     status_5   status_6  _freq |
     |----------------------------------------------------------------------------------|
  1. |        W&S            .            .            .            .          .  58372 |
  2. | Unemployed          W&S            .            .            .          .   7858 |
  3. |         SE            .            .            .            .          .   6095 |
  4. |        W&S   Unemployed            .            .            .          .   5403 |
  5. |        W&S   Unemployed          W&S            .            .          .   4659 |
     |----------------------------------------------------------------------------------|
  6. | Unemployed          W&S   Unemployed            .            .          .   2325 |
  7. | Unemployed          W&S   Unemployed          W&S            .          .   1634 |
  8. |        W&S           SE            .            .            .          .    883 |
  9. |        W&S   Unemployed          W&S   Unemployed            .          .    735 |
 10. |         SE          W&S            .            .            .          .    715 |
     |----------------------------------------------------------------------------------|
 11. | Unemployed           SE            .            .            .          .    597 |
 12. |        W&S   Unemployed          W&S   Unemployed          W&S          .    533 |
 13. |      Other            .            .            .            .          .    529 |
 14. |         SE   Unemployed            .            .            .          .    493 |
 15. | Unemployed          W&S   Unemployed          W&S   Unemployed          .    459 |
     |----------------------------------------------------------------------------------|
 16. | Unemployed          W&S   Unemployed          W&S   Unemployed        W&S    311 |
 17. |        W&S           SE          W&S            .            .          .    290 |
 18. |        W&S   Unemployed           SE            .            .          .    202 |
 19. |      Other          W&S            .            .            .          .    188 |
 20. | Unemployed        Other            .            .            .          .    178 |
     |----------------------------------------------------------------------------------|
 21. |        W&S        Other            .            .            .          .    155 |
 22. | Unemployed           SE   Unemployed            .            .          .    150 |
 23. |         SE          W&S           SE            .            .          .    126 |
 24. |      Other   Unemployed            .            .            .          .    123 |
 25. |         SE   Unemployed           SE            .            .          .    121 |
     +----------------------------------------------------------------------------------+
*/

