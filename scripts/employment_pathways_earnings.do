webdoc init Employment_pathways_earnings, replace logall
webdoc toc 5

/***
<html>
<head><title>Employment Pathways Earnings </title></head>
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
**# Data import

use sipp_reshaped_work_comb_imputed, clear  

// bringing in monthly level data 
merge m:1 ssuid_spanel_pnum_id spanel swave monthcode using sipp_monthly_combined 
sort ssuid_spanel_pnum_id spanel swave monthcode 
bysort ssuid_spanel_pnum_id: egen _merge_avg = mean(_merge)

list ssuid_spanel_pnum_id if _merge_avg >2 & _merge_avg <3 in 1/100
list ssuid_spanel_pnum_id  spanel swave monthcode job ejb_jborse  ejb_startwk ejb_endwk tjb_mwkhrs tpearn  tage enjflag _merge if ssuid_spanel_pnum_id ==5
// by bringing in the monthly data we get the full 12 months for this person. previously missing months 9 and 10 in the job only data set 


// temporary check of race variable 
egen race_tag = tag(ssuid_spanel_pnum_id erace)
bysort ssuid_spanel_pnum_id: egen race_tag_sum = sum(race_tag)
unique ssuid_spanel_pnum_id if race_tag_sum > 1
unique ssuid_spanel_pnum_id

// according to the above, 2374 people changed the race they considered themself sometime in our data 

sort ssuid_spanel_pnum_id swave monthcode
list ssuid_spanel_pnum_id spanel swave monthcode erace race_tag_sum if race_tag_sum >1 in 1/100000, sepby(ssuid_spanel_pnum_id)



/***
<html>
<body>
<p>examining how our job variables overlap with unemployment flag that we brought in reingesting data for sipp_monthly_combined in data. Wave 4 month 7 here we see that you can be marked as a jobless spell even if you get recorded as a job during the month given there can be gaps in start/end weeks that don't stretch a full month-job </p>
***/
sort ssuid_spanel_pnum_id spanel swave monthcode ejb_startwk
list ssuid_spanel_pnum_id  swave monthcode job ejb_jborse ejb_startwk ejb_endwk enjflag  tjb_mwkhrs if ssuid_spanel_pnum_id ==199771 



// filtering to population of interest
keep if tage>=18 & tage<=64

codebook ejb_jborse

/***
<html>
<body>
<h3>Creating main job flag</h3>
***/
**# main job

gsort ssuid_spanel_pnum_id swave monthcode -tjb_mwkhrs -ejb_jobid  // sort descending by hours, breaking ties by jobid 

duplicates report ssuid_spanel_pnum_id swave monthcode tjb_mwkhrs ejb_jobid  // no ties actually broken 
qby ssuid_spanel_pnum_id swave monthcode: gen jb_main=_n==1 // 

sort ssuid_spanel_pnum_id swave monthcode 
list ssuid_spanel_pnum_id ejb_jobid swave monthcode jb_main ejb_jborse enjflag tpearn if ssuid_spanel_pnum_id==5
list ssuid_spanel_pnum_id ejb_jobid swave monthcode ejb_jobid tjb_mwkhrs jb_main ejb_jborse ejb_startwk ejb_endwk enjflag tpearn if ssuid_spanel_pnum_id==199771

keep if jb_main ==1 // gets us one record for each month with their main job or that they were unemployed 
recode enjflag (1=1 unemployed) (2=0 no), into(unemployed_flag)
codebook enjflag 
codebook unemployed_flag

// dropping those who never worked in our dataset
bysort ssuid_spanel_pnum_id: egen sum_enjflag = sum(unemployed_flag)
bysort ssuid_spanel_pnum_id: gen num_records = _N
drop if sum_enjflag == num_records



frame copy default pre_flag_creation, replace 

/***
<html>
<body>
<h1>Unemployed for 1-month analysis</h1>
***/
**# 1-month unemployed 

/***
<html>
<body>
<h3>creating lenient employment type flag</h3>
<p> job trumps unemployment flag  (must be unemployed for at least one month to count as unemployed)</p>
***/
**# employment type flag 

gen employment_type1 = 1 if ejb_jborse == 1 // W&S
replace employment_type1 = 2 if ejb_jborse == 2 // SE
replace employment_type1 = 3 if ejb_jborse == 3 // other 
replace employment_type1 = 4 if ejb_jborse == . & enjflag == 1
codebook employment_type1

// looking into odd cases here. These are instances where there's no ejb_jborse data but they have tpearn and don't get flagged as unemployed
list ssuid_spanel_pnum_id if employment_type1 == . 
list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type1 if ssuid_spanel_pnum_id==272
list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type1 if ssuid_spanel_pnum_id==937
list ssuid_spanel_pnum_id swave monthcode ejb_jobid job jb_main ejb_jborse enjflag tpearn tjb_msum employment_type1 if ssuid_spanel_pnum_id==193993 

 // will ignore these few edge cases for now as they just seem to be data entry issues 
drop if employment_type1 == . 
unique ssuid_spanel_pnum_id swave monthcode // person month level file here. So we only have one job per month and it's their main job 
unique ssuid_spanel_pnum_id swave // person years
isid ssuid_spanel_pnum_id swave monthcode // double checking 

/***
<html>
<body>
<h3>at this point we have a person-month level file with an employment status for them for each period captured in employment_type </h3>
***/

egen tag = tag(ssuid_spanel_pnum_id employment_type1)
su tag
bysort ssuid_spanel_pnum_id: egen tag_sum = sum(tag)
unique ssuid_spanel_pnum_id if tag_sum >1 // gives us count of people who changed at some point 

label define employment_types 1 "W&S" 2 "SE" 3 "Other" 4 "Unemp"
label values employment_type1 employment_types

**# marking when their job status changes
bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen change = employment_type1 != employment_type1[_n-1] & _n >1 
list ssuid_spanel_pnum_id spanel swave monthcode employment_type1  change if ssuid_spanel_pnum_id == 28558, sepby(swave) 

bysort ssuid_spanel_pnum_id (spanel swave monthcode): gen first_status = employment_type1 if _n==1

by ssuid_spanel_pnum_id: egen ever_changed = total(change)
table ever_changed
unique ssuid_spanel_pnum_id, by(ever_changed)  // counts of people falling into each job change category. 

gsort ssuid_spanel_pnum_id -change spanel swave monthcode

list ssuid_spanel_pnum_id spanel swave monthcode employment_type1 change *status if ssuid_spanel_pnum_id == 199771
by ssuid_spanel_pnum_id: gen second_status = employment_type1 if change ==1 & _n ==1
by ssuid_spanel_pnum_id: gen third_status = employment_type1 if change ==1 & _n ==2
by ssuid_spanel_pnum_id: gen fourth_status = employment_type1 if change ==1 & _n ==3
by ssuid_spanel_pnum_id: gen fifth_status = employment_type1 if change ==1 & _n ==4
by ssuid_spanel_pnum_id: gen sixth_status = employment_type1 if change ==1 & _n ==5
by ssuid_spanel_pnum_id: gen seventh_status = employment_type1 if change ==1 & _n ==6
by ssuid_spanel_pnum_id: gen eighth_status = employment_type1 if change ==1 & _n ==7
by ssuid_spanel_pnum_id: gen ninth_status = employment_type1 if change ==1 & _n ==8
by ssuid_spanel_pnum_id: gen tenth_status = employment_type1 if change ==1 & _n ==9
by ssuid_spanel_pnum_id: gen eleventh_status = employment_type1 if change ==1 & _n ==10
by ssuid_spanel_pnum_id: gen twelfth_status = employment_type1 if change ==1 & _n ==11


foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status {
	label values `x' employment_types
	//bysort ssuid_spanel_pnum_id (`x'): carryforward `x', replace 

}

sort ssuid_spanel_pnum_id spanel swave monthcode 
list ssuid_spanel_pnum_id spanel swave monthcode employment_type1  change *status if ssuid_spanel_pnum_id == 199771

list ssuid_spanel_pnum_id spanel swave monthcode employment_type1  change *status if ssuid_spanel_pnum_id == 28558	


local i = 0
foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status  {
	gsort ssuid_spanel_pnum_id -`x' 
	local i = `i' + 1
	by ssuid_spanel_pnum_id: carryforward `x', gen(status_`i') 
	
}


egen unique_tag = tag(ssuid_spanel_pnum_id) // unique id

preserve
keep if unique_tag 
contract status_*
gsort -_freq
list in 1/25
restore 


preserve
keep if unique_tag
contract status_1 status_2 status_3 
gsort -_freq
list
restore 


preserve
keep if unique_tag
contract status_1 status_2 erace 
gsort erace -_freq
list 
restore 


sort ssuid_spanel_pnum_id swave monthcode employment_type1

local i = 0

foreach x in first_status second_status third_status fourth_status fifth_status sixth_status seventh_status eighth_status ninth_status tenth_status eleventh_status twelfth_status {
	local i = `i' + 1
	bysort ssuid_spanel_pnum_id (swave monthcode) employment_type1: carryforward `x', gen(status_`i'_lim)  dynamic_condition(employment_type1[_n-1]==employment_type1[_n])

}

list ssuid_spanel_pnum_id swave monthcode employment_type1 status_*_lim if ssuid_spanel_pnum_id ==  178409 
list ssuid_spanel_pnum_id swave monthcode employment_type1 status_*_lim if ssuid_spanel_pnum_id ==  199771 
list ssuid_spanel_pnum_id swave monthcode employment_type1 status_*_lim if ssuid_spanel_pnum_id ==  28558 


bysort ssuid_spanel_pnum_id status_1_lim: egen tpearn_s1 = mean(tpearn) if status_1_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tpearn_s1, replace 
bysort ssuid_spanel_pnum_id status_2_lim: egen tpearn_s2 = mean(tpearn) if status_2_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tpearn_s2, replace 

bysort ssuid_spanel_pnum_id status_3_lim: egen tpearn_s3 = mean(tpearn) if status_3_lim == employment_type1
bysort ssuid_spanel_pnum_id: carryforward tpearn_s3, replace 
// use this method and a reshape if we decide to track more statuses 
// collapse (mean) tpearn, by(ssuid_spanel_pnum_id status_1 status_2 status_3 status_1_lim status_2_lim status_3_lim erace) cw


/***
<html>
<body>
<h3> Multi-month unemployment flag</h3>
<p> Here we create a measure of how long people held each employment status. So we can now create a person-level flag for if someone experienced unemployment for 3 months or 6 months. </p>
***/
sort ssuid_spanel_pnum_id swave monthcode 
list ssuid_spanel_pnum_id swave monthcode status_1 status_2 status_3 status_4 status_5  status_1_lim status_2_lim status_3_lim status_4_lim status_5_lim if ssuid_spanel_pnum_id== 704 

forval x = 1/12 {
	by ssuid_spanel_pnum_id: egen months_s`x' = count(status_`x'_lim)
	
}
/*
by ssuid_spanel_pnum_id: egen months_s1 = count(status_1_lim)
by ssuid_spanel_pnum_id: egen months_s2 = count(status_2_lim)
by ssuid_spanel_pnum_id: egen months_s3 = count(status_3_lim)
*/

list ssuid_spanel_pnum_id swave monthcode status_1 status_2 status_3 status_1_lim status_2_lim status_3_lim months_* if ssuid_spanel_pnum_id== 704 

bysort ssuid_spanel_pnum_id: gen unemp_3 = 1 if (status_1 == 4 & months_s1 >=3) | (status_2 == 4 & months_s2 >=3) | (status_3 ==4 & months_s3 >=3)
replace unemp_3 = 0 if unemp_3 == . 

bysort ssuid_spanel_pnum_id: gen unemp_6 = 1 if (status_1 == 4 & months_s1 >=6) | (status_2 == 4 & months_s2 >=6) | (status_3 ==4 & months_s3 >=6)
replace unemp_6 = 0 if unemp_6 == . 

list ssuid_spanel_pnum_id swave monthcode status_1 status_2 status_3 status_1_lim status_2_lim status_3_lim months_*  unemp_* in 1/200, sepby(ssuid_spanel_pnum_id)



/***
<html>
<body>
<h4> Length of unemployment spells</h4>
<p> what does unemployment look like in terms of length of spells. If someone is unemployed as second or third status the spells tend to be a bit shorter, but the median length for those spells are still 6 and 5 months, respectively.  Doesn't appear to differ by race. </p>
***/
// 

su months_s1 if status_1 == 4 & unique_tag ==1, detail
su months_s2 if status_2 == 4 & unique_tag ==1, detail
su months_s3 if status_3 == 4 & unique_tag ==1, detail 

tabstat months_s1 if status_1 ==4 & unique_tag ==1, by(erace) statistic(mean sd min med max n)
tabstat months_s2 if status_2 ==4 & unique_tag ==1, by(erace) statistic(mean sd min med max n)
tabstat months_s3 if status_3 ==4 & unique_tag ==1, by(erace) statistic(mean sd min med max n)



/***
<html>
<body>
<h1> Assessing what we have</h1>
<p> At this point, we've created status_* variables that capture each unique employment status and the order someone experiences them. For those variables, unemployed is simply that we had no ejb data for that month and the enjflag signalled unemployed. We also have the month_* vars that tell us how long people held each status. Next we have the tpearn_* vars that capture the average monthly earnings for each status. Finally, we have the two unemployment flags signalling if someone was unemployed for 3 or more months or 6 or more months.</p>
***/

list ssuid_spanel_pnum_id status_1 status_2 status_3 months_* tpearn tpearn_* tjb_prft tbsjval in 1/3000, sepby(ssuid_spanel_pnum_id)




save earnings_by_status.dta, replace 

/***
<html>
<body>
<h1>Earnings Comparisons for 1-month unemployed</h1>
***/

/***
<html>
<body>
<h3>Effect of unemployment on subsequent earnings</h3>
<p> Here we see that those entering SE from unemployment earn more on average than those entering W&S from unemployment. However, this difference only holds for white respondents, not black respondents. </p>
***/
table erace if unique_tag ==1 
table erace status_2 if unique_tag ==1 & status_1 == 4 
table erace status_2 if unique_tag ==1 & status_1 == 4, statistic(mean tpearn_s2)
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2), by(status_2) // those who start as unemployed and enter W&S or SE
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2) & erace ==1 , by(status_2) // white, start as unemp and enter W&S or SE
ttest tpearn_s2 if unique_tag ==1 & status_1 == 4 & (status_2 == 1 | status_2 == 2) & erace ==2 , by(status_2) // black, start as unemp and enter W&S and SE


/***
<html>
<body>
<h4>Those who started as W&S versus those who entered from unemployment</h4>
<p> As expected, those who enter W&S from unemployment earn less during their employed period than those who never experienced unemployment. Holds for both white and black respondents  </p>
***/
tabstat tpearn_s1 if unique_tag ==1 & status_1 == 1 & status_2 == ., statistic(n mean sd) 
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 1 , statistic(n mean sd)
ttesti 58372 4810 4772 13168 2246 3143

tabstat tpearn_s1 if unique_tag ==1 & status_1 == 1 & status_2 == ., statistic(n mean sd) by(erace) 
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 1 , statistic(n mean sd) by(erace)
ttesti 46226 4898 4826 9678 2269 3305 // white respondents
ttesti 6034 3800 3538 20178 2000 2264 // black respondents 


/***
<html>
<body>
<h4>Those who started as SE versus those who entered SE from unemployment </h4>
<p> As expected, those entering from unemployment earn less during SE than those who didn't. Holds true for both white and black respondents   </p>
***/
tabstat tpearn_s1 if unique_tag ==1 & status_1 == 2 & status_2 == ., statistic(n mean sd) 
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 2 , statistic(n mean sd)
ttesti 6095 5994 12332 958 2665 11263

tabstat tpearn_s1 if unique_tag ==1 & status_1 == 2 & status_2 == ., statistic(n mean sd) by(erace)
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 2 , statistic(n mean sd) by(erace)

ttesti 5137 6187 12732 741 2833 11750 // white respondents
ttesti 428 3834 7656 107 2010 6603 // black respondents 


/***
<html>
<body>
<h4>Those who entered SE from unemployment versus W&S</h4>
<p>Those who entered SE from unemployment versus wage and salary earn less on average. Holds for white subsample, not the case for black subsample  </p>
***/


ttest tpearn_s2 if unique_tag ==1 & status_2 == 2 & (status_1 == 4 | status_1 == 1), by(status_1)
ttest tpearn_s2 if unique_tag ==1 & status_2 == 2 & (status_1 == 4 | status_1 == 1) & erace ==1, by(status_1) // white respondents 
ttest tpearn_s2 if unique_tag ==1 & status_2 == 2 & (status_1 == 4 | status_1 == 1) & erace ==2, by(status_1) // black respoondents 



**# 3 & 6 month unemployment 

/***
<html>
<body>
<h1>Earnings comparison for 3 & 6-month unemployed </h1>
***/


/***
<html>
<body>
<h4>Those who started as W&S versus those who entered from unemployment</h4>
<p> As expected, those who enter W&S from unemployment earn less during their employed period than those who never experienced unemployment. Holds for both white and black respondents  </p>
***/

tabstat tpearn_s1 if unique_tag ==1 & status_1 == 1 & status_2 == ., statistic(n mean sd) // alwyas W&S 
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 1 & months_s1 >=3, statistic(n mean sd) // enter W&S from unemp, lose about a thousand people who were unemployed for less than three months. Still significant difference 
ttesti 58372 4810 4772 11779 2241 3194 // 3-month

tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 1 & months_s1 >=6, statistic(n mean sd) // enter W&S from unemp, lose about a thousand people who were unemployed for less than three months. Still significant difference 
ttesti 58372 4810 4772 8920 2328 3430

tabstat tpearn_s1 if unique_tag ==1 & status_1 == 1 & status_2 == ., statistic(n mean sd) by(erace) 
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 1 & months_s1 >=3 , statistic(n mean sd) by(erace)
ttesti 46226 4898 4826 8625 2262 3382 // white respondents
ttesti 6034 3800 3538 1864 2006 2335 // black respondents 

tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 1 & months_s1 >=6 , statistic(n mean sd) by(erace)
ttesti 46226 4898 4826 6424 2356 3672 // white respondents 6-month
ttesti 6034 3800 3538 1467 2074 2422  // black respondents 6-month 

/***
<html>
<body>
<h4>Those who started as SE versus those who entered SE from unemployment </h4>
<p> As expected, those entering from unemployment earn less during SE than those who didn't. Holds true for both white and black respondents   </p>
***/
tabstat tpearn_s1 if unique_tag ==1 & status_1 == 2 & status_2 == ., statistic(n mean sd) 
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 2 & months_s1 >=3 , statistic(n mean sd)
ttesti 6095 5994 12332 876 2680 11538 // three months 

tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 2 & months_s1 >=6 , statistic(n mean sd)
ttesti 6095 5994 12332 765 2752 12032


tabstat tpearn_s1 if unique_tag ==1 & status_1 == 2 & status_2 == ., statistic(n mean sd) by(erace)
tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 2 & months_s1 >=3 , statistic(n mean sd) by(erace)

ttesti 5137 6187 12732 682 2815 11961 // white respondents 3-month
ttesti 428 3834 7656 96 2044 6933 // black respondents 3-month 

tabstat tpearn_s2 if unique_tag == 1 & status_1 == 4 & status_2 == 2 & months_s1 >=6 , statistic(n mean sd) by(erace)
ttesti 5137 6187 12732 592 2972 12640 // white respondents 6-month
ttesti 428 3834 7656 80 2165 7411 // black respondents 6-month 


/***
<html>
<body>
<h4>Those who entered SE from unemployment versus W&S</h4>
<p> as with earlier unemployment measure, different findings for white and black subsamples  </p>
***/
tabstat tpearn_s2 if unique_tag ==1 & status_2 ==2 & status_1 == 1, statistic( n mean sd) // those who went WS to SE
tabstat tpearn_s2 if unique_tag ==1 & status_2 ==2 & status_1 ==4 & months_s1 >=3, statistic( n mean sd) // those who went unemp for 3 or more months to SE 
ttesti 1386 5475 14224 876 2680 11538

// by race 
tabstat tpearn_s2 if unique_tag ==1 & status_2 ==2 & status_1 == 1, statistic( n mean sd) by(erace) // those who went WS to SE
tabstat tpearn_s2 if unique_tag ==1 & status_2 ==2 & status_1 ==4 & months_s1 >=3, statistic( n mean sd) by(erace) // those who went unemp for 3 or more months to SE 

ttesti 1119 5677 15038 682 2815 11961 // white respondents 
ttesti 145 3245 7913 96 2044 6933 // black respndents 

/***
<html>
<body>
<h4>Those who went WS to Unemp to SE </h4>
<p> n-sizes get a bit too small here for comparisons within race subsamples. </p>
***/
// comparing W&S earnings for this group to those who remained W&S  
tabstat tpearn_s1 if unique_tag ==1 & status_1 == 1 & status_2 == ., statistic (n mean sd)
tabstat tpearn_s1 if unique_tag ==1 & status_1 == 1 & status_2 == 4 & status_3 == 2 &  months_s2 >=3, statistic(n mean sd) by(erace)
ttesti 58372 4810 4772 217 3454 4179 

// comparing their W&S earnings with their own SE earnings. Put differently, did they see an earnings increase in SE or does it seem to be for survival purposes. (unclear)
tabstat tpearn_s3 if unique_tag ==1 & status_1 ==1 & status_2 ==4 & status_3 ==2 & months_s2 >=3, statistic(n mean sd)
ttesti 217 3454 4179 217 3797 33940


