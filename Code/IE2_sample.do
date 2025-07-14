
cd .. 
global figures "writeup_SCOMP\figures"
global tables "writeup_SCOMP\Tables"
////////////////////////////////////////////////
**# Bookmark #1 Data Cleaning 
////////////////////////////////////////////////


use Data/1_solicitudes_12to19RV, clear
		
	keep if tipo_consultante == "A"
	drop tipo_consultante
		

use Data/2_ofertas_acep_12to19RV, clear

	sort id_certificado_saldo num_meses_garantizados id_oferta

	tab tipo_pension
	keep if tipo_pension == "PE"
	drop tipo_pension
	

	tab ind_oferta_externa
	tab tipo_inter
	
	bysort id_certificado_saldo id_oferta ind_oferta_externa: gen aux = _N // not unique id 
	tab aux
	bysort id_certificado_saldo id_oferta sec_oferta: gen aux2 = _N // unique id 
	tab aux2
	drop aux*

	ds id_certificado_saldo, not
	local vars_to_rename `r(varlist)'
	local vars_to_rename id_oferta sec_oferta 

	quietly foreach v of local vars_to_rename {
		rename `v' `v'1
	}
	
	
	merge m:1 id_certificado_saldo using Data/3_aceptaciones_12to19

	br if _merge == 1
	tab year month if _merge == 1 // the not matched observations are at the end of the period, and are accepted in 2020. 
	keep if _merge == 3
	drop _merge 


	// keep only the ones who bought RV: two different methods for robustness 
	
	tab cod_modalidad_pension 

	gen drop1 = 1 if cod_modalidad_pension != 1


	gen accepted = 1 if id_oferta1 == id_oferta
	bysort id_certificado_saldo: egen aux = sum(accepted) 
	tab aux 

	gen accepted2 = 1 if id_oferta1 == id_oferta & sec_oferta1 == sec_oferta 
	bysort id_certificado_saldo: egen aux2 = sum(accepted2) 
	tab aux2 // dummies: correct accepted var 

	gen drop2 = 1 if aux2 == 0 

	gen coincide = (drop1 == drop2) // the ones that do not coincide are at the beginning of period, hence some offers are recorder prior to our data. 
	
	drop if drop2 == 1 
	drop drop* accepted aux*  coincide
	
	tab num_meses_diferidos num_anos_diferidos // no variation
	tab cod_modalidad_pension // no variation
	drop num_meses_diferidos num_anos_diferidos cod_modalidad_pension
	
	save temp, replace
	
	
	use Data/1_solicitudes_12to19, clear 
	bysort id_certificado_saldo: egen aux = sd(val_uf_saldo) 
	summ aux, d // no variation 

	keep id_certificado_saldo val_uf_saldo year
	bysort id_certificado_saldo: keep if _n == 1 
		
	save temp2, replace 
	
	use temp, clear 

	merge m:1 id_certificado_saldo using temp2 
	keep if _merge == 3  // the merge == 1 are at the beginning of period 
	drop _merge 
	egen n_unique = nvals(id_certificado_saldo) // 8176 purchases 
	local unique = n_unique[1]
	tab n_unique 
	
	count
	local total = r(N)
	local ratio = `total'/`unique'
		
	keep if num_meses_garantizados == 0 & val_uf_monto_eld == 0 // to compare only simle annuities 

	egen n_unique2 = nvals(id_certificado_saldo)
	local unique = n_unique[1]
	count
	local total2 = r(N)
	local ratio2 = `total2'/`unique'
	matrix stats = (`unique', `total', `ratio', `total2', `ratio2')
	esttab matrix(stats) using "$tables/IE2_sample_size.tex",  replace 

	drop n_unique n_unique2 
	
	
	tab num_meses_garantizados por_descuento_garantizado
	drop num_meses_garantizados por_descuento_garantizado

	drop nac // drop nationality 

	tab tipo_pension sec_beneficiario
	drop tipo_pension sec_beneficiario


	save temp3, replace
	
	use temp3, clear 
	
	bysort id_certificado_saldo: egen aux = total(accepted2)
	order accepted2 aux 
	drop if aux == 0 // accepted an annuity with ELD or a guaranteed period. 
	drop aux
	
	
	bysort id_certificado_saldo: gen byte first_cert = (_n==1)
	save temp4, replace
	
	/* 
	Explanation 
	temp: selects only annuiteis (cod_mod ==1) and pensions due to age ("PE") and merges the offers with the acceptance data. 
	
	temp3 takes temp and uses the requests data to get the amount of savings. and also restricts the sample to offers that do not have guarantee nor ELD 
	
	temp4 selects only individuals who chose to buy annuities without guaranteed period nor ELD. 
	
	*/
	





////////////////////////////////////////////////
**# Bookmark #2 Magnitude of search: some basic descriptives.
////////////////////////////////////////////////

	use temp4, clear 

	

	tab year 
	bysort id_certificado_saldo: egen n_ext = total(ind_oferta_externa == "S") // number external offers 

	tab n_ext if first_cert 
	
	gen ext_cat = n_ext // truncated number of external offers. 
	replace ext_cat = 5 if ext_cat > 8
	
	*label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5+", replace
	label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8+", replace

	label values ext_cat extcat

	graph bar (percent) first_cert if first_cert, over(ext_cat)  /// 
	ytitle("Share (%)") title("Dist. Num. External Offers") 
	
	graph export "$figures\IE2_dist_external_offers.png", replace
	
	
	graph bar (percent) first_cert if first_cert, over(year) over(ext_cat, gap(200))  ///
	asyvars ytitle("Share (%)") title("Dist. Num. External Offers") ///
	legend(title("Year")) scheme(white_jet) 
	
	graph export "$figures\IE2_dist_external_offers_byyear.png", replace
	
	// CDF and hazards. 
	egen total_cert = total(first_cert) // number of certificates 
	bysort ext_cat: egen freq = total(first_cert) // number of people with 
	bysort ext_cat first_cert: gen tag = (_n == _N & first_cert )

	gen cumfreq   = sum(freq)        if tag
	gen survivors = total_cert - (cumfreq - freq) if tag
	gen cdf       = cumfreq / total_cert       if tag
	gen hazard    = freq / survivors           if tag

	twoway line cdf ext_cat if first_cert, sort ///
		xlabel(   ,valuelabel) ///
		ytitle("Cumulative share") title("CDF of External‐Offer Counts")
		graph export "$figures\IE2_CDF_number_extoffers.png", replace
 
		
	twoway line hazard ext_cat if tag, sort ///
		xlabel( ,valuelabel) ///
		ytitle("Hazard rate") title("Hazard of k External Offers")
		graph export "$figures\IE2_hazard_number_extoffers.png", replace
	

////////////////////////////////////////////////
**# Bookmark #3 Search and its relation to income
////////////////////////////////////////////////

			
use temp4, clear

* 3) Define quintiles of avg_pension
xtile income_q = val_uf_saldo if first_cert, nq(5)
label define qlab 1 "Q1 (low)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (high)", replace
label values income_q qlab

* 4) Count external offers per certificate and bin at 5+
bysort id_certificado_saldo: egen n_ext = total(ind_oferta_externa=="S")
gen byte ext_cat = min(n_ext,8) if first_cert
//label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5+", replace
label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8+", replace

label values ext_cat extcat

reg n_ext val_uf_saldo if first_cert // richer people search more. 
summarize val_uf_saldo if first_cert
generate double z_saldo = (val_uf_saldo - r(mean)) / r(sd)
regress n_ext z_saldo if first_cert // one standard deviation in income creates .72 extra searches. 


graph bar (mean) n_ext if first_cert, ///
    over(income_q) ///
    ytitle("Average # External Offers") ///
    title("External Offers by Income Quintile")
graph export "$figures\IE2_search_by_income_quintile.png", replace

bysort income_q: egen total_cert = total(first_cert) 
bysort ext_cat income_q: egen freq = total(first_cert) 
bysort ext_cat first_cert income_q: gen tag = (_n == _N & first_cert) 

bysort income_q (ext_cat): gen cumfreq = sum(freq) if tag 
bysort income_q: gen survivors = total_cert - (cumfreq - freq) if tag
bysort income_q: gen cdf       = cumfreq / total_cert       if tag
bysort income_q: gen hazard    = freq / survivors           if tag

twoway  (line cdf ext_cat if tag & income_q==1, sort) ///
  (line cdf ext_cat if tag & income_q==2, sort) ///
  (line cdf ext_cat if tag & income_q==3, sort) ///
  (line cdf ext_cat if tag & income_q==4, sort) ///
  (line cdf ext_cat if tag & income_q==5, sort) ///
, ///
  xlabel(0(1)8, valuelabel) ///
  ytitle("Cumulative share") ///
  xtitle("Number of ext. offers") ///
  title("CDF of External‐Offer Counts by Income Quintile") /// 
  legend( ///
    order(1 "Q1 (low)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (high)") ///
    ring(1) pos(5) cols(5) )
	
graph export "$figures\IE2_search_CDF_by_income_quintile.png", replace

twoway  (line hazard ext_cat if tag & income_q==1, sort) ///
  (line hazard ext_cat if tag & income_q==2, sort) ///
  (line hazard ext_cat if tag & income_q==3, sort) ///
  (line hazard ext_cat if tag & income_q==4, sort) ///
  (line hazard ext_cat if tag & income_q==5, sort) ///
, ///
  xlabel(0(1)8, valuelabel) ///
  ytitle("Cumulative share") ///
  xtitle("Number of ext. offers") ///
  title("CDF of External‐Offer Counts by Income Quintile") /// 
  legend( ///
    order(1 "Q1 (low)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (high)") ///
    ring(1) pos(5) cols(5) )
 
graph export "$figures\IE2_search_hazardrate_by_income_quintile.png", replace


	
////////////////////////////////////////////////	
**# Bookmark #4 within group are offers the same? 
////////////////////////////////////////////////

* group are defined as a combination of 1) savings quintile, 2) 
use temp4, clear // here could have used temp3

xtile income_q = val_uf_saldo if first_cert, nq(5)
bysort id_certificado_saldo (income_q): replace income_q = income_q[1]

gen edad = year - agno_nac
summ edad, d 
disp `r(p99)'
histogram edad if edad < `r(p99)'


/* group are defined as a combination of: 
1) savings quintile: income_q 
2) age: edad 
3) sexo: M or F 
*/ 

bysort id_certificado_saldo (accepted2): gen aux = accepted2[1] // many people did accept offers with guarantees or with ELD 



drop if ind_oferta_externa == "S" // the bargaining reveals variables that we can not conrol for 
keep id_certificado_saldo edad  income_q sex id_participe year  val_uf_saldo  val_uf_pension sec_solicitud_oferta

gen edad_g = edad - mod(edad,5)

gen ratio = val_uf_saldo / val_uf_pension

egen group = group(edad_g income_q sex id_participe year) // offers made by an insurer to individuals that are similar. 
egen group2 = group(edad val_uf_saldo sex id_participe year) 
egen group3 = group(edad val_uf_saldo sex  ) 

sort group id_certificado_saldo

bysort group id_certificado_saldo: drop if _n > 1 

bysort group: gen size = _N 

bysort group2: gen size2 = _N 
bysort group: egen sd_ratio    = sd(ratio) 
bysort group2: egen sd_ratio2    = sd(ratio) 
bysort group: egen sd_offer  = sd(val_uf_pension)
bysort group2: egen sd_offer2  = sd(val_uf_pension)
bysort group3: egen sd_offer3  = sd(val_uf_pension)

bysort group: egen mu_ratio = mean(ratio)
bysort group2: egen mu_ratio2 = mean(ratio)
bysort group: egen mu_offer = mean(val_uf_pension)
bysort group2: egen mu_offer2 = mean(val_uf_pension)
bysort group3: egen mu_offer3 = mean(val_uf_pension)


gen z_offer = sd_offer / mu_offer // mean .19
gen z_offer2 = sd_offer2 /mu_offer2 // mean .06
gen z_offer3 = sd_offer3 /mu_offer3 //

summ z_offer 
summ z_offer2
summ sd_offer2

gen z_ratio = sd_ratio / mu_ratio
gen z_ratio2 = sd_ratio2 /mu_ratio2

summ z_ratio
summ z_ratio2

sort group group2

estpost summarize z_offer z_offer2 z_offer3 sd_offer2 z_ratio z_ratio2
esttab using "$tables/IE2_within_group_dispersion.tex", cells("mean sd min max count") ///
	title("Summary Statistics") replace

reghdfe ratio, absorb(group) // R2 = .56
reghdfe val_uf_pension, absorb(group3) //R2 = .99 
 keep if size2 > 1

reghdfe ratio, absorb(group2) // R2 = .70
reghdfe val_uf_pension, absorb(group2) // .98
 



	
////////////////////////////////////////////////	
**# Bookmark #5 dispersion within group for external and internal offers. 
////////////////////////////////////////////////

* group are defined as a combination of 1) savings quintile, 2) 
use temp4, clear

xtile income_q = val_uf_saldo if first_cert, nq(20)
bysort id_certificado_saldo (income_q): replace income_q = income_q[1]

gen edad = year - agno_nac
gen edad_g = edad - mod(edad,5)
gen ratio = val_uf_saldo / val_uf_pension


/* group are defined as a combination of: 
1) savings quintile: income_q 
2) age: edad 
3) sexo: M or F 
*/ 

keep id_certificado_saldo edad  income_q sex id_participe year  val_uf_saldo  val_uf_pension sec_solicitud_oferta edad_g ratio ind_oferta_externa

egen group = group(edad_g income_q sex id_participe year) // offers made by an insurer to individuals that are similar. 
egen group2 = group(edad val_uf_saldo sex id_participe year) 
egen group3 = group(edad val_uf_saldo id_participe) 


sort group
bysort group ind_oferta_externa id_certificado_saldo  : drop if _n > 1 
bysort group: gen size = _N 

by group: egen n_S = total(ind_oferta_externa == "S")
keep if n_S > 1 



bysort group id_certificado_saldo: egen n_ext = total(ind_oferta_externa == "S")
gen has_external = n_ext > 0

keep if has_external > 0 


bysort group ind_oferta_externa: egen sd = sd(ratio)
bysort  ind_oferta_externa : summarize sd
sort group ind_oferta_externa id_certificado_saldo

gen gender = 1 if sexo == "F" 
replace gender = 0 if sexo == "M"


mfp: regress ratio edad val_uf_saldo gender if ind_oferta_externa == "N" 
mfp: regress ratio edad val_uf_saldo gender if ind_oferta_externa == "S" 


// Generate polynomial terms manually
gen val_uf_saldo2 = val_uf_saldo^2
gen val_uf_saldo3 = val_uf_saldo^3
gen edad2 = edad^2
gen edad3 = edad^3
regress ratio c.val_uf_saldo##c.val_uf_saldo##c.val_uf_saldo ///
         c.edad##c.edad##c.edad gender if ind_oferta_externa == "N" 

regress ratio c.val_uf_saldo##c.val_uf_saldo##c.val_uf_saldo ///
         c.edad##c.edad##c.edad gender if ind_oferta_externa == "S" 

/* If there is revelation of information in the aftermarket then the R^2 of the regression of the initial offers would be lower than for the external offers, since there would be information that firms are considering when bidding but which we do not have in our data. but is not the case */ 












////////////////////////////////////////////////
**# Bookmark #6 Others 
/* 
1. for an individual how much dispersion is among the offers? 
2. how much do the external offer imrpoves on the internal offer of the same firm? 
and on the best internal offer? 
3. how many internal offers do people get? 
4. acceptance: share of the time accept highest offer? in a logit model does the credit rating matter? 
5. get the date of death of the individuals.  
*/
////////////////////////////////////////////////

/// 1. for an individual how much dispersion is among the offers? 
		
use temp4, clear

sort id_certificado_saldo

bysort id_certificado_saldo: egen sd = sd(val_uf_pension) 
bysort id_certificado_saldo: egen mean = mean(val_uf_pension) 

gen diff_pct = sd / mean // standard deviation in percent 
bysort id_certificado_saldo: egen max = max(val_uf_pension) 
bysort id_certificado_saldo: egen min = min(val_uf_pension) 
gen range = max - min 
gen z_range = (max-min)/ mean

summ diff_pct if first_cert

histogram diff_pct if first_cert
graph export "$figures\IE2_dispertion_choice_set.png", replace

histogram z_range if first_cert
graph export "$figures\IE2_dispertion_choice_set_range.png", replace

estpost summarize diff_pct z_range
esttab using "$tables/IE2_choiceset_dispersion.tex", cells("mean sd min max count") ///
	title("Summary Statistics") replace


/// 2. how much do the external offer imrpoves on the internal offer of the same firm? and on the best internal offer? 
use temp4, clear


sort id_certificado_saldo id_participe

bysort id_certificado_saldo id_participe: gen amount_external = val_uf_pension if ind_oferta_externa == "S"
bysort id_certificado_saldo id_participe: egen temp  = max(amount_external)
replace amount_external = temp 
drop temp
replace amount_external = . if ind_oferta_externa == "S"


order amount_external*, a(val_uf_pension)

gen improvement = (amount_external - val_uf_pension)/val_uf_pension 

summ improvement, d
estpost summarize improvement
esttab using "$tables/IE2_offer_improvement.tex", cells("mean sd min max count") ///
	title("Summary Statistics") replace

// 2.1 do the external offers improve on the best internal offer? not always   

use temp4, clear	

bysort id_certificado_saldo sec_oferta1: egen temp = max(val_uf_pension) if sec_oferta1 == 1 
order temp, a(val_uf_pension)

bysort id_certificado_saldo: egen best_initial_offer = max(temp) 
gen improvement = val_uf_pension/best_initial_offer -1 if ind_oferta_externa == "S"
bysort id_certificado_saldo: egen has_external = max(ind_oferta_externa == "S")

order temp best_initial_offer improvement has_external, a(val_uf_pension)

keep if has_external 
summ improvement, d

// 3. number of internal offers 
use temp4, clear 
bysort id_certificado_saldo sec_oferta1 sec_solicitud_oferta: gen internal_offers = _N 
replace internal_offers =. if sec_oferta1 != 1 

 
summ internal_offers

*second approach 
 

bysort id_certificado_saldo: egen n_id_participe = nvals(id_participe)
summ n_id_participe if first_cert 
order internal_offers n_id_participe

// 4. acceptance: share of the time accept highest offer? in a logit model does the credit rating matter? 


use temp4, clear
gen aux = val_uf_pension if accepted2 == 1
bysort id_certificado_saldo: egen accepted_amount = max(aux) 

bysort id_certificado_saldo: egen max_amount = max(val_uf_pension) 

gen acc_highest = (max_amount <= accepted_amount ) // dummy for accepting highest offer. 

tab acc_highest if first_cert // around half accept the highest offer 

gen foregone_pension = 100* (max_amount -accepted_amount) / accepted_amount   if acc_highest == 0 

order aux accepted_amount max_amount acc_highest foregone_pension, a(val_uf_pension) 

summ foregone_ // people who do not accept the highest forego a 1.5% higher pension 

histogram foregone if first_cert == 1

// one possibility is that it was because of having better credit ratings. 
rename id_participe rut_compania 
merge m:1 rut_compania year month using Data/4_clasificacion_riesgo
keep if _merge == 3 
drop _merge 
drop fecha_clasificacion str_ym fecha m_active rating_sd 

order clasificacion Nrisk, a(rut_compania)

br accepted2 id_certificado_saldo Nrisk val_uf_pension val_uf_saldo rut_compania
sort id_certificado_saldo

replace accepted2 = 0 if missing(accepted2)

*standarize vars 
bysort id_certificado_saldo: egen mu = mean(Nrisk)
bysort id_certificado_saldo: egen sd = sd(Nrisk)
gen Nrisk2 = (Nrisk - mu)/ sd
bysort id_certificado_saldo: egen mu2 = mean(val_uf_pension)
bysort id_certificado_saldo: egen sd2 = sd(val_uf_pension)
gen val_uf_pension2 = (val_uf_pension - mu) / sd
drop mu sd mu2 sd2



clogit accepted2 val_uf_pension2 Nrisk2 i.rut_compania, group(id_certificado_saldo)

margins, dydx(*)
marginsplot
predict pr, pr
estat eform

//  5. get the date of death of the individuals

	
	
	



////////////////////////////////////////////////
**# Bookmark #6 look at date of death and whether correlates with something of the external offers. 
////////////////////////////////////////////////

			
use temp5, clear
