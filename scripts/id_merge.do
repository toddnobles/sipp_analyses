capture log close

clear all
set more off
set trace off
pause on
macro drop _all

local homepath "/Volumes/Extreme SSD/SIPP Data Files/"
local datapath "`homepath'/dtas"

cd "`homepath'"


local c_time = c(current_time)
local today : display %tdCYND date(c(current_date), "DMY")

log using "./_logs/id_tests_`today'.log", text replace 


cd "`datapath'"

global file1="pu2014w1"
global file2="pu2014w2"
global file3="pu2014w3_13"
global file4="pu2014w4"
global file5="pu2018"
global file6="pu2019_lowercase"
global file7="pu2020_lowercase"
global file8="pu2021_lowercase"

global varbasic_ids="spanel shhadid swave monthcode ssuid pnum wpfinwgt"
global demographics="eeduc tage esex erace ems tceb ebornus eorigin"

//This section creates our unique list of person level IDs
clear
save id_testing, replace emptyok 
foreach num of numlist 1/8 {
use $varbasic_ids $demographics using ${file`num'}, clear
compress
append using id_testing
save id_testing, replace
} 
 
egen ssuid_spanel_pnum_id = group(ssuid spanel pnum)
egen ssuid_shhadid_pnum_id = group(ssuid shhadid pnum)
sort ssuid pnum swave monthcode 
egen tag = tag(ssuid pnum shhadid)
bysort ssuid pnum: egen tag_sum = sum(tag)

