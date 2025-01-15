library(data.table)

ds <- c("PU2014W1", "PU2014W2", "PU2014W3", "PU2014W4", "pu2018", "pu2019", "pu2020", "pu2021", "pu2022", "pu2023")

for (x in ds) {
  # at some point add in to only run this chunk if the data file date/time has changed. 
  cols <- colnames(fread(paste0("/Volumes/ExtremeSSD/SIPP Data Files/delims/",x, ".csv"), sep = "|", nrows = 0))
  newname <- paste0(tolower(x), "_monthly")
  print(newname)
  
  
  
  # handling annoying case inconsistencies in their coding.
  target_columns <- c('SSUID', 'PNUM', 'MONTHCODE', 'ERESIDENCEID', 'ERELRPE', 'SPANEL', 
                      'SWAVE', 'SHHADID', 'WPFINWGT', 'ESEX', 'TAGE', 'TAGE_EHC', 'ERACE', 
                      'EORIGIN', 'EEDUC', 'EMS', 'TCEB', 'EBORNUS', 'TDEBT_AST', 'THDEBT_AST', 
                      'TOEDDEBTVAL', 'TDEBT_CC', 'THDEBT_CC', 'TDEBT_ED', 'THDEBT_ED', 
                      'TDEBT_HOME', 'THDEBT_HOME', 'TDEBT_BUS', 'TTHR401VAL', 'TIRAKEOVAL', 
                      'TVAL_AST', 'THVAL_AST', 'TNETWORTH', 'THNETWORTH', 'TVAL_HOME', 
                      'THVAL_HOME', 'TEQ_HOME', 'THEQ_HOME', 'TEQ_BUS', 'TPTOTINC', 
                      'TPEARN', 'ENJFLAG', 'EPAR_SCRNR')
  
  # Match column names after coercing all to same case
  selected_columns <- cols[tolower(cols) %in% tolower(target_columns)]
  pu <- fread(paste0("/Volumes/ExtremeSSD/SIPP Data Files/delims/",x, ".csv"), 
              sep = "|", 
              select = c(selected_columns), data.table = FALSE)
  # Rename columns to lowercase
  names(pu) <- tolower(names(pu))
  assign(newname, pu)
  saveRDS(get(newname), paste0("/Volumes/ExtremeSSD/SIPP Data Files/rds/",newname,  ".rds"))
  rm(pu)
  
}



for (x in ds) {
  cols <- colnames(fread(paste0("/Volumes/ExtremeSSD/SIPP Data Files/delims/",x, ".csv"), sep = "|", nrows = 0))
  newname <- paste0(tolower(x), "_joblevel")
  print(newname)
  
  
  
  # handling annoying case inconsistencies in their coding.
  target_columns <- c('SSUID', 'PNUM', 'MONTHCODE', 'SPANEL', 'SWAVE', "TAGE")
  
  # Match column names after coercing all to same case
  selected_columns <- cols[tolower(cols) %in% tolower(target_columns)]
  
  # actually reading in the data now with our id cols and our job level vars 
  pu <- fread(paste0("/Volumes/ExtremeSSD/SIPP Data Files/delims/",x, ".csv"), 
              sep = "|", 
              select = c(selected_columns, 
                         grep("EJB\\d_JBORSE", cols, value = TRUE, ignore.case = TRUE),
                         grep("EJB\\d_CLWRK", cols, value = TRUE, ignore.case = TRUE),
                         grep("TJB\\d_EMPB", cols, value = TRUE, ignore.case = TRUE),
                         grep("EJB\\d_INCPB", cols, value = TRUE, ignore.case = TRUE),
                         grep("EJB\\d_JOBID", cols, value = TRUE, ignore.case = TRUE),
                         grep("AJB\\d_JOBID", cols, value = TRUE, ignore.case = TRUE),
                         grep("EJB\\d_STARTWK", cols, value = TRUE, ignore.case = TRUE),
                         grep("EJB\\d_ENDWK", cols, value = TRUE, ignore.case = TRUE),
                         grep("TJB\\d_MWKHRS", cols, value = TRUE, ignore.case = TRUE),
                         grep("TJB\\d_IND", cols, value = TRUE, ignore.case = TRUE),
                         grep("TJB\\d_OCC",cols, value = TRUE, ignore.case = TRUE),
                         grep("EJB\\d_TYPPAY1", cols, value = TRUE, ignore.case = TRUE),
                         grep("TJB\\d_GAMT1", cols, value = TRUE, ignore.case = TRUE),
                         grep("EJB\\d_BSLRYB",cols, value = TRUE, ignore.case = TRUE),
                         grep("TBSJ\\dVAL", cols, value = TRUE, ignore.case = TRUE),
                         grep("TJB\\d_PRFTB", cols, value = TRUE, ignore.case = TRUE),
                         grep("TJB\\d_MSUM", cols, value = TRUE, ignore.case = TRUE)),
              data.table = FALSE )
  
  # Rename columns to lowercase
  names(pu) <- tolower(names(pu))
  assign(newname, pu)
  saveRDS(get(newname), paste0("/Volumes/ExtremeSSD/SIPP Data Files/rds/",newname, ".rds"))
  rm(pu)
}


library(tidyverse)
sipp_monthly_combined <- bind_rows(pu2014w1_monthly %>% select(-eresidenceid),
                                   pu2014w2_monthly %>% select(-eresidenceid),
                                   pu2014w3_monthly%>% select(-eresidenceid),
                                   pu2014w4_monthly%>% select(-eresidenceid),
                                   pu2018_monthly %>% select(-eresidenceid),
                                   pu2019_monthly %>% select(-eresidenceid),
                                   pu2020_monthly %>% select(-eresidenceid),
                                   pu2021_monthly %>% select(-eresidenceid),
                                   pu2022_monthly %>% select(-eresidenceid),
                                   pu2023_monthly %>% select(-eresidenceid)
                                   )
saveRDS(sipp_monthly_combined, "/Volumes/ExtremeSSD/SIPP Data Files/rds/sipp_monthly_combined.rds")



sipp_joblevel_combined_wide <- bind_rows(pu2014w1_joblevel,
                                   pu2014w2_joblevel,
                                   pu2014w3_joblevel,
                                   pu2014w4_joblevel,
                                   pu2018_joblevel,
                                   pu2019_joblevel,
                                   pu2020_joblevel,
                                   pu2021_joblevel,
                                   pu2022_joblevel,
                                   pu2023_joblevel)


saveRDS(sipp_joblevel_combined_wide, "/Volumes/ExtremeSSD/SIPP Data Files/rds/sipp_joblevel_combined_wide.rds")
