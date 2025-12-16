## SIPP Data Analyses 
This repository contains the code and instructions for reproducing the analyses examining the earnings penalty associated with unemployment for entrepeneurs using the SIPP data.  


### Data
The data can be downloaded from the SIPP website, or from this [Google Drive folder](https://drive.google.com/drive/folders/1yhev71lwjQFBPCUF5xfGoo1xuaksJ42Y?usp=sharing)]. See the data ingestion script for the specific files used if downloading from the SIPP website directly. 


### Scripts 
1. 1_data_intake.R
    This file combines and reshapes the raw SIPP data files. 
2. 2_data_prep.qmd
    This file cleans and filters to our working data set for analysis.
3. 3_working_paper_outputs.qmd
    This reproduces the analyses and exports descriptive tables and model outputs to an Excel document for viewing. 
4. 3_working_paper_outputs_10hrs.qmd
    Mirrored version of the above script running on a modified sample as robustness check for different working hours threshold.
4. model_coef_comparisons.do
    Compares changes in key coefficient for unemployment after we add in industry experience. See script notes for why we move to using Stata for this step. 
