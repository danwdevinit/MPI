********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Bangladesh DHS 2014 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m

*** Working Folder Path ***
global path_in G:/My Drive/Work/GitHub/MPI/project_data/DHS MICS data files
global path_out G:/My Drive/Work/GitHub/MPI/project_data/MPI out
global path_ado G:/My Drive/Work/GitHub/MPI/project_data/ado


********************************************************************************
*** BANGLADESH DHS 2014 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
********************************************************************************
	
/*The Bangladesh DHS 2014 collected anthropometric data on the nutritional 
status of children by measuring the height and weight of all children under age 
5 in the sampled households (p.152). Page 170 of the report suggest that the
survey measured the height and weight of all ever-married women age 15-49 who
were sampled. Anthropometric information was not collected from men */


********************************************************************************
*** Step 1.1 PR - INDIVIDUAL RECODE
*** (Children under 5 years) 
********************************************************************************

use "$path_in/BDPR72FL.DTA", clear 


*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id

duplicates report ind_id

count if hv105<5
tab hv120,miss	
	/*8,325 children under 5 are eligible for anthropometric 
	measurement. */	
count if hc1!=.
	//All 8,325 children under 5 have information on age in months
tab hv105 if hc1!=.
	/*A cross check with the age in years reveal that all are within the 5 year 
	age group */
tab hc13 if hv120==1, miss
	//7,440 (89.37%) of the 8,325 children have been measured
tab hc13 if hc3<=9990, miss
tab hc13 if hc2<=9990, miss
	/*For example, height and weight data is available for all 7,440 children 
	who have been successfully measured */

	/*Following the checks carried out above, we keep only eligible children in
	this section since the interest is to generate measures for children under 
	5*/
keep if hv120==1
count	
	//8,325 children under 5		
	
	
*** Check variables that WHO ado needs to calculate the z-scores:

*** Variable: SEX ***
desc hc27 hv104
	/*hc27=sex of the child from biomarker questionnaire;
	hv104=sex from household roaster */
compare hc27 hv104
	//hc27 should match with hv104
tab hc27, miss 
	//"1" for male ;"2" for female 
tab hc27, nol 
clonevar gender = hc27
desc gender
tab gender


*** Variable: AGE ***
tab hc1, miss  
codebook hc1 
clonevar age_months = hc1  
desc age_months
sum age_months

gen mdate = mdy(hc18, hc17, hc19)
gen bdate = mdy(hc30, hc16, hc31) if hc16 <= 31
	//Calculate birth date in days from date of interview
replace bdate = mdy(hc30, 15, hc31) if hc16 > 31 
	//If date of birth of child has been expressed as more than 31, we use 15
gen age = (mdate-bdate)/30.4375 
	//Calculate age in months with days expressed as decimals
	
gen  str6 ageunit = "months" 
lab var ageunit "Months"

	
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook hc2, tab (9999)
gen	weight = hc2/10 
	//We divide it by 10 in order to express it in kilograms 
tab hc2 if hc2>9990, miss nol   
	//Missing values are 9994 to 9996
replace weight = . if hc2>=9990 
	//All missing values or out of range are replaced as "."
tab	hc13 hc2 if hc2>=9990 | hc2==., miss 
	//hw13: result of the measurement 
sum weight


*** Variable: HEIGHT (CENTIMETERS)
codebook hc3, tab (9999)
gen	height = hc3/10 
	//We divide it by 10 in order to express it in centimeters
tab hc3 if hc3>9990, miss nol   
	//Missing values are 9994 to 9996
replace height = . if hc3>=9990 
	//All missing values or out of range are replaced as "."
tab	hc13 hc3   if hc3>=9990 | hc3==., miss 
sum height


*** Variable: MEASURED STANDING/LYING DOWN ***	
codebook hc15
gen measure = "l" if hc15==1 
	//Child measured lying down
replace measure = "h" if hc15==2 
	//Child measured standing up
replace measure = " " if hc15==9 | hc15==0 | hc15==. 
	//Replace with " " if unknown
tab measure


*** Variable: OEDEMA ***
lookfor oedema
gen  oedema = "n"  
	//It assumes no-one has oedema
tab oedema	


*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores of a child. 
	So we assume all children in the sample have the same sample weight */
gen sw = 1	
sum sw


*** Indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: http://www.who.int/childgrowth/software/en/
adopath + "$path_ado/igrowup_stata"

*** We will now proceed to create three nutritional variables: 
	*** weight-for-age (underweight),  
	*** weight-for-height (wasting) 
	*** height-for-age (stunting)

/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Child Growth Standards are stored.*/	
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"

/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"

/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file (datalab_z_r_rc and datalab_prev_rc)*/
gen str30 datalab = "children_nutri_bgd" 
lab var datalab "Working file"
	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age ageunit weight height ///
measure oedema sw

/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_bgd_z_rc.dta", clear 

	
*** Standard MPI indicator ***
	//Takes value 1 if the child is under 2 stdev below the median & 0 otherwise
	
gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"
tab underweight, miss


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"
tab stunting, miss


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"
tab wasting, miss


count if _fwei==1 | _flen==1 	
	/* 112 children were replaced as missing because they have extreme 
	z-scores which are biologically implausible. */
 

gen child_PR=1 
	//Identification variable for children under 5 in PR recode 	
 
 
	//Retain relevant variables:
keep ind_id child_PR underweight* stunting* wasting* 
order ind_id child_PR underweight* stunting* wasting* 
sort ind_id
save "$path_out/BGD14_PR_child.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_bgd_z_rc.xls"
erase "$path_out/children_nutri_bgd_prev_rc.xls"
erase "$path_out/children_nutri_bgd_z_rc.dta"


********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/

use "$path_in/BDBR72FL.DTA", clear

		
*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"


desc b3 b7	
gen date_death = b3 + b7
	//Date of death = date of birth (b3) + age at death (b7)
gen mdead_survey = v008 - date_death
	//Months dead from survey = Date of interview (v008) - date of death
gen ydead_survey = mdead_survey/12
	//Years dead from survey

	
gen age_death = b7	
label var age_death "Age at death in months"
tab age_death, miss
	//Check whether the age is in months

	
codebook b5, tab (10)	
gen child_died = 1 if b5==0
	//1=child dead; 0=child alive
replace child_died = 0 if b5==1
replace child_died = . if b5==.
label define lab_died 1 "child has died" 0 "child is alive"
label values child_died lab_died
tab b5 child_died, miss

	
	/*NOTE: For each woman, sum the number of children who died and compare to 
	the number of sons/daughters whom they reported have died */
bysort ind_id: egen tot_child_died = sum(child_died) 
egen tot_child_died_2 = rsum(v206 v207)
	//v206: sons who have died; v207: daughters who have died
compare tot_child_died tot_child_died_2
	//Bangladesh DHS 2014: these figures are identical

	
	//Identify child under 18 mortality in the last 5 years
gen child18_died = child_died 
replace child18_died=0 if age_death>=216 & age_death<.
label values child18_died lab_died
tab child18_died, miss	
			
bysort ind_id: egen tot_child18_died_5y=sum(child18_died) if ydead_survey<=5
	/*Total number of children under 18 who died in the past 5 years 
	prior to the interview date */	
	
replace tot_child18_died_5y=0 if tot_child18_died_5y==. & tot_child_died>=0 & tot_child_died<.
	/*All children who are alive or who died longer than 5 years from the 
	interview date are replaced as '0'*/
	
replace tot_child18_died_5y=. if child18_died==1 & ydead_survey==.
	//Replace as '.' if there is no information on when the child died  

tab tot_child_died tot_child18_died_5y, miss

bysort ind_id: egen childu18_died_per_wom_5y = max(tot_child18_died_5y)
lab var childu18_died_per_wom_5y "Total child under 18 death for each women in the last 5 years (birth recode)"
	

	//Keep one observation per women
bysort ind_id: gen id=1 if _n==1
keep if id==1
drop id
duplicates report ind_id 

gen women_BR = 1 
	//Identification variable for observations in BR recode

	
	//Retain relevant variables
keep ind_id women_BR childu18_died_per_wom_5y 
order ind_id women_BR childu18_died_per_wom_5y
sort ind_id
save "$path_out/BGD14_BR.dta", replace		

	
		
********************************************************************************
*** Step 1.3  IR - WOMEN's RECODE  
*** (Eligible female 15-49 years in the household)
********************************************************************************
/*The purpose of step 1.3 is to identify all deaths that are reported by 
eligible women.*/

/*Do note, that the Bangladesh DHS 2014 IR file is only limited to women who 
ever married. This aligns with the statement in the report: "..the survey 
selected 18,000 residential households, which were expected to result in 
completed interviews with about 18,000 ever-married women (p.5) */

use "$path_in/BDIR72FL.DTA", clear
	
	
*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

tab v012, miss
codebook v201 v206 v207,tab (999)
	/*Bangladesh DHS 2014: Fertility and mortality question was only 
	collected from women 15-49 years.*/

gen women_IR=1 
	//Identification variable for observations in IR recode


//Marital status of household member (women)
/*Usually this information is extracted from the PR file. However, there is no
marital information in the Bangladesh DHS 2014 PR file. Hence we construct it 
using information from women's file.*/ 
clonevar marital = v501 
codebook marital, tab (10)
recode marital (0=1)(1=2)(8=.)
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member (women)"
tab v501 marital, miss


keep ind_id women_IR v003 v005 v012 v201 v206 v207 marital 
order ind_id women_IR v003 v005 v012 v201 v206 v207 marital 
sort ind_id
save "$path_out/BGD14_IR.dta", replace
	

********************************************************************************
*** Step 1.4  PR - INDIVIDUAL RECODE  
*** (Girls 15-19 years in the household)
********************************************************************************
/*The purpose of step 1.4 is to compute bmi-for-age for girls 15-19 years. */

use "$path_in/BDPR72FL.DTA", clear
	
		
*** Generate individual unique key variable required for data merging using:
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


*** Identify anthropometric sample for girls
count if hv105>=15 & hv105<=19 & hv104==2 
	//4,905 girls 15-19 years
codebook hv116, tab (9)	
tab ha13 hv116 if hv105>=15 & hv105<=19 & hv104==2, miss
count if hv105>=15 & hv105<=19 & hv104==2 & hv116>=1 & hv116<=2
	/*Total number of ever-married gilrs 15-19 years who have 
	anthropometric data and were selected for the biomarker 
	questionnaire: 2,306 */
tab ha13 hv117 if hv105>=15 & hv105<=19 & hv104==2 & hv116>=1 & hv116<=2, miss
tab ha13 hv103 if hv105>=15 & hv105<=19 & hv104==2 & hv116>=1 & hv116<=2, miss
	/*246 of the 2,306 women 15-19 years are identified as non-eligible
	for the female interview as they did not sleep the night before in the 
	household. Hence they will not have data on child mortality but they have 
	anthropometric information as they were covered in the biomarker 
	questionnaire. */
	
		
*** Keep relevant sample	
keep if hv105>=15 & hv105<=19 & hv104==2 & hv116>=1 & hv116<=2 
count
	//Total girls 15-19 years: 2,306

	
***Variables required to calculate the z-scores to produce BMI-for-age:

*** Variable: SEX ***
codebook hv104, tab (9)
clonevar gender = hv104
	//2:female 


*** Variable: AGE ***
desc hv008 ha32
gen age_month = hv008 - ha32
lab var age_month "Age in months, individuals 15-19 years (girls)"
tab age_month, miss	
	/*Note: For a couple of observations, we find that the age in months is 
	beyond 228 months. In this secton, while calculating the z-scores, these 
	cases will be excluded. However, in section 2.3, we will take the BMI 
	information of these girls. */

	
*** Variable: AGE UNIT ***
gen str6 ageunit = "months" 
lab var ageunit "Months"

			
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook ha2, tab (9999)
count if ha2>9990 
tab ha13 if ha2>9990, miss
gen weight = ha2/10 if ha2<9990
	/*Weight information from girls. We divide it by 10 in order to express 
	it in kilograms. Missing values or out of range are identified as "." */	
sum weight


*** Variable: HEIGHT (CENTIMETERS)	
codebook ha3, tab (9999)
count if ha3>9990 
tab ha13 if ha3>9990, miss
gen height = ha3/10 if ha3<9990
	/*Height information from girls. We divide it by 10 in order to express 
	it in centimeters. Missing values or out of range are identified as "." */
sum height


*** Variable: OEDEMA
	// We assume all individuals in the sample have no oedema
gen oedema = "n"  
tab oedema	


*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores. We 
	assume all individuals in the sample have the same sample weight */
gen sw = 1
sum sw

					
/* 
For this part of the do-file we use the WHO AnthroPlus software. This is to 
calculate the z-scores for young individuals aged 15-19 years. 
Source of ado file: https://www.who.int/growthref/tools/en/
*/

*** Indicate to STATA where the igrowup_restricted.ado file is stored:	
adopath + "$path_ado/who2007_stata"

	
/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Growth reference are stored. Note that we use strX to specify 
the length of the path in string. */		
gen str100 reflib = "$path_ado/who2007_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA data
set containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file*/
gen str30 datalab = "girl_nutri_bgd" 
lab var datalab "Working file"
	

/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/girl_nutri_bgd_z.dta", clear 

	
gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
lab var z_bmi "z-score bmi-for-age WHO"


*** Standard MPI indicator ***
	/*Takes value 1 if BMI-for-age is under 2 stdev below the median & 0 
	otherwise */	
gen	low_bmiage = (z_bmi < -2.0) 
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"


gen girl_PR=1 
	//Identification variable for girls 15-19 years in PR recode 


	//Retain relevant variables:	
keep ind_id girl_PR age_month low_bmiage*
order ind_id girl_PR age_month low_bmiage*
sort ind_id
save "$path_out/BGD14_PR_girls.dta", replace


	//Erase files from folder:
erase "$path_out/girl_nutri_bgd_z.xls"
erase "$path_out/girl_nutri_bgd_prev.xls"
erase "$path_out/girl_nutri_bgd_z.dta"


********************************************************************************
*** Step 1.5  MR - MEN'S RECODE  
********************************************************************************
	
	/*Note: There is no male recode file for Bangladesh DHS 2014. Hence the 
	commands under this section have been removed */

********************************************************************************
*** Step 1.6  MR - MEN'S RECODE  
***(Boys 15-19 years in the household) 
********************************************************************************

	/*Note: There is no male recode file for Bangladesh DHS 2014. Hence the 
	commands under this section have been removed */

	
********************************************************************************
*** Step 1.7  PR - HOUSEHOLD MEMBER'S RECODE 
********************************************************************************

use "$path_in/BDPR72FL.DTA", clear

*** Generate a household unique key variable at the household level using: 
	***hv001=cluster number 
	***hv002=household number
gen double hh_id = hv001*10000 + hv002 
format hh_id %20.0g
label var hh_id "Household ID"
codebook hh_id  



*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


sort hh_id ind_id


********************************************************************************
*** Step 1.8 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BGD14_BR.dta"
drop _merge
erase "$path_out/BGD14_BR.dta"


*** Merging IR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BGD14_IR.dta"
tab women_IR hv117, miss col
tab ha65 if hv117==1 & women_IR ==., miss 
	//Total number of eligible women not interviewed
drop _merge
erase "$path_out/BGD14_IR.dta"


/*Check if the number of women in BR recode matches the number of those
who provided birth history information in IR recode. */
count if women_BR==1
count if v201!=0 & v201!=. & women_IR==1


/*Check if the number of women in BR and IR recode who provided birth history 
information matches with the number of eligible women identified by hv117. */
count if hv117==1
count if women_BR==1 | v201==0
count if (women_BR==1 | v201==0) & hv117==1
tab v201 if hv117==1, miss
*tab v201 ha65 if hv117==1, miss
	/*Note: Some 2.09% eligible women did not provide information on their birth 
	history as they were not interviewed. This will result in missing value 
	for the child mortality indicator that we will construct later */


*** Merging 15-19 years: girls 
*****************************************
merge 1:1 ind_id using "$path_out/BGD14_PR_girls.dta"
tab ha13 girl_PR if hv105>=15 & hv105<=19 & hv104==2 &hv116>=1 & hv116<=2, miss col
drop _merge
erase "$path_out/BGD14_PR_girls.dta"

		
*** Merging child under 5 
*****************************************
merge 1:1 ind_id using "$path_out/BGD14_PR_child.dta"
tab hv120, miss  
tab hc13 if hv120==1, miss
drop _merge
erase "$path_out/BGD14_PR_child.dta"


sort ind_id
	
	
********************************************************************************
*** Step 1.9 KEEPING ONLY DE JURE HOUSEHOLD MEMBERS ***
********************************************************************************

//Permanent (de jure) household members 
clonevar resident = hv102 
codebook resident, tab (10) 
label var resident "Permanent (de jure) household member"

drop if resident!=1 
tab resident, miss
	/*Note: The Global MPI is based on de jure (permanent) household members 
	only. As such, non-usual residents will be excluded from the sample. 
	In the context of Bangladesh DHS 2014, 3,939 (4.83%) individuals who were 
	non-usual residents were dropped from the sample
	*/

	
********************************************************************************
*** Step 1.10 SUBSAMPLE VARIABLE ***
********************************************************************************

/*
In the context of Bangladesh DHS 2014, height and weight measurements were
collected from all children (0-5) and women (15-49) who were sampled. Hence in
this context there is no subsample selection 
*/
gen subsample = .
label var subsample "Households selected as part of nutrition subsample" 
tab subsample, miss	


********************************************************************************
*** Step 1.11 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years or adult women 15-49 years. 
These households will not have information on relevant indicators of health. 
As such, these households are considered as non-deprived in those relevant 
indicators.*/


*** No eligible women 15-49 years 
*** for adult nutrition indicator
***********************************************
tab ha13 if hv105>=15 & hv105<=19 & hv104==2 & hv116>=1 & hv116<=2, miss
gen fem_nutri_eligible = (ha13!=.)
tab fem_nutri_eligible, miss
bysort hh_id: egen hh_n_fem_nutri_eligible = sum(fem_nutri_eligible) 	
gen	no_fem_nutri_eligible = (hh_n_fem_nutri_eligible==0)
	//Takes value 1 if the household had no eligible women for anthropometrics
lab var no_fem_nutri_eligible "Household has no eligible women for anthropometric"	
drop fem_nutri_eligible hh_n_fem_nutri_eligible
tab no_fem_nutri_eligible, miss


*** No eligible women 15-49 years 
*** for child mortality indicator
*****************************************
gen	fem_eligible = (hv117==1)
bysort	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible women for an interview
lab var no_fem_eligible "Household has no eligible women for interview"
drop fem_eligible hh_n_fem_eligible 
tab no_fem_eligible, miss


*** No eligible men 
*** for adult nutrition indicator (if relevant)
***********************************************
	//Note: There is no male recode file for Bangladesh DHS 2014
gen	no_male_nutri_eligible = .
lab var no_male_nutri_eligible "Household has no eligible men for anthropometric"	


*** No eligible men 
*** for child mortality indicator (if relevant)
*****************************************
	//Note: There is no male recode file for Bangladesh DHS 2014
gen no_male_eligible = . 
lab var no_male_eligible "Household has no eligible man"


*** No eligible children under 5
*** for child nutrition indicator
*****************************************
gen	child_eligible = (hv120==1) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible for anthropometric"
drop child_eligible hh_n_children_eligible
tab no_child_eligible, miss


*** No eligible women and men 
*** for adult nutrition indicator
***********************************************
		/*There is no male recode file for Bangladesh DHS 2014. So 
		this variable is only made up of eligible adult women */
gen	no_adults_eligible = (no_fem_nutri_eligible==1) 
lab var no_adults_eligible "Household has no eligible women or men for anthropometrics"
tab no_adults_eligible, miss 


*** No Eligible Children and Women
*** for child and women nutrition indicator 
***********************************************
gen	no_child_fem_eligible = (no_child_eligible==1 & no_fem_nutri_eligible==1)
lab var no_child_fem_eligible "Household has no children or women eligible for anthropometric"
tab no_child_fem_eligible, miss 


*** No Eligible Women, Men or Children 
*** for nutrition indicator 
***********************************************
		/*There is no male recode file for Bangladesh DHS 2014. So 
		this variable is only made up of eligible adult women and 
		children */
gen no_eligibles = (no_fem_nutri_eligible==1 & no_child_eligible==1)
lab var no_eligibles "Household has no eligible women, men, or children"
tab no_eligibles, miss


sort hh_id ind_id


********************************************************************************
*** Step 1.12 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
desc hv005
clonevar weight = hv005 
label var weight "Sample weight"


//Area: urban or rural	
desc hv025
codebook hv025, tab (5)		
clonevar area = hv025  
replace area=0 if area==2  
	//Redefine the coding and labels to 1/0
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Sex of household member	
codebook hv104
clonevar sex = hv104 
label var sex "Sex of household member"


//Age of household member
codebook hv105, tab (100)
clonevar age = hv105  
replace age = . if age>=98
label var age "Age of household member"


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhs "Household size"
tab hhsize, miss
drop member


//Subnational region
	/*NOTE: The sample for the Bangladesh DHS 2014 was designed to provide 
	estimates of key indicators for the country as a whole, for urban and rural 
	areas separately, and for each of the for each of the seven divisions (p.5).*/ 
lookfor region division
codebook hv024, tab (100)
clonevar region = hv024
lab var region "Region for subnational decomposition"



********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

codebook hv108, tab(30)
clonevar  eduyears = hv108   
	//Total number of years of education
replace eduyears = . if eduyears>30
	//Recode any unreasonable years of highest education as missing value
replace eduyears = . if eduyears>=age & age>0
	/*The variable "eduyears" was replaced with a '.' if total years of 
	education was more than individual's age */
replace eduyears = 0 if age < 10 
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */

	
	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 
	10 years and older */	
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bysort	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 10 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=10 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are 10 years and older 
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
tab no_missing_edu, miss
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"		
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no household member 
aged 10 years or older has completed SIX years of schooling.*/
******************************************************************* 
gen	 years_edu6 = (eduyears>=6)
	/* The years of schooling indicator takes a value of "1" if at least someone 
	in the hh has reported 6 years of education or more */
replace years_edu6 = . if eduyears==.
bysort hh_id: egen hh_years_edu6_1 = max(years_edu6)
gen	hh_years_edu6 = (hh_years_edu6_1==1)
replace hh_years_edu6 = . if hh_years_edu6_1==.
replace hh_years_edu6 = . if hh_years_edu6==0 & no_missing_edu==0 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

codebook hv121, tab (10)
clonevar attendance = hv121 
recode attendance (2=1) 
codebook attendance, tab (10)	
replace attendance = 0 if (attendance==9 | attendance==.) & hv109==0 
	/*In some countries, they don't assess attendance for those with no 
	 educational attainment. These are replaced with a '0' */
replace attendance = . if  attendance==9 & hv109!=0
	//Replace missing values
	


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
	/*In Bangladesh, the official school entrance age is 6 years.  
	  So, age range is 6-14 (=6+8) 
	  Source: "http://data.uis.unesco.org/?ReportId=163" */

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 
gen temp = 1 if child_schoolage==1 & attendance!=.
	/*Generate a variable that captures the number of eligible school aged 
	children who are attending school */
bysort hh_id: egen no_missing_atten = sum(temp)	
	/*Total school age children with no missing information on school 
	attendance */
gen temp2 = 1 if child_schoolage==1	
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are of school age
replace no_missing_atten = no_missing_atten/hhs 
replace no_missing_atten = (no_missing_atten>=2/3)
	/*Identify whether there is missing information on school attendance for 
	more than 2/3 of the school age children */			
tab no_missing_atten, miss
label var no_missing_atten "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs
		
bysort	hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
	//Control variable: 
	//It takes value 1 if the household has children in school age
lab var hh_children_schoolage "Household has children in school age"

gen	child_not_atten = (attendance==0) if child_schoolage==1
replace child_not_atten = . if attendance==. & child_schoolage==1
bysort	hh_id: egen any_child_not_atten = max(child_not_atten)
gen	hh_child_atten = (any_child_not_atten==0) 
replace hh_child_atten = . if any_child_not_atten==.
replace hh_child_atten = 1 if hh_children_schoolage==0
replace hh_child_atten = . if hh_child_atten==1 & no_missing_atten==0 
	/*If the household has been intially identified as non-deprived, but has 
	missing school attendance for at least 2/3 of the school aged children, then 
	we replace this household with a value of '.' because there is insufficient 
	information to conclusively conclude that the household is not deprived */
lab var hh_child_atten "Household has all school age children up to class 8 in school"
tab hh_child_atten, miss


/*Note: The indicator takes value 1 if ALL children in school age are attending 
school and 0 if there is at least one child not attending. Households with no 
children receive a value of 1 as non-deprived. The indicator has a missing value 
only when there are all missing values on children attendance in households that 
have children in school age. */


********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************

********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************
	//Bangladesh DHS 2014 has BMI data only for women 15-49 years. 

foreach var in ha40  {
			 gen inf_`var' = 1 if `var'!=.
			 bysort sex: tab age inf_`var' 
			 drop inf_`var'
			 //Eligible women: 15-49 years
			 }
***

*** BMI Indicator for Women 15-49 years ***
******************************************************************* 
gen	f_bmi = ha40/100
lab var f_bmi "Women's BMI"
gen	f_low_bmi = (f_bmi<18.5)
replace f_low_bmi = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi "BMI of women < 18.5"

gen	f_low_bmi_u = (f_bmi<17)
replace f_low_bmi_u = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi_u "BMI of women <17"
	//Note: The BMI threshold applied for destitution is 17 instead of 18.5


*** BMI Indicator for Men ***
******************************************************************* 
	//Bangladesh DHS 2014 has no anthropometric data for men. 
	
gen m_bmi = .
lab var m_bmi "Male's BMI"
gen m_low_bmi = .
lab var m_low_bmi "BMI of male < 18.5"

gen m_low_bmi_u = .
lab var m_low_bmi_u "BMI of male <17"



*** Standard MPI: BMI-for-age for individuals 15-19 years 
*** 				  and BMI for individuals 20-49 years ***
*******************************************************************  
gen low_bmi_byage = 0
lab var low_bmi_byage "Individuals with low BMI or BMI-for-age"
replace low_bmi_byage = 1 if f_low_bmi==1
	//Replace variable "low_bmi_byage = 1" if eligible women have low BMI	
replace low_bmi_byage = 1 if low_bmi_byage==0 & m_low_bmi==1 
	/*Replace variable "low_bmi_byage = 1" if eligible men have low BMI. If 
	there is no male anthropometric data, then 0 changes are made.*/

	
/*Note: The following command replaces BMI with BMI-for-age for those between 
the age group of 15-19 by their age in months where information is available */
	//Replacement for girls: 
replace low_bmi_byage = 1 if low_bmiage==1 & age_month!=.
replace low_bmi_byage = 0 if low_bmiage==0 & age_month!=.

	
/*Note: The following control variable is applied when there is BMI information 
for adults and BMI-for-age for teenagers.*/	
replace low_bmi_byage = . if f_low_bmi==. & m_low_bmi==. & low_bmiage==. 
		
bysort hh_id: egen low_bmi = max(low_bmi_byage)
gen	hh_no_low_bmiage = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age */	
replace hh_no_low_bmiage = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
replace hh_no_low_bmiage = 1 if no_adults_eligible==1	
	//Households take a value of '1' if there is no eligible adult population.
drop low_bmi
lab var hh_no_low_bmiage "Household has no adult with low BMI or BMI-for-age"
tab hh_no_low_bmiage, miss	

	/*NOTE that hh_no_low_bmiage takes value 1 if: (a) no any eligible 
	individuals in the household has (observed) low BMI or (b) there are no 
	eligible individuals in the household. The variable takes values 0 for 
	those households that have at least one adult with observed low BMI. 
	The variable has a missing value only when there is missing info on BMI 
	for ALL eligible adults in the household */


********************************************************************************
*** Step 2.3b Child Nutrition ***
********************************************************************************

*** Child Underweight Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(underweight)
gen	hh_no_underweight = (temp==0) 
	//Takes value 1 if no child in the hh is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_underweight "Household has no child underweight - 2 stdev"
drop temp


*** Child Stunting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0) 
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
drop temp


*** Child Either Underweight or Stunted Indicator ***
************************************************************************

*** Standard MPI ***
gen hh_no_uw_st = 1 if hh_no_stunting==1 & hh_no_underweight==1
replace hh_no_uw_st = 0 if hh_no_stunting==0 | hh_no_underweight==0
	//Takes value 0 if child in the hh is stunted or underweight 
replace hh_no_uw_st = . if hh_no_stunting==. & hh_no_underweight==.
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st "Household has no child underweight or stunted"


********************************************************************************
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* Members of the household are considered deprived if the household has a 
child under 5 whose height-for-age or weight-for-age is under two standard 
deviation below the median, or has teenager with BMI-for-age that is under two 
standard deviation below the median, or has adults with BMI threshold that is 
below 18.5 kg/m2. Households that have no eligible adult AND no eligible 
children are considered non-deprived. The indicator takes a value of missing 
only if all eligible adults and eligible children have missing information 
in their respective nutrition variable. */
************************************************************************

gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_low_bmiage==0 | hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_low_bmiage==. & hh_no_uw_st==.
	/*Replace indicator as missing if household has eligible adult and child 
	with missing nutrition information */
replace hh_nutrition_uw_st = . if hh_no_low_bmiage==. & hh_no_uw_st==1 & no_child_eligible==1
	/*Replace indicator as missing if household has eligible adult with missing 
	nutrition information and no eligible child for anthropometric measures */ 
replace hh_nutrition_uw_st = . if hh_no_uw_st==. & hh_no_low_bmiage==1 & no_adults_eligible==1
	/*Replace indicator as missing if household has eligible child with missing 
	nutrition information and no eligible adult for anthropometric measures */ 
replace hh_nutrition_uw_st = 1 if no_eligibles==1  
 	/*We replace households that do not have the applicable population, that is, 
	women 15-49 & children 0-5, as non-deprived in nutrition*/
lab var hh_nutrition_uw_st "Household has no individuals malnourished"
tab hh_nutrition_uw_st, miss


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook v206 v207 
	//v206: number of sons who have died 
	//v207: number of daughters who have died
	

	//Total child mortality reported by eligible women
egen temp_f = rowtotal(v206 v207), missing
replace temp_f = 0 if v201==0
replace temp_f = 0 if hv116==0 & hv104==2 & hv105>=15 & hv105<=49
	//This line replaces never married women for whom the data was not collected
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	
	//Total child mortality reported by eligible men: no male recode
gen child_mortality_m = .
lab var child_mortality_m "Occurrence of child mortality reported by men"

egen child_mortality = rowmax(child_mortality_f)
lab var child_mortality "Total child mortality within household"
tab child_mortality, miss	
	
	
*** Standard MPI *** 
/* Members of the household are considered deprived if women in the household 
reported mortality among children under 18 in the last 5 years from the survey 
year. Members of the household is considered non-deprived if eligible women 
within the household reported (i) no child mortality or (ii) if any child died 
longer than 5 years from the survey year or (iii) if any child 18 years and 
older died in the last 5 years. In adddition, members of the household were 
identified as non-deprived if eligible men within the household reported no 
child mortality in the absence of information from women. Households that have 
no eligible women or adult are considered non-deprived. The indicator takes 
a missing value if there was missing information on reported death from 
eligible individuals. */
************************************************************************

tab childu18_died_per_wom_5y, miss
	/* The 'childu18_died_per_wom_5y' variable was constructed in Step 1.2 using 
	information from individual women who ever gave birth in the BR file. The 
	missing values represent eligible woman who have never ever given birth and 
	so are not present in the BR file. But these 'missing women' may be living 
	in households where there are other women with child mortality information 
	from the BR file. So at this stage, it is important that we aggregate the 
	information that was obtained from the BR file at the household level. This
	ensures that women who were not present in the BR file is assigned with a 
	value, following the information provided by other women in the household.*/
replace childu18_died_per_wom_5y = 0 if v201==0 
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */
replace childu18_died_per_wom_5y = 0 if hv116==0 & hv104==2 & hv105>=15 & hv105<=49
	/*This line replaces never-married women with 0 child death. 
	Child mortality information was only collected from ever-married 
	women.*/		
replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1 
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */	
	
bysort hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
	/*Replace all households as 0 death if women has missing value and men 
	reported no death in those households */
label var childu18_mortality_5y "Under 18 child mortality within household past 5 years reported by women"
tab childu18_mortality_5y, miss		
	
gen hh_mortality_u18_5y = (childu18_mortality_5y==0)
replace hh_mortality_u18_5y = . if childu18_mortality_5y==.
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"
tab hh_mortality_u18_5y, miss 


********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************

*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************
clonevar electricity = hv206 
codebook electricity, tab (10)
replace electricity = . if electricity==9 
label var electricity "Electricity"

 
********************************************************************************
*** Step 2.6 Sanitation ***
********************************************************************************

/*
Improved sanitation facilities include flush or pour flush toilets to sewer 
systems, septic tanks or pit latrines, ventilated improved pit latrines, pit 
latrines with a slab, and composting toilets. These facilities are only 
considered improved if it is private, that is, it is not shared with other 
households.
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-02-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/

clonevar toilet = hv205  
codebook toilet, tab(30) 
codebook hv225, tab(30)  
clonevar shared_toilet = hv225 


*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
gen	toilet_mdg = ((toilet<23 | toilet==41) & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
replace toilet_mdg = 0 if (toilet<23 | toilet==41)  & shared_toilet==1   
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */	
	
replace toilet_mdg = 0 if toilet == 14 | toilet == 15
	/*Household is assigned a value of '0' if it uses non-improved sanitation: 
	"flush to somewhere else" and "flush don't know where"  */	

replace toilet_mdg = . if toilet==.  | toilet==99
	//Household is assigned a value of '.' if it has missing information 	
	
lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab toilet toilet_mdg, miss



********************************************************************************
*** Step 2.7 Drinking Water  ***
********************************************************************************

/*
Improved drinking water sources include the following: piped water into 
dwelling, yard or plot; public taps or standpipes; boreholes or tubewells; 
protected dug wells; protected springs; packaged water; delivered water and 
rainwater which is located on premises or is less than a 30-minute walk from 
home roundtrip. 
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-01-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/


clonevar water = hv201  
clonevar timetowater = hv204  
codebook water, tab(100)
clonevar ndwater = hv202  
	//Non-drinking water: no observation

	
*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==21 | ///
					 water==31 | water==41 | water==51 | water==71
	/*Non deprived if water is piped into dwelling, piped to yard/plot, 
	  public tap/standpipe, tube well or borehole, protected well, 
	  protected spring, rainwater, bottled water */
	
replace water_mdg = 0 if water==32 | water==42 | water==43 | ///
						 water==61 | water==62 | water==96 
	/*Deprived if it is unprotected well, unprotected spring, tanker truck
	  surface water (river/lake, etc), cart with small tank, other */
	
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=996 & timetowater!=998 & timetowater!=999 
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 

replace water_mdg = . if water==. | water==99
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss
	
	

********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hv213 
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor<=11 | floor==96  
	//Deprived if mud/earth, sand, dung, other 
replace floor_imp = . if floor==. | floor==99 	
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	



/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
clonevar wall = hv214 
codebook wall, tab(99)	
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=25 | wall==96  
	/*Deprived if no wall, cane/palms/trunk, mud/dirt, 
	grass/reeds/thatch, pole/bamboo with mud, stone with mud, plywood,
	cardboard, carton/plastic, uncovered adobe, canvas/tent, 
	unburnt bricks, reused wood, other */	
replace wall_imp = . if wall==. | wall==99 	
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = hv215
codebook roof, tab(99)	
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=24 | roof==96  
	/*Deprived if no roof, thatch/palm leaf, mud/earth/lump of earth, 
	sod/grass, plastic/polythene sheeting, rustic mat, cardboard, 
	canvas/tent, wood planks/reused wood, unburnt bricks, other */		
replace roof_imp = . if roof==. | roof==99 	
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss
	
	
*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************
gen housing_1 = 1
replace housing_1 = 0 if floor_imp==0 | wall_imp==0 | roof_imp==0
replace housing_1 = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_1 "Household has roof, floor & walls that it is not low quality material"
tab housing_1, miss

	
********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************

/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

clonevar cookingfuel = hv226  
codebook cookingfuel, tab(99)


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel by MDG standards"
	/* Deprived if: coal/lignite, charcoal, wood, straw/shrubs/grass, 
					agricultural crop, animal dung */		 
tab cookingfuel cooking_mdg, miss	



********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */


*** Television/LCD TV/plasma TV/color TV/black & white tv
codebook hv208
clonevar television = hv208 
lab var television "Household has television"	


***	Radio/walkman/stereo/kindle
codebook hv207
clonevar radio = hv207 
lab var radio "Household has radio"	



***	Handphone/telephone/iphone/mobilephone/ipod
lookfor telephone téléphone mobilephone ipod
codebook hv221 hv243a
clonevar telephone = hv221
replace telephone=1 if telephone!=1 & hv243a==1	
	//hv243a=mobilephone. Combine information on telephone and mobilephone.	
tab hv243a hv221 if telephone==1,miss
lab var telephone "Household has telephone (landline/mobilephone)"	


***	Refrigerator/icebox/fridge
codebook hv209
clonevar refrigerator = hv209 
lab var refrigerator "Household has refrigerator"


***	Car/van/lorry/truck
codebook hv212
clonevar car = hv212  
lab var car "Household has car"		


***	Bicycle/cycle rickshaw
codebook hv210	
clonevar bicycle = hv210 
lab var bicycle "Household has bicycle"	



***	Motorbike/motorized bike/autorickshaw
codebook hv211
clonevar motorbike = hv211 
lab var motorbike "Household has motorbike"	


***	Computer/laptop/tablet
codebook sh110n
clonevar computer = sh110n
lab var computer "Household has computer"		
		
		
***	Animal cart
codebook hv243c
	//Bangladesh DHS 2014: all missing value
clonevar animal_cart = hv243c
lab var animal_cart "Household has animal cart"	
		
		
foreach var in television radio telephone refrigerator car ///
			   bicycle motorbike computer animal_cart {
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Missing values replaced


*** Standard MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal cart and does not own a car or truck.*/
*****************************************************************************
egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 
   
gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"

		
********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************

	//Retain DHS wealth index:
desc hv270 	
clonevar windex=hv270

desc hv271
clonevar windexf=hv271


	//Retain data on sampling design: 
desc hv022 hv021	
clonevar strata = hv022
clonevar psu = hv021

	//Retain year, month & date of interview:
desc hv007 hv006 hv008
clonevar year_interview = hv007 	
clonevar month_interview = hv006 
clonevar date_interview = hv008


*** Rename key global MPI indicators for estimation ***
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_1 			(0=1)(1=0) , gen(d_hsg)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)
 

*** Generate coutry and survey details for estimation ***
char _dta[cty] "Bangladesh"
char _dta[ccty] "BGD"
char _dta[year] "2014" 	
char _dta[survey] "DHS"
char _dta[ccnum] "050"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(date) c(time)'."	
save "$path_out/bgd_dhs14.dta", replace 

