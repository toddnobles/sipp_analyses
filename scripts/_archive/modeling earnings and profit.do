webdoc init modeling earnings and profit, replace logall
webdoc toc 5

/***
<html>
<head><title>Preliminary models of earnings, profit and business value </title></head>
<p> Goals of analysis: 
Models (Earnings): Run models 1 and 2 for each comparison groups: 
(1) those who started as wage and salary ve rsus those who entered wage and salary from unemployment, 
(2) those who started as self employed versus those who entered self employment from unemployed, 
(3) those who entered self employment from being unemployed versus those who entered self employment from a wage and salary job

M1:
Earnings = those who started as wage and salary versus those who entered wage and salary from unemployment (base model)

M2:
M1+ controls (demographic characteristics + industry + year)

Models (Profit and business value)
M1: 
profit/business value = those who started as wage and salary versus those who entered wage and salary from unemployment (base model)

M2:
M1+ controls (demographic characteristics + industry + year </p>
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


