********************************************************************************
/*
Suggested citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Laos MICS 2017 [STATA do-file]. 
Retrieved from: https://ophi.org.uk/multidimensional-poverty-index/mpi-resources/  

For further queries, please contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m


*** Working Folder Path ***
global path_in G:/My Drive/Work/GitHub/MPI//project_data/DHS MICS data files/Lao_PDR_MICS6_Datasets
global path_out G:/My Drive/Work/GitHub/MPI//project_data/MPI out
global path_ado G:/My Drive/Work/GitHub/MPI//project_data/ado

	
********************************************************************************
*** LAOS MICS 2017 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting main variables from CH, WM, HH & MN recode & merging with HL recode 
********************************************************************************

	
/* LAOS MICS 2017: Six questionnaires were used in the survey (p.3): 
1) a household questionnaire which was used to collect basic demographic 
information on all de jure household members (usual residents), the household,
 and the dwelling; 
2) a water quality testing questionnaire administered in three households 
in each cluster of the sample; 
3) a questionnaire for individual women administered in each household to 
all women age 15-49 years; 
4) a questionnaire for individual men administered in every second household 
to all men age 15-49 years; 
5) an under-5 questionnaire, administered to mothers (or caretakers) of all 
children under 5 living in the household; and 
6) a questionnaire for children age 5-17 years,  administered to the mother 
(or caretaker) of one randomly selected child age 5-17 years living in the 
household. 

Anthropometry measure and anemia test was collected from all children under 
5 years.*/ 


********************************************************************************
*** Step 1.1 CH - CHILD RECODE
*** (Children under 5 years) 
********************************************************************************
/*The purpose of step 1.1 is to compute anthropometric measures for children 
under 5 years.*/

use "$path_in/ch.dta", clear 

rename _all, lower	


*** Generate individual unique key variable required for data merging
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** ln=child's line number in household
gen double ind_id = hh1*1000000 + hh2*100 + ln 
format ind_id %20.0g
label var ind_id "Individual ID"


duplicates report ind_id   
	//no duplicates


gen child_CH=1 
	//Generate identification variable for observations in CH recode


*** Check the variables to calculate the z-scores:

*** Variable: SEX ***
codebook hl4, tab (9) 
	//"1" for male ;"2" for female 
clonevar gender = hl4
tab gender


*** Variable: AGE ***
desc cage caged
tab cage, miss
	//Age in months: information missing for 92 children
tab caged, miss
	/*Age in days: information missing for 92 children. We use age in days 
	as it result in more accurate anthropometric measures. */
clonevar age_days = caged
replace age_days = . if caged==9999 
count if caged < 0 	
replace age_days = trunc(cage*(365/12)) if caged < 0 
sum age_days

gen str6 ageunit = "days"
lab var ageunit "Days"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook an8, tab (9999)   
clonevar weight = an8	
replace weight = . if an8>=99 
tab uf17 an8 if an8>=99 | an8==., miss  
sum weight	


*** Variable: HEIGHT (CENTIMETERS)
codebook an11, tab (9999) 
clonevar height = an11
replace height = . if an11>=999 
tab	uf17 an4 if an11>=999 | an11==., miss  
sum height


	
*** Variable: MEASURED STANDING/LYING DOWN	
codebook an12  
gen measure = "l" if an12==1 
	//Child measured lying down
replace measure = "h" if an12==2 
	//Child measured standing up
replace measure = " " if an12==9 | an12==0 | an12==. 
	//Replace with " " if unknown
tab measure
	
	
*** Variable: OEDEMA ***
lookfor oedema œdème edema
gen str1 oedema = "n"  
	//This variable assumes no one has oedema


*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores of a child. 
	So we assume all children in the sample have the same weight */
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
containing the WHO Child Growth Standards are stored. */	
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file (datalab_z_r_rc and datalab_prev_rc)*/
gen str30 datalab = "children_nutri_lao"
lab var datalab "Working file"	
	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_days ageunit weight ///
height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_lao_z_rc.dta", clear 

		
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
	/*Lao MICS 2017: 228 children were replaced as missing because
	they have extreme z-scores which are biologically implausible. */

	
	//Retain relevant variables:
keep ind_id child_CH ln underweight* stunting* wasting*  
order ind_id child_CH ln underweight* stunting* wasting*
sort ind_id
save "$path_out/lao17_CH.dta", replace

count  
	//There are 11,812 children as reported in country report pg. 23


	//Erase files from folder:
erase "$path_out/children_nutri_lao_z_rc.xls"
erase "$path_out/children_nutri_lao_prev_rc.xls"
erase "$path_out/children_nutri_lao_z_rc.dta"
	

********************************************************************************
*** Step 1.2  BH - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children under 18 who died in 
the last 5 years prior to the survey date.*/

use "$path_in/bh.dta", clear

rename _all, lower	

		
*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** wm4=women's line number.
gen double ind_id = hh1*1000000 + hh2*100 + wm3 
format ind_id %20.0g
label var ind_id "Individual ID"

		
desc bh4c bh9c	
gen date_death = bh4c + bh9c	
	//Date of death = date of birth (bh4c) + age at death (bh9c)	
gen mdead_survey = wdoi-date_death	
	//Months dead from survey = Date of interview (wdoi) - date of death	
replace mdead_survey = . if (bh9c==0 | bh9c==.) & bh5==1	
	/*Replace children who are alive as '.' to distinguish them from children 
	who died at 0 months */ 
gen ydead_survey = mdead_survey/12
	//Years dead from survey
	

gen age_death = bh9c if bh5==2
label var age_death "Age at death in months"	
tab age_death, miss
	//Check whether the age is in months			
	
codebook bh5, tab (10)	
gen child_died = 1 if bh5==2
replace child_died = 0 if bh5==1
replace child_died = . if bh5==.
label define lab_died 0"child is alive" 1"child has died"
label values child_died lab_died
tab bh5 child_died, miss
	
	
bysort ind_id: egen tot_child_died = sum(child_died) 
	//For each woman, sum the number of children who died
	
	
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


gen women_BH = 1 
	//Identification variable for observations in BH recode

	
	//Retain relevant variables
keep ind_id women_BH childu18_died_per_wom_5y 
order ind_id women_BH childu18_died_per_wom_5y
sort ind_id
save "$path_out/lao17_BH.dta", replace	


********************************************************************************
*** Step 1.3  WM - WOMEN's RECODE  
*** (Eligible females 15-49 years in the household)
********************************************************************************
/*The purpose of step 1.3 is to identify all deaths that are reported by 
eligible women.*/

use "$path_in/wm.dta", clear 
	
rename _all, lower	
	
*** Generate individual unique key variable required for data merging
	*** hh1=cluster number;  
	*** hh2=household number; 
	*** ln=respondent's line number
gen double ind_id = hh1*1000000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen women_WM =1 
	//Identification variable for observations in WM recode
		
tab wb4, miss 
	/*Lao MICS 2017: Fertility and mortality question was collected 
	from women 15-49 years. 783 women with missing age information.*/
	
tab cm1 cm8, miss
	/*Lao MICS 2017: 32 women report never having given birth but 
	who also have information on child mortality (i.e. anomalies). */	
		
	
lookfor marital	
codebook mstatus ma6, tab (10)
tab mstatus ma6, miss 
gen marital = 1 if mstatus == 3 & ma6==.
	//1: Never married
replace marital = 2 if mstatus == 1 & ma6==.
	//2: Currently married
replace marital = 3 if mstatus == 2 & ma6==1
	//3: Widowed	
replace marital = 4 if mstatus == 2 & ma6==2
	//4: Divorced	
replace marital = 5 if mstatus == 2 & ma6==3
	//5: Separated/not living together	
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab ma6 marital, miss
tab mstatus marital, miss
rename marital marital_wom


keep wm7* cm1 cm8 cm9 cm10 ind_id women_WM *_wom
order wm7* cm1 cm8 cm9 cm10 ind_id women_WM *_wom
sort ind_id
save "$path_out/lao17_WM.dta", replace


********************************************************************************
*** Step 1.4  MN - MEN'S RECODE 
***(Eligible man: 15-49 years in the household) 
********************************************************************************
/*The purpose of step 1.4 is to identify all deaths that are reported by 
eligible men.*/

use "$path_in/mn.dta", clear 
	
rename _all, lower

	
*** Generate individual unique key variable required for data merging
	*** hh1=cluster number;  
	*** hh2=household number; 
	*** ln=respondent's line number
gen double ind_id = hh1*1000000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen men_MN=1 	
	//Identification variable for observations in MR recode

	
tab mwb4, miss 
	/*Lao MICS 2017: Fertility and mortality question was collected 
	from men 15-49 years. 670 men with missing age information.*/
	
tab mcm1 mcm8, miss
	/*Lao MICS 2017: 23 men report never fathering a child but who 
	have information on child mortality (i.e. anomalies). */	
	

codebook mmstatus mma6, tab (10)
tab mmstatus mma6, miss 
gen marital = 1 if mmstatus == 3 & mma6==.
	//1: Never married
replace marital = 2 if mmstatus == 1 & mma6==.
	//2: Currently married
replace marital = 3 if mmstatus == 2 & mma6==1
	//3: Widowed	
replace marital = 4 if mmstatus == 2 & mma6==2
	//4: Divorced	
replace marital = 5 if mmstatus == 2 & mma6==3
	//5: Separated/not living together	
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab mma6 marital, miss
tab mmstatus marital, miss
rename marital marital_men

	
keep mcm1 mcm8 mcm9 mcm10 ind_id men_MN *_men 
order mcm1 mcm8 mcm9 mcm10 ind_id men_MN *_men 
sort ind_id
save "$path_out/lao17_MN.dta", replace


********************************************************************************
*** Step 1.5 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

use "$path_in/hh.dta", clear 
	
rename _all, lower	

*** Generate individual unique key variable required for data merging
	*** hh1=cluster number;  
	*** hh2=household number; 
gen	double hh_id = hh1*1000 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"

duplicates report hh_id 


save "$path_out/lao17_HH.dta", replace


********************************************************************************
*** Step 1.6 HL - HOUSEHOLD MEMBER  
********************************************************************************

use "$path_in/hl.dta", clear 
	
rename _all, lower

	
*** Generate a household unique key variable at the household level using: 
	***hh1=cluster number 
	***hh2=household number
gen double hh_id = hh1*1000 + hh2 
format hh_id %20.0g
label var hh_id "Household ID"


*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** hl1=respondent's line number.
gen double ind_id = hh1*1000000 + hh2*100 + hl1 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 


sort ind_id

	
********************************************************************************
*** Step 1.7 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/lao17_BH.dta"
drop _merge
erase "$path_out/lao17_BH.dta" 
 
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/lao17_WM.dta"
count if hl8>0
	/*26,103 women 15-49 years were eligible for interview. This matches the 
	country report (p.iii) */
drop _merge
erase "$path_out/lao17_WM.dta"


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/lao17_HH.dta"
tab hh46 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed
drop _merge
erase "$path_out/lao17_HH.dta"


*** Merging MN Recode 
*****************************************
merge 1:1 ind_id using "$path_out/lao17_MN.dta"
drop _merge
erase "$path_out/lao17_MN.dta"


*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/lao17_CH.dta"
drop _merge
erase "$path_out/lao17_CH.dta"

sort ind_id


********************************************************************************
*** Step 1.8 CONTROL VARIABLES
********************************************************************************
/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women or men. These 
households will not have information on relevant indicators of health. As such, 
these households are considered as non-deprived in those relevant indicators. */


*** No eligible women 15-49 years 
*** for child mortality indicator
*****************************************
gen	fem_eligible = (women_WM==1)
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
drop fem_eligible hh_n_fem_eligible 
tab no_fem_eligible, miss


*** No eligible men 15-49 years
*** for child mortality indicator (if relevant)
*****************************************
gen	male_eligible = (men_MN==1)
bysort	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible men for an interview
lab var no_male_eligible "Household has no eligible man for interview"
drop male_eligible hh_n_male_eligible
tab no_male_eligible, miss

	
*** No eligible children under 5
*** for child nutrition indicator
*****************************************
gen	child_eligible = (child_CH==1) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible for anthropometric"
drop child_eligible hh_n_children_eligible
tab no_child_eligible, miss

		
sort hh_id


********************************************************************************
*** Step 1.9 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
clonevar weight = hhweight 
label var weight "Sample weight"


//Area: urban or rural		
codebook hh6, tab (9)	
clonevar area = hh6  
replace area=0 if area==2  |area==3 
	/*Lao MICS 2017: there is a distinction btw rural with road (2) 
	and without road (3) */
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Sex of household member
codebook hl4
clonevar sex = hl4 
label var sex "Sex of household member"


//Age of household member
codebook hl6, tab (100)
clonevar age = hl6  
replace age = . if age>=98
label var age "Age of household member"


//Age group (for global MPI estimation)
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+") , gen(agec4)
lab var agec4 "age groups (4 groups)"


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
compare hhsize hh48  
drop member

//Subnational region
	/* The sample for the Lao MICS 2017 was designed to provide estimates at 
	the national level, for urban and rural areas, including rural with roads 
	and rural without roads, for three regions including: North, Central and 
	South and 18 provinces including: Vientiane Capital, Phongsaly, Luangnamtha, 
	Oudomxay, Bokeo, Luangprabang, Huaphanh, Xayabury, Xiengkhuang, Vientinae, 
	Borikhamxay, Khammuane, Savannakhet, Saravane, Sekong, Champasack, Attapeu 
	and Xaysomboun. pg3 */   	
codebook hh7, tab (99) 
decode hh7, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
tab region, miss
drop temp
label define lab_reg ///
1 "Attapeu" ///
2 "Bokeo" ///
3 "Borikhamxay" ///
4 "Champasack" ///
5 "Houaphan" ///
6 "Khammuane" ///
7 "Luang Namtha" ///
8 "Luang Prabang" ///
9 "Oudomxay" ///
10 "Phongsaly" ///
11 "Saravane" ///
12 "Savannakhet" ///
13 "Sekong" ///
14 "Vientiane" ///
15 "Vientiane Capital" ///
16 "Xaignabouri" ///
17 "Xaisomboun " ///
18 "Xiangkhouang"
label values region lab_reg


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************

********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

/* In Lao PDR, children enter primary school at age 6, lower secondary at age 
11 and enter upper secondary school at age 15. There are 5 grades in primary 
school and 4 + 3 grades in secondary school. In primary school, grades are 
referred to as grade 1 to grade 5. For lower secondary school, grades are 
referred to as grade 6 to grade 9 and in upper secondary to grade 10 to 
grade 12 (p.258 of country report).*/


codebook ed4 ed5a, tab (99)
tab age ed10a if ed5a==0, miss
	//The category ECE indicate early childhood education, that is, pre-primary
clonevar edulevel = ed5a 
	//Highest educational level attended
replace edulevel = . if ed5a==. | ed5a==8 
	//All missing values or out of range are replaced as "."
replace edulevel = 0 if ed4==2 
	//Those who never attended school are replaced as '0'
label var edulevel "Highest level of education attended"


codebook ed5b, tab (99)
clonevar eduhighyear = ed5b 
	//Highest grade attended at that level
replace eduhighyear = .  if ed5b==. | ed5b==98 
	//All missing values or out of range are replaced as "."
replace eduhighyear = 0  if ed4==2 
	//Those who never attended school are replaced as '0'
lab var eduhighyear "Highest grade attended for each level of edu"


*** Cleaning inconsistencies 
replace edulevel = 0 if age<10  
replace eduhighyear = 0 if age<10 
	/*The variables edulevel and eduhighyear was replaced with a '0' given that 
	the criteria for this indicator is household member aged 10 years or older */ 
replace eduhighyear = 0 if edulevel<1
	//Early childhood education has no grade
replace eduhighyear = ed5b-1 if ed6==2 & eduhighyear>=1 & eduhighyear<. 
	/*Through ed6 variable, individuals confirm whether they have completed the 
	highest grade they have attended. For individuals who responded that they 
	did not complete the highest grade attended, we re-assign them to the next  
	lower grade that they would have completed. */

	
*** Now we create the years of schooling 
tab eduhighyear edulevel, miss
gen	eduyears = . 
replace eduyears = 0 if eduhighyear==0

//Number of years for primary level education: 
replace eduyears = 0 if eduhighyear==10 & edulevel==1
	/*Those who attended primary school grade 1, but never completed. Remember, 
	primary grade 1 is coded as '11' in Laos dataset. So those who did not 
	complete grade 1 of primary were re-assigned a 10 in line 810. */
replace eduyears = 1 if eduhighyear==11 & edulevel==1
replace eduyears = 2 if eduhighyear==12 & edulevel==1
replace eduyears = 3 if eduhighyear==13 & edulevel==1
replace eduyears = 4 if eduhighyear==14 & edulevel==1
replace eduyears = 5 if eduhighyear==15 & edulevel==1

//Number of years for people with lower secondary:	
replace eduyears = 5 if eduhighyear==20 & edulevel==2
	/*Those who attended secondary school grade 1, but never completed. Remember, 
	secondary grade 1 is coded as '21' in Laos dataset. So those who did not 
	complete grade 1 of secondary were re-assigned a 20 in line 810. */	
replace eduyears = 6 if eduhighyear==21 & edulevel==2	
replace eduyears = 7 if eduhighyear==22 & edulevel==2	
replace eduyears = 8 if eduhighyear==23 & edulevel==2	
replace eduyears = 9 if eduhighyear==24 & edulevel==2	

//Number of years for people with upper secondary:	
replace eduyears = 9 if eduhighyear==30 & edulevel==3
replace eduyears = 10 if eduhighyear==31 & edulevel==3	
replace eduyears = 11 if eduhighyear==32 & edulevel==3	
replace eduyears = 12 if eduhighyear==33 & edulevel==3

//Number of years for people with non-tertiary (diploma etc):
replace eduyears = 12 if eduhighyear==40 & edulevel==4	
replace eduyears = 13 if eduhighyear==41 & edulevel==4
replace eduyears = 14 if eduhighyear==42 & edulevel==4
replace eduyears = 15 if eduhighyear==43 & edulevel==4

//Number of years for people with university:
replace eduyears = 12 if eduhighyear==50 & edulevel==5
replace eduyears = 13 if eduhighyear==51 & edulevel==5
replace eduyears = 14 if eduhighyear==52 & edulevel==5
replace eduyears = 15 if eduhighyear==53 & edulevel==5
replace eduyears = 16 if eduhighyear==54 & edulevel==5
replace eduyears = 17 if eduhighyear==55 & edulevel==5
replace eduyears = 18 if eduhighyear==56 & edulevel==5
replace eduyears = 19 if eduhighyear==57 & edulevel==5



*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data. Please check 
	whether this is the case and correct when necessary */
replace eduyears = 0 if age< 10 
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */
replace eduyears = 12 if edulevel==4 & eduhighyear==.
	/*We assume that an individual who has post secondary non tertiary but 
	no information on grade, has completed upper secondary the most. */ 
replace eduyears = 12 if edulevel==5 & eduhighyear==.
	/*We assume that an individual who has tertiary education but 
	no information on grade, has completed upper secondary the most. */ 			
lab var eduyears "Total number of years of education accomplished"
tab eduyears,miss


	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 10 years 
	and older */	
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bysort	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 10 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=10 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	/*Total number of household members who are 10 years and older */
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
tab no_missing_edu, miss
	//Check that values for 0 are less than 1%
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"	
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no household member aged 
10 years or older has completed SIX years of schooling. */
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
tab hh_years_edu6, miss


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

codebook ed4 ed9, tab (9)   

gen	attendance = .
replace attendance = 1 if ed9==1 
	//Replace attendance with '1' if currently attending school	
replace attendance = 0 if ed9==2 
	//Replace attendance with '0' if currently not attending school	
replace attendance = 0 if ed4==2 
	//Replace attendance with '0' if never ever attended school	
tab age ed9, miss	
	//Check individuals who are not of school age	
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age 
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"
tab attendance, miss


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */ 
******************************************************************* 

gen	child_schoolage = (schage>=6 & schage<=14)
	/*
	Note: In Laos, the official school entrance age to primary school is 
	6 years. So, age range is 6-14 (=6+8) 
	Source: "http://data.uis.unesco.org/?ReportId=163"
	Go to Education>Education>System>Official entrance age to primary education. 
	Look at the starting age and add 8. 
	*/

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 	
gen temp = 1 if child_schoolage==1 & attendance!=.
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
*** Step 2.3a Child Nutrition ***
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
*** Step 2.3b Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* The indicator takes value 1 if the household has no child under 5 who 
has either height-for-age or weight-for-age that is under 2 stdev below 
the median. It also takes value 1 for the households that have no eligible 
children. The indicator takes a value of missing only if all eligible 
children have missing information in their respective nutrition variable. */
************************************************************************

gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_eligible==1   
 	/*We replace households that do not have the applicable population, that is, 
	children 0-5, as non-deprived in nutrition*/		
lab var hh_nutrition_uw_st "Household has no individuals malnourished"
tab hh_nutrition_uw_st, miss



********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9 cm10 mcm9 mcm10
	/*cm9 or mcm9: number of sons who have died 
	  cm10 or mcm10: number of daughters who have died */
	  
egen temp_f = rowtotal(cm9 cm10), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if cm1==1 & cm8==2 | cm1==2 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth */
replace temp_f = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f	

egen temp_m = rowtotal(mcm9 mcm10), missing
	//Total child mortality reported by eligible men	
replace temp_m = 0 if mcm1==1 & mcm8==2 | mcm1==2 
	/*Assign a value of "0" for:
	- all eligible men who ever fathered children but reported no child death 
	- all eligible men who never fathered children */
replace temp_m = 0 if no_male_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing	
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m

egen child_mortality = rowmax(child_mortality_f child_mortality_m)
lab var child_mortality "Total child mortality within household"
tab child_mortality, miss  

	
*** Standard MPI *** 
/* The standard MPI indicator takes a value of "0" if women in the household 
reported mortality among children under 18 in the last 5 years from the survey 
year. The indicator takes a value of "1" if eligible women within the household 
reported (i) no child mortality or (ii) if any child died longer than 5 years 
from the survey year or (iii) if any child 18 years and older died in the last 
5 years. Households were replaced with a value of "1" if eligible 
men within the household reported no child mortality in the absence of 
information from women. The indicator takes a missing value if there was 
missing information on reported death from eligible individuals. */
************************************************************************

tab childu18_died_per_wom_5y, miss
	/* The 'childu18_died_per_wom_5y' variable was constructed in Step 1.2 using 
	information from individual women who ever gave birth in the BH file. The 
	missing values represent eligible woman who have never ever given birth and 
	so are not present in the BR file. But these 'missing women' may be living 
	in households where there are other women with child mortality information 
	from the BH file. So at this stage, it is important that we aggregate the 
	information that was obtained from the BH file at the household level. This
	ensures that women who were not present in the BH file is assigned with a 
	value, following the information provided by other women in the household.*/		
replace childu18_died_per_wom_5y = 0 if cm1==2 															   
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */
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
/*Members of the household are considered deprived if the household has no 
electricity */
****************************************
clonevar electricity = hc8
codebook electricity, tab (9)
replace electricity = 0 if electricity==3 
replace electricity = 1 if electricity==2
	//Please ensure that 0=no; 1=yes (off-grid or interconnected)
replace electricity = . if electricity==9 
	//Please check that missing values remain missing	
label var electricity "Household has electricity"



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

desc ws11 ws15  
clonevar toilet = ws11  	
clonevar shared_toilet = ws15
codebook shared_toilet, tab(99)  
recode shared_toilet (2=0)
replace shared_toilet=. if ws15==9  
tab ws15 shared_toilet, miss nol
	
	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
codebook toilet, tab(99) 
gen	toilet_mdg = ((toilet<=22 | toilet==31) & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
		
replace toilet_mdg = 0 if (toilet<=22 | toilet==31)  & shared_toilet==1 
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */	
	
replace toilet_mdg = 0 if toilet==14 
	/* The report indicate (p.322) that flush to open drain is considered as 
	unimproved sanitation facility */		
	
replace toilet_mdg = . if toilet==.  | toilet==99
	//Household is assigned a value of '.' if it has missing information 
lab var toilet_mdg "Household has improved sanitation"
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

clonevar water = ws1  
clonevar timetowater = ws4  
clonevar ndwater = ws2  	
tab ws2 if water==91 	
/*Households using bottled water are only considered to be using 
improved water when they use water from an improved source for cooking and 
personal hygiene. This is because the quality of bottled water is not known. 
However, it is important to note that households using bottled 
water for drinking are classified as improved or unimproved source if this is 
explicitly indicated in the country report. 

Page 306 of the country report indicate that packaged water (bottled water and 
sachet water) and delivered water (tanker truck and cart with small drum/tank) 
are treated as an improve source of water. */


*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
codebook water, tab(99)
gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==14 | ///
					 water==21 | water==31 | water==41 | water==51 | ///
					 water==61 | water==91 | water==92   
	/*Non deprived if water is piped into dwelling, piped to yard/plot, 
	public tap/standpipe, tube well or borehole, protected well, 
	protected spring, rainwater, bottled water, packaged water.*/
		
	/* Note: In Laos, packaged water (bottled water and sachet water) 
	and delivered water (tanker truck and cart with small drum/tank) are 
	treated as improved source in the report (p. 306-7). As such, we have 
	followed the report. */
		
replace water_mdg = 0 if water==32 | water==42 | water==81 | water==96 
	/*Deprived if it is unprotected well, unprotected spring, 
	surface water (river/lake, etc),other*/

codebook timetowater, tab(9999)		
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=998
	//Deprived if water is at more than 30 minutes' walk (roundtrip). 
replace water_mdg = . if water==. | water==99					 
lab var water_mdg "Household has safe drinking water on premises"
tab water water_mdg, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hc4
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor<=12 | floor==96 
	//Deprived if mud/earth, sand, dung, other 		
replace floor_imp = . if floor==.  
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials. We followed the report's definitions
of natural or rudimentary materials. */
clonevar wall = hc6
codebook wall, tab(99)	
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=29  | wall==96 
	/*Deprived if no wall, cane/palms/trunk, mud/dirt, 
	grass/reeds/thatch, pole/bamboo with mud, stone with mud, plywood,
	cardboard, carton/plastic, uncovered adobe, canvas/tent, 
	unburnt bricks, reused wood, other */	
replace wall_imp = . if wall==. 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials. We followed the report's definitions
of natural and rudimentary materials. */
clonevar roof = hc5
codebook roof, tab(99)	
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=23 | roof==96
	/*Deprived if no roof, thatch/palm leaf, mud/earth/lump of earth, 
	sod/grass, plastic/polythene sheeting, rustic mat, cardboard, 
	canvas/tent, wood planks/reused wood, unburnt bricks, other */
replace roof_imp = . if roof==. 
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

lookfor cook combustible
clonevar cookingfuel = eu4 
	//eu4 = type of fuel or energy source used for the cookstove

	
*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook eu1 cookingfuel, tab(99)
tab eu1 cookingfuel, miss

gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>=4 & cookingfuel<=11
	/* Deprived if: coal/lignite, charcoal, wood, straw/shrubs/grass, 
					agricultural crop, animal dung, woodchips, sawdust */	
replace cooking_mdg = 0 if cookingfuel==96 
	/*The cross tab between eu1 and eu4 indicate that of the 2,047 individuals
	reported using other type of cookstove, 2,008 of them have used solid fuel 
	on the cookstove, while 39 of them used other type of fuel. It is very 
	likely that these 39 individuals have also used some form of fuel that is 
    not clean. As such, we identify all individuals who reported using other 
	fuel on cookstove as deprived. */
lab var cooking_mdg "Household cooks with clean fuels"	
tab cookingfuel cooking_mdg, miss
tab eu1 if cookingfuel==. & cooking_mdg==1, miss	
tab cooking_mdg, miss


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */


*** Television/LCD TV/plasma TV/color TV/black & white tv
lookfor tv television plasma lcd
codebook hc9a
clonevar television = hc9a 
lab var television "Household has television"
tab television, miss
	//7% missing value 
tab electricity television, miss
	/*This is because these households do not have electricity. All households 
	that responded no electricity, did not respond for questions on television 
	and refrigerator (p.469) */
replace television=0 if electricity==0 & television==.	
	/*We make an assumption that there is no television in these households 
	given that there is no electricity  */

		
***	Radio/walkman/stereo/kindle
lookfor radio walkman stereo
codebook hc7b
clonevar radio = hc7b 
lab var radio "Household has radio"	


***	Handphone/telephone/iphone/mobilephone/ipod
lookfor telephone téléphone mobilephone ipod
codebook hc7a hc12
clonevar telephone =  hc7a
replace telephone=1 if telephone!=1 & hc12==1	
	//hc12=mobilephone. Combine information on telephone and mobilephone.	
tab hc7a hc12 if telephone==1,miss
lab var telephone "Household has telephone (landline/mobilephone)"	

	
***	Refrigerator/icebox/fridge
lookfor refrigerator réfrigérateur
codebook hc9b
clonevar refrigerator = hc9b 
lab var refrigerator "Household has refrigerator"
tab refrigerator, miss
	//7% missing value 
tab electricity refrigerator, miss
	/*This is because these households do not have electricity. All households 
	that responded no electricity, did not respond for questions on television 
	and refrigerator (p.469) */
replace refrigerator=0 if electricity==0 & refrigerator==.	
	/*We make an assumption that there is no refrigerator in these households 
	given that there is no electricity  */


***	Car/van/lorry/truck
lookfor car voiture truck van
codebook hc10e
clonevar car = hc10e  
lab var car "Household has car"		

	
***	Bicycle/cycle rickshaw
lookfor bicycle bicyclette
codebook hc10b
clonevar bicycle = hc10b 
lab var bicycle "Household has bicycle"	
	
	
***	Motorbike/motorized bike/autorickshaw
lookfor motorbike moto
codebook hc10c	
clonevar motorbike = hc10c
lab var motorbike "Household has motorbike"

	
***	Computer/laptop/tablet
lookfor computer ordinateur laptop ipad tablet
codebook hc11
clonevar computer = hc11
lab var computer "Household has computer"


***	Animal cart
lookfor brouette charrette cart
codebook hc10d
gen animal_cart = hc10d
lab var animal_cart "Household has animal cart"	
	
	
foreach var in television radio telephone refrigerator car ///
			   bicycle motorbike computer animal_cart {
replace `var' = 0 if `var'==2 
label define lab_`var' 0"No" 1"Yes"
label values `var' lab_`var'			   
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Labels defined and missing values replaced	
	

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
	
	//Retain data on sampling design: 
gen psu = hh1
egen strata = group(hh7 hh6)	


	//Retain year, month & date of interview:
desc hh5y hh5m hh5d 
clonevar year_interview = hh5y 	
clonevar month_interview = hh5m 
clonevar date_interview = hh5d 


	//Generate presence of subsample
gen subsample = .
 
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
char _dta[cty] "Lao PDR"
char _dta[ccty] "LAO"
char _dta[year] "2017" 	
char _dta[survey] "MICS"
char _dta[ccnum] "418"
char _dta[type] "micro"

	
*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/lao_mics17.dta", replace 
