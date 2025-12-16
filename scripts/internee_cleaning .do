/*
This script cleans our internee list. It also matches with the repatriation lists to give us some measure of those who were german sailors, etc. 
*/


/* Specify directory locations: */
global MatchingDoFiles "/Users/toddnobles/Documents/pows/abe_algorithm_code_july2020/codes" /* location where all ABE/Ferrie matching algorithm files (and .ado files) are stored */

global outdir  "/Users/toddnobles/Documents/pows/ndira/cleaned"  /*location to store cleaned data*/
global matchdir "/Users/toddnobles/Documents/pows/ndira/"	/*location to store matched data*/

** standardizing our internees
*-------------------------------------------------------------------------------
** bringing in those who died that I hand matched. 
import delimited "/Users/toddnobles/Documents/pows/data/checks/dead_internee_hand_match.csv", clear
drop if blobname == "NA"
save "/Users/toddnobles/Documents/pows/ndira/dead_internee_hand_match.dta", replace 


** This file is from Peter where hiscnew has already been assigned to our internees. Sent to me on July 31st, 2025. 
//use "/Users/toddnobles/Documents/pows/ndira/bpl_hiscnew.dta",clear 
import delimited "/Users/toddnobles/Documents/pows/data/processed/archive_scans_extracts_allfmts.csv", clear
capture drop _merge
merge 1:1 blobname using "/Users/toddnobles/Documents/pows/ndira/dead_internee_hand_match.dta", keep(master match) keepusing(death_card_page)
gen died = 1 if death_card_page != ""
replace died = 0 if death_card_page ==""


gen BPL = 450 if bpl_char == "austria" | bpl_char == "hungary"
replace BPL = 453 if bpl_char == "germany"

** now we do our basic clean up
rename first_name_cl f_name // call first name "f_name"
rename last_name_cl l_name 	// call last name "l_name"
destring age,  replace ignore("NA")
gen birthyr = 1917-age
gen id = internal_id		// generate unique identifier, or rename existing identifier "id"
gen sex = 2 if sex_cl == "female"
replace sex = 1 if sex_cl == "male" 
keep if sex == 1 // keeping only men 
tostring id, replace 


cd $MatchingDoFiles // set current directory to location of abeclean.ado and abematch.ado
abeclean f_name l_name, nicknames sex(sex) initial(middleinitial)

save "${outdir}/male_archive_ready2link.dta", replace 


** now we need to bring in our repatriation lists and see how many we find
import delimited "/Users/toddnobles/Documents/pows/ndira/repatriation_lists.csv", clear
rename first_name f_name
rename last_name l_name
gen sex = 1 
gen id = _n
tostring(id), replace
abeclean f_name l_name, nicknames sex(sex) initial(middleinitial)
gen birthyr = 1885
save  "${outdir}/repatriation_ready2link.dta", replace


abematch f_name_cleaned l_name_cleaned,  file_A("${outdir}/male_archive_ready2link.dta") file_B("${outdir}/repatriation_ready2link.dta") timevar(birthyr)  timeband(80) save(`"${outdir}/matches_repatriated"')  replace id_A(id) id_B(id) keep_A(l_name f_name blobname) keep_B(l_name f_name) 


abematch f_name_nysiis l_name_nysiis,  file_A("${outdir}/male_archive_ready2link.dta") file_B("${outdir}/repatriation_ready2link.dta") timevar(birthyr)  timeband(80) save(`"${outdir}/matches_repatriated_nysiis"')  replace id_A(id) id_B(id) keep_A(l_name f_name blobname) keep_B(l_name f_name) 


// merging in our name matches for repatriated
use "${outdir}/male_archive_ready2link.dta", clear 
gen blobname_A = blobname
cap drop _merge
merge 1:1 blobname_A using "${outdir}/matches_repatriated", keep(master match) keepusing(id_B)
rename id_B repatriation_id
gen repatriated =1  if repatriation_id != ""
replace repatriated = 0 if repatriation_id ==""
//rename hiscnew hiscnew_1918
save "${outdir}/male_died_repatriated_archive_rd2l.dta", replace

preserve
keep if BPL == 453
save "${outdir}/453_archive_ready2link.dta", replace 
restore

keep if BPL == 450 | BPL == 454
save "${outdir}/450_archive_ready2link.dta", replace 


