
cd .. 
global figures "writeup_SCOMP\figures"
global tables "writeup_SCOMP\Tables"
////////////////////////////////////////////////
**# Bookmark #1 Data Cleaning 
////////////////////////////////////////////////

use Data/2_ofertas, clear

	sort id_certificado_saldo num_meses_garantizados id_oferta

	tab tipo_pension
	keep if tipo_pension == "PE"
	drop tipo_pension
	

	tab ind_oferta_externa
	tab tipo_inter 
	
	bysort id_certificado_saldo id_oferta ind_oferta_externa: gen aux = _N // not unique id 
	tab aux
	bysort id_certificado_saldo id_oferta sec_oferta: gen aux2 = _N // NOT UNIQUE ID IN THIS SAMPLE 
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
	tab periodo_ingreso if _merge == 1 // STILL TO CHECK BECAUSE ARE NOT ONLY AT THE END OF THE PERIOD. 
	keep if _merge == 3
	drop _merge 


	// ALREADY SELECTED ONLY cod_modalidad_pension == 1 


	gen accepted = 1 if id_oferta1 == id_oferta
	bysort id_certificado_saldo: egen aux = sum(accepted) 
	tab aux 

	gen accepted2 = 1 if id_oferta1 == id_oferta & sec_oferta1 == sec_oferta 
	bysort id_certificado_saldo: egen aux2 = sum(accepted2) 
	tab aux2 // dummies: correct accepted var 

	gen drop2 = 1 if aux2 == 0 
	
	drop if drop2 == 1 
	drop drop2 accepted aux*  
	
	tab num_meses_diferidos num_anos_diferidos // no variation
	tab cod_modalidad_pension // no variation
	drop num_meses_diferidos num_anos_diferidos cod_modalidad_pension
	
	save temp_full, replace
	
	
	use Data/1_solicitudes_12to19, clear 
	bysort id_certificado_saldo: egen aux = sd(val_uf_saldo) 
	summ aux, d // no variation 

	keep id_certificado_saldo val_uf_saldo year
	bysort id_certificado_saldo: keep if _n == 1 
		
	save temp2, replace 
	
	use temp_full, clear 

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
	esttab matrix(stats) using "$tables/IE3_sample_size.tex",  replace 

	drop n_unique n_unique2 
	
	
	tab num_meses_garantizados por_descuento_garantizado
	drop num_meses_garantizados por_descuento_garantizado

	drop nac // drop nationality 

	tab tipo_pension sec_beneficiario
	drop tipo_pension sec_beneficiario

	tab ind_oferta_rta_vit_inmediata ind_oferta_rta_vit_diferida
	drop ind_oferta_rta_vit_inmediata ind_oferta_rta_vit_diferida

	tab ind_oferta_rta_vit_inm_r_pro val_uf_renta_temporal
	drop ind_oferta_rta_vit_inm_r_pro val_uf_renta_temporal
	
	save temp3_full, replace
	
	use temp3_full, clear 
	
	bysort id_certificado_saldo: egen aux = total(accepted2)
	order accepted2 aux 
	drop if aux == 0 // accepted an annuity with ELD or a guaranteed period. 
	drop aux
	
	
	bysort id_certificado_saldo: gen byte first_cert = (_n==1)
	
	tostring periodo_ingreso, replace
	gen month = substr(periodo_ingreso, 5, 6)
	destring month, replace
	
	tab val_uf_rp val_uf_rt // no variation 
	drop val_uf_rp val_uf_rt
	
	label var val_uf_pension "Offer: monthly payment"
	label var val_uf_saldo "Stock of savings"

	save temp4_full, replace
	
	/* 
	Explanation 
	temp: selects only annuiteis (cod_mod ==1) and pensions due to age ("PE") and merges the offers with the acceptance data. 
	
	temp3 takes temp and uses the requests data to get the amount of savings. and also restricts the sample to offers that do not have guarantee nor ELD 
	
	temp4 selects only individuals who chose to buy annuities without guaranteed period nor ELD. 
	
	*/
	





////////////////////////////////////////////////
**# Bookmark #2 Magnitude of search: some basic descriptives.
////////////////////////////////////////////////

	use temp4_full, clear 

	tab year 
	bysort id_certificado_saldo: egen n_ext = total(ind_oferta_externa == "S") // number external offers 

	tab n_ext if first_cert 
	
	gen ext_cat = n_ext // truncated number of external offers. 
	replace ext_cat = 5 if ext_cat > 5
	
	label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5+", replace
	*label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8+", replace

	label values ext_cat extcat

	graph bar (percent) first_cert if first_cert, over(ext_cat)  /// 
	ytitle("Share (%)")  b1title("Number of searches") title("Distribution of search") name("plot1", replace)
	
	graph export "$figures\IE3_dist_external_offers.png", replace
	
	
	graph bar (percent) first_cert if first_cert, over(year) over(ext_cat, gap(200))  ///
	asyvars ytitle("Share (%)") title("Dist. Num. External Offers") ///
	legend(title("Year")) scheme(white_jet) name("plot2", replace)
	
	graph export "$figures\IE3_dist_external_offers_byyear.png", replace
	
	// CDF and hazards. 
	egen total_cert = total(first_cert) // number of certificates 
	bysort ext_cat: egen freq = total(first_cert) // number of people with 
	bysort ext_cat first_cert: gen tag = (_n == _N & first_cert )

	gen cumfreq   = sum(freq)        if tag
	gen survivors = total_cert - (cumfreq - freq) if tag
	gen cdf       = cumfreq / total_cert       if tag
	gen hazard    = freq / survivors           if tag

	twoway line cdf ext_cat if first_cert, sort ///
		xlabel(   ,valuelabel) ytitle("Cumulative share") /// 
		title("CDF of External‐Offer Counts") name("plot3", replace)
		graph export "$figures\IE3_CDF_number_extoffers.png", replace
 
		
	twoway line hazard ext_cat if tag, sort xlabel( ,valuelabel) ///
		ytitle("Hazard rate") title("Hazard of k External Offers") name("plot4", replace)
		graph export "$figures\IE3_hazard_number_extoffers.png", replace
	

////////////////////////////////////////////////
**# Bookmark #3 Search and its relation to income
////////////////////////////////////////////////

			
	use temp4_full, clear 

xtile income_q = val_uf_saldo if first_cert, nq(5)
label define qlab 1 "Q1 (low)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (high)", replace
label values income_q qlab

bysort id_certificado_saldo: egen n_ext = total(ind_oferta_externa=="S")
gen byte ext_cat = min(n_ext,8) if first_cert
label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5+", replace

label values ext_cat extcat

reg n_ext val_uf_saldo if first_cert // richer people search more. 
summarize val_uf_saldo if first_cert
generate double z_saldo = (val_uf_saldo - r(mean)) / r(sd)
regress n_ext z_saldo if first_cert // one standard deviation in income creates .34 extra searches. 

local b_z : display %6.2f _b[z_saldo]
file open texdefs using "$tables/IE3_coefficient1.tex", write replace
file write texdefs "`b_z'" _n
file close texdefs

graph bar (mean) n_ext if first_cert, ///
    over(income_q) ///
    ytitle("Average # External Offers") ///
    title("External Offers by Income Quintile")
graph export "$figures\IE3_search_by_income_quintile.png", replace

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
	
graph export "$figures\IE3_search_CDF_by_income_quintile.png", replace

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
 
graph export "$figures\IE3_search_hazardrate_by_income_quintile.png", replace

// search by gender 

gen male = 1 if sexo == "M" 
replace male = 0 if sexo == "F"

reg n_ext male if first_cert // males search less

local b_z : display %6.2f _b[male]
file open texdefs using "$tables/IE3_coefficient11.tex", write replace
file write texdefs "`b_z'" _n
file close texdefs

graph bar (mean) n_ext if first_cert, ///
    over(male) ///
    ytitle("Average # External Offers") ///
    title("External Offers by gender")
graph export "$figures\IE3_search_by_gender.png", replace // almost no difference in search by gender.



////////////////////////////////////////////////	
**# Bookmark #4 within group are offers the same? 
////////////////////////////////////////////////

	use temp4_full, clear 

	// create groups
	xtile income_q = val_uf_saldo if first_cert, nq(5)
	bysort id_certificado_saldo (income_q): replace income_q = income_q[1]

	xtile income_q2 = val_uf_saldo if first_cert, nq(10)
	bysort id_certificado_saldo (income_q2): replace income_q2 = income_q2[1]

	gen edad = year - agno_nac
	summ edad, d 
	disp `r(p99)'
	histogram edad if edad < `r(p99)'
	
	gen edad_g = edad - mod(edad,5)
	gen edad_g2 = edad - mod(edad,2)

	drop if ind_oferta_externa == "S" // barg. reveals vars we can not conrol for 
	keep id_certificado_saldo edad*  income_q* sex id_participe year  val_uf_saldo  val_uf_pension sec_solicitud_oferta 

	egen group = group(edad_g income_q sex id_participe year) 
	egen group2 = group(edad_g2 income_q2 sex id_participe year) 
	egen group3 = group(edad val_uf_saldo sex id_participe year) 

	// create within group deviations 
	gen ratio = val_uf_saldo / val_uf_pension

	bysort group id_certificado_saldo: drop if _n > 1 
	bysort group: gen size = _N 
	bysort group2: gen size2 = _N 
	bysort group3: gen size3 = _N

	bysort group: egen sd_ratio    = sd(ratio) 
	bysort group2: egen sd_ratio2    = sd(ratio) 
	bysort group2: egen sd_ratio3    = sd(ratio) 

	bysort group: egen sd_offer  = sd(val_uf_pension)
	bysort group2: egen sd_offer2  = sd(val_uf_pension)
	bysort group3: egen sd_offer3  = sd(val_uf_pension)

	bysort group: egen mu_ratio = mean(ratio)
	bysort group2: egen mu_ratio2 = mean(ratio)
	bysort group3: egen mu_ratio3 = mean(ratio)

	bysort group: egen mu_offer = mean(val_uf_pension)
	bysort group2: egen mu_offer2 = mean(val_uf_pension)
	bysort group3: egen mu_offer3 = mean(val_uf_pension)


	gen z_offer = sd_offer / mu_offer 
	gen z_offer2 = sd_offer2 /mu_offer2
	gen z_offer3 = sd_offer3 /mu_offer3

	gen z_ratio = sd_ratio / mu_ratio
	gen z_ratio2 = sd_ratio2 /mu_ratio2
	gen z_ratio3 = sd_ratio3 /mu_ratio3

	// summary stats for the group level deviations 

	estpost summarize z_offer z_offer2 z_offer3 sd_offer3 
	esttab using "$tables/IE3_within_group_dispersion.tex", cells("mean sd min max count") ///
		title("Summary Statistics") replace

	reghdfe ratio, absorb(group) 
	local r2_1 : display %5.2f e(r2)      
	reghdfe ratio, absorb(group2)
	local r2_2 : display %5.2f e(r2)      
	reghdfe ratio, absorb(group3)
	local r2_3 : display %5.2f e(r2)      

	reghdfe val_uf_pension, absorb(group)
	local r2_4 : display %5.2f e(r2)  
	reghdfe val_uf_pension, absorb(group2)  
	local r2_5 : display %5.2f e(r2)      
	reghdfe val_uf_pension, absorb(group3) 
	local r2_6 : display %5.2f e(r2)     

	matrix stats = (`r2_4', `r2_5',  `r2_6')  // `r2_1', `r2_2', `r2_3')

	matrix rownames stats = "Val UF Pension" // Ratio
	matrix colnames stats = Group1 Group2 Group3
	esttab matrix(stats) using "$tables/IE3_coefficient2.tex", replace  nomtitle


////////////////////////////////////////////////	
**# Bookmark #5 dispersion within group for external and internal offers. 
////////////////////////////////////////////////

	use temp4_full, clear 

	// create groups
	xtile income_q = val_uf_saldo if first_cert, nq(5)
	bysort id_certificado_saldo (income_q): replace income_q = income_q[1]
	xtile income_q2 = val_uf_saldo if first_cert, nq(10)
	bysort id_certificado_saldo (income_q2): replace income_q2 = income_q2[1]

	gen edad = year - agno_nac
	summ edad, d 
	gen edad_g = edad - mod(edad,5)
	gen edad_g2 = edad - mod(edad,2)

	egen group = group(edad_g income_q sex id_participe year) 
	//egen group = group(edad_g2 income_q2 sex id_participe year) 
	//egen group = group(edad val_uf_saldo sex id_participe year) 
	
	// keep only one internal and one external offer per individual/group 
	bysort group ind_oferta_externa id_certificado_saldo  : drop if _n > 1 
	bysort group id_certificado_saldo  : keep if _N == 2
	bysort group: keep if _N > 3 // at least two buyers 

	bysort group: egen SD_int_group = sd(val_uf_pension)

	bysort group: egen SD_S = sd( cond(ind_oferta_externa=="S", val_uf_pension, .) )
	bysort group: egen SD_N = sd( cond(ind_oferta_externa=="N", val_uf_pension, .) )

	summarize SD_S
	summarize SD_N
	
	reghdfe val_uf_pension if ind_oferta_externa == "S" , absorb(group)
	reghdfe val_uf_pension if ind_oferta_externa == "N" , absorb(group)
	
////////////////////////////////////////////////	
**# Bookmark #6  dispersion of pension value within choice sets. 
////////////////////////////////////////////////
	
use temp4_full, clear
est clear
bysort id_certificado_saldo: egen sd = sd(val_uf_pension) 
bysort id_certificado_saldo: egen mean = mean(val_uf_pension) 

gen diff_pct = sd / mean // standard deviation in percent 
bysort id_certificado_saldo: egen max = max(val_uf_pension) 
bysort id_certificado_saldo: egen min = min(val_uf_pension) 
gen range = max - min 
gen z_range = (max-min)/ mean

summ diff_pct if first_cert

histogram diff_pct if first_cert, title("Offer dispersion within choice sets") xtitle("% of difference to the mean") note("Includes external and internal offers")
graph export "$figures\IE3_dispertion_choice_set.png", replace

histogram z_range if first_cert,  title("Within choice set range") note("Within each choice set we calculated the range and dived it by the mean of the offers. Includes external and internal offers")
graph export "$figures\IE3_dispertion_choice_set_range.png", replace

estpost summarize diff_pct z_range
esttab using "$tables/IE3_choiceset_dispersion.tex", cells("mean sd min max count") ///
	title("Summary Statistics") replace

	
////////////////////////////////////////////////	
**# Bookmark #7 improvement when searching for external offers 
* how much do the external offer improves on the internal offer of the same firm?   
////////////////////////////////////////////////
	
use temp4_full, clear 
est clear
bysort id_certificado_saldo id_participe sec_solicitud_oferta: gen amount_external = val_uf_pension if ind_oferta_externa == "S"
bysort id_certificado_saldo id_participe sec_solicitud_oferta: egen temp  = max(amount_external)
replace amount_external = temp 
drop temp
replace amount_external = . if ind_oferta_externa == "S"

gen improvement_pct = 100* (amount_external - val_uf_pension)/val_uf_pension 
gen improvement_abs = amount_external - val_uf_pension 

order sexo
	 drop id_aceptacion_oferta-per_dev_uc num_mes_cot-rut_participe ind_condicion_cobertura por_alternativa_art6 ind_eld tipo_monto_eld

local r = 0.003 // monthly rate of return of AFP during last 20 years https://bigdatauls.userena.cl/dashboards/rentabilidad-fondo-de-pensiones/
local n = 20*12 // number of months 
gen improvement_PV20 = improvement_abs * (1 - (1+`r')^(-`n'))/`r'

gen improvement_wage = improvement_PV20 / mto_ult

estpost summarize improvement_abs improvement_pct improvement_PV20 improvement_wage 
esttab using "$tables/IE3_offer_improvement.tex", cells("mean sd min max count") ///
	title("Improvement when searching") replace
	
* improvements by gender. 
est clear
estpost tabstat improvement_abs improvement_pct improvement_PV20 improvement_wage, ///
    by(sexo) statistics(mean sd min max n)
 
* improvement by quintile 
xtile income_q = val_uf_saldo if first_cert, nq(5)
label define qlab 1 "Q1 (low)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (high)", replace
label values income_q qlab

est clear
estpost tabstat improvement_abs improvement_pct improvement_PV20 improvement_wage, ///
    by(income_q) statistics(mean sd min max n)


histogram improvement_wage if improvement_wage < 10 & -1 < improvement_wage, title("PV improvement in terms of last wage") xtitle("PV improvement/monthly wage")
graph export "$figures\IE3_offer_improvement_histogram.png", replace


////////////////////////////////////////////////	
**# Bookmark #8 diff btwn highest initial offer and external offers 
////////////////////////////////////////////////
use temp4_full, clear 
est clear
	 drop id_aceptacion_oferta-per_dev_uc num_mes_cot-val_uf_pension_referencia ind_condicion_cobertura por_alternativa_art6 ind_eld tipo_monto_eld id_inter_oferta_ext-val_uf_comision_inter_o_ext

bysort id_certificado_saldo sec_solicitud_oferta: gen amount_external = val_uf_pension if ind_oferta_externa == "S"
bysort id_certificado_saldo sec_solicitud_oferta: egen temp  = max(amount_external)
replace amount_external = temp 
drop temp

bysort id_certificado_saldo sec_solicitud_oferta: gen amount_internal = val_uf_pension if ind_oferta_externa == "N"
bysort id_certificado_saldo sec_solicitud_oferta: egen temp  = max(amount_internal)
replace amount_internal = temp 
drop temp 

sort id_certificado_saldo sec_solicitud_oferta sec_oferta

bysort id_certificado_saldo sec_solicitud_oferta: gen first_solicitud = 1 if _n == 1 

bysort id_certificado_saldo sec_solicitud_oferta: egen mean_offers = mean(val_uf_pension)  
gen diff = amount_external - amount_internal 
gen diff_pct = 100* diff / mean_offers

estpost summarize diff diff_pct if first_solicitud
esttab using "$tables/IE3_offer_change_max_internal.tex", cells("mean sd min max count") ///
	title("External offer vs. highest initial offer") replace addnote("hola")

 histogram diff_pct
graph export "$figures\IE3_offer_change_max_internal.png", replace


// other way of doing, for each buyer comparing the best initial offer (across al sec_solicitud_oferta) with each one of the external offers.  not the prefered approach because you are comparing an external offer with sec_solicitud_oferta == 1 with internal offers with sec_solicitud_oferta > 1 and this internal offers where not known when bargaining. but the results are almost the same. 

use temp4_full, clear 

gen separation = . 

bysort id_certificado_saldo sec_oferta1: egen temp2 = max(val_uf_pension) if sec_oferta1 == 1 
bysort id_certificado_saldo: egen best_initial_offer = max(temp2) 
gen improvement = val_uf_pension/best_initial_offer -1 if ind_oferta_externa == "S"
bysort id_certificado_saldo: egen has_external = max(ind_oferta_externa == "S")

keep if has_external 
summ improvement, d


////////////////////////////////////////////////	
**# Bookmark #9  number of internal offers 
////////////////////////////////////////////////

use temp4_full, clear 
est clear
	 drop id_aceptacion_oferta-per_dev_uc num_mes_cot-val_uf_pension_referencia ind_condicion_cobertura por_alternativa_art6 ind_eld tipo_monto_eld id_inter_oferta_ext-val_uf_comision_inter_o_ext

drop if ind_oferta_externa == "S" 
bysort id_certificado_saldo sec_solicitud_oferta : gen internal_offers = _N if _n == 1

estpost summarize internal_offers
esttab using "$tables/IE3_number_initial_offers.tex", cells("mean sd min max count") ///
	title("Dist. of number of initial offers") replace 

	
////////////////////////////////////////////////	
**# Bookmark #10 discrete choice. 
////////////////////////////////////////////////

// foregoing highest offer and foregone amount. 

	use temp4_full, clear 
	est clear
	drop id_aceptacion_oferta-per_dev_uc num_mes_cot-val_uf_pension_referencia ind_condicion_cobertura por_alternativa_art6 ind_eld tipo_monto_eld id_inter_oferta_ext-val_uf_comision_inter_o_ext

	gen aux = val_uf_pension if accepted2 == 1
	bysort id_certificado_saldo: egen accepted_amount = max(aux) 

	bysort id_certificado_saldo: egen max_amount = max(val_uf_pension) 

	gen acc_highest = (max_amount <= accepted_amount ) // dummy for accepting highest offer. 

	tab acc_highest if first_cert // around half accept the highest offer 

	quietly summarize acc_highest if first_cert==1
	local share : display %6.3f (1-r(mean))    // e.g. 0.512
	file open texdefs using "$tables/IE3_share_acc_highest.tex", write replace
	file write texdefs "`share'" _n
	file close texdefs

	gen foregone_pct = 100* (max_amount -accepted_amount) / accepted_amount   if acc_highest == 0 
	summ foregone_ // people who do not accept the highest forego a 1.5% higher pension 

	histogram foregone if first_cert == 1, title("Dist. foregone value") xtitle("(Highest offer/Chosen offer -1)%") 
	graph export "$figures\IE3_foregone_hist.png", replace

	local r = 0.003 
	local n = 20*12 
	gen foregonePV20 = (max_amount - accepted_amount) * (1 - (1+`r')^(-`n'))/`r'
	gen foregone_wage = foregonePV20 / mto_ult 

	estpost summarize foregone_pct foregonePV20 foregone_wage 
	esttab using "$tables/IE3_foregone.tex", cells("mean sd min max count") ///
		title("Foregone pension") replace

// estimating clogit 

	* merge with credit ratings 
	rename id_participe rut_compania 
	merge m:1 rut_compania year month using Data/4_clasificacion_riesgo
	keep if _merge == 3 
	drop _merge 
	drop fecha_clasificacion str_ym fecha m_active rating_sd 

	replace accepted2 = 0 if missing(accepted2)

	*standarize vars 
	bysort id_certificado_saldo: egen mu = mean(Nrisk)
	bysort id_certificado_saldo: egen sd = sd(Nrisk)
	gen Nrisk2 = (Nrisk - mu)/ sd
	bysort id_certificado_saldo: egen mu2 = mean(val_uf_pension)
	bysort id_certificado_saldo: egen sd2 = sd(val_uf_pension)
	gen val_uf_pension2 = (val_uf_pension - mu) / sd
	drop mu sd mu2 sd2

	la var Nrisk2 "Standarized risk score"
	la var val_uf_pension2 "Standarizd amount"
	eststo model1: clogit accepted2 val_uf_pension2 Nrisk2 i.rut_compania, group(id_certificado_saldo)
	esttab model1 using "$tables/IE3_clogit.tex", replace ///
		title("Acceptance (clogit) Results")     /// adds a caption/title
		keep(val_uf_pension2 Nrisk2) label   /// use variable labels if you have them
		b(3) se(3)                              /// 3 decimals; se in parentheses
		star(* 0.10 ** 0.05 *** 0.01)            /// significance stars
		stats(N, fmt(%9.0gc) labels("Obs."))     /// number of obs.
		nomtitles noobs                       /// drop model titles & obs row
		  addnote("Variables are standarized at the choice set level") 
		
		
	margins, dydx(val_uf_pension2 Nrisk2)
	
////////////////////////////////////////////////	
**# Bookmark #11 relation between death and external offers
////////////////////////////////////////////////
	
	
use temp4_full, clear 
est clear
drop id_aceptacion_oferta-id_aceptante per_dev_uc num_mes_cot-val_uf_pension_referencia ind_condicion_cobertura por_alternativa_art6 ind_eld tipo_monto_eld id_inter_oferta_ext-val_uf_comision_inter_o_ext


gen dead = 0 if missing(agno_fall) 
replace dead  = 1 if !missing(agno_fall)
	
// are people who die more likely to request an ext offer? 
	bysort id_certificado_saldo: egen has_external = max(ind_oferta_externa == "S")
		
	tabulate dead has_external if first_cert, col
	tabulate dead has_external if first_cert, row

	gen has_ex_alive = has_external if dead ==0 & first_cert == 1
	gen has_ex_dead = has_external if dead == 1 & first_cert == 1
	est clear
	estpost tabulate dead has_external if first_cert

	
	esttab using "$tables/IE3_dead_has_external.tex", ///
		cell(b) unstack noobs nonumber nomtitle ///
		title("Cross-tabulation of Death Status and External Status") ///
		replace

	estpost summarize has_ex_alive has_ex_dead
	esttab using "$tables/IE3_dead_has_external2.tex", cells("mean sd min max count") ///
		title("") replace

			
	eststo model: logit has_external dead i.year val_uf_saldo, vce(robust)

	esttab model using "$tables/IE3_dead_external_logi.tex", replace ///
		title("Acceptance (clogit) Results")     /// adds a caption/title
		keep(val_uf_saldo dead) label   /// use variable labels if you have them
		b(3) se(3)                              /// 3 decimals; se in parentheses
		star(* 0.10 ** 0.05 *** 0.01)            /// significance stars
		stats(N, fmt(%9.0gc) labels("Obs."))     /// number of obs.
		nomtitles noobs  addnote("Includes year fixed effects")                     
		
	preserve 
	keep if first_cert 
	prtest has_external, by(dead) 
	restore

//  do sick individuals get higher increases when bargaining? 
		
	bysort id_certificado_saldo id_participe sec_solicitud_oferta: gen amount_external = val_uf_pension if ind_oferta_externa == "S"
	bysort id_certificado_saldo id_participe sec_solicitud_oferta: egen temp  = max(amount_external)
	replace amount_external = temp 
	drop temp
	replace amount_external = . if ind_oferta_externa == "S"
	gen improvement_pct = 100* (amount_external - val_uf_pension)/val_uf_pension

	ttest improvement_pct, by(dead)

	est clear
	estpost ttest improvement_pct, by(dead)

	esttab using "$tables/IE3_ttest_improvement_pct.tex", ///
		cells("mu_1(fmt(3) label(Mean Dead=0)) mu_2(fmt(3) label(Mean Dead=1)) b(star fmt(3) label(Difference)) se(fmt(3) label(Std. Error)) t(fmt(3) label(t-statistic)) p(fmt(3) label(p-value))") ///
		wide nonumber nomtitle ///
		title("T-test: Improvement Percentage by Death Status") ///
		note("*** p<0.01, ** p<0.05, * p<0.1") ///
		replace
		
	eststo model: reg improvement_pct dead i.year


		esttab model using "$tables/IE3_dead_on_improvements.tex", replace ///
			title("Effect of bad health on negotiation gains")     /// adds a caption/title
			keep(dead) label   /// use variable labels if you have them
			b(3) se(3)                              /// 3 decimals; se in parentheses
			star(* 0.10 ** 0.05 *** 0.01)            /// significance stars
			stats(N, fmt(%9.0gc) labels("Obs."))     /// number of obs.
			nomtitles noobs  addnote("Includes year fixed effects")  	
		
		
////////////////////////////////////////////////
**# Bookmark #12 supply 
////////////////////////////////////////////////
	
use temp4_full, clear 
est clear
 

* Keep only accepted offers
keep if accepted2 == 1
gen age = year - agno_nac
gen age_bin = floor((age)/5)*5 // 5-year bins 
xtile age_q = age, nq(5) 
xtile income_q = val_uf_saldo, nq(5)


bysort age: gen total_age = _N
bysort age_bin: gen total_bin = _N
bysort income_q: gen total_quin = _N 
bysort age_q: gen total_age_quin = _N 

bysort age id_participe: gen sold = _N 
bysort age_bin id_participe: gen sold_bin = _N 
bysort income_q id_participe: gen sold_quin = _N 
bysort age_q id_participe: gen sold_age_quin = _N 

gen share_age = sold/total_age 
gen share_bin = sold_bin / total_bin 
gen share_inc_q = sold_quin / total_quin
gen share_age_q = sold_age_quin / total_age_quin

keep total* age* sold* share* id_participe income_q age_q

preserve 
keep age_q share_age_q id_participe sold_age_quin total_age_quin
drop  sold_age_quin total_age_quin
duplicates drop
bysort id_participe: egen aux = mean(share_age_q) 
drop if aux < .06 
drop aux 
rename share_age_q firm 
tostring id_participe, replace
replace id_participe = substr(id_participe, 1,4)
destring id_participe, replace
reshape wide firm, i(age_q) j(id_participe)
twoway line firm* age_q, sort title("Market Share by age quintile") ///
    ytitle("Market Share") xtitle("Age quintile")
graph export "$figures\IE3_supply_age_quintile.png", replace
restore 


preserve 
keep income_q share_inc_q id_participe sold_quin total_quin
drop sold_quin total_quin
duplicates drop
bysort id_participe: egen aux = mean(share_inc_q) 
drop if aux < .06 
drop aux 
rename share_inc_q firm 
tostring id_participe, replace
replace id_participe = substr(id_participe, 1,4)
destring id_participe, replace
reshape wide firm, i(income_q) j(id_participe)
twoway line firm* income_q, sort title("Market Share by income quintile") ///
    ytitle("Market Share") xtitle("Income quintile")
graph export "$figures\IE3_supply_income_quintile.png", replace
restore 


preserve 
drop if age > 69
bysort id_participe: egen aux = min(sold) 
drop if aux < 10
drop aux
keep age share_age id_participe 
duplicates drop
reshape wide share_age, i(age) j(id_participe)
twoway line share* age, sort title("Market Share by Age") ///
    ytitle("Market Share") xtitle("Age")
graph export "$figures\IE3_supply_age.png", replace
restore 


preserve 
drop if age > 69
bysort id_participe: egen aux = min(sold) 
drop if aux < 10
drop aux
keep age_bin share_bin id_participe 
duplicates drop
reshape wide share_bin, i(age_bin) j(id_participe)
twoway line share* age, sort ///
    title("Market Share by Age bin") ///
    ytitle("Market Share") xtitle("Age bin")
graph export "$figures\IE3_supply_agebin.png", replace
restore 
	
////////////////////////////////////////////////
**# Bookmark #13 supply2
////////////////////////////////////////////////
	
use temp4_full, clear 
est clear
 
keep if ind_oferta_externa == "N" // keep only initial offers. 
drop periodo_ingreso-val_uf_monto_eld
gen age = year - agno_nac
xtile age_q = age, nq(5) 
xtile income_q = val_uf_saldo, nq(5)

duplicates report  id_certificado_saldo sec_solicitud_oferta id_participe // THIS IS  APROBLEM I DO NOT UNDERSTAND WHY IS IT THE CASE THAT THERE ARE DUPLICATES. 

egen requests_age = nvals(id_certificado_saldo sec_solicitud_oferta), by(age) 
egen requests_age_q = nvals(id_certificado_saldo sec_solicitud_oferta), by(age_q) 
egen requests_income_q = nvals(id_certificado_saldo sec_solicitud_oferta), by(income_q) 

egen offers_age = nvals(id_certificado_saldo sec_solicitud_oferta), by (age id_participe) 
egen offers_age_q = nvals(id_certificado_saldo sec_solicitud_oferta), by (age_q id_participe) 
egen offers_income_q = nvals(id_certificado_saldo sec_solicitud_oferta), by (income_q id_participe) 

gen share_age = offers_age / requests_age
gen share_age_q = offers_age_q / requests_age_q
gen share_income_q = offers_income_q / requests_income_q

keep offers* age* request* share* id_participe income_q age_q


preserve 
keep age requests_age offers_age share_age id_participe
drop if requests < 500
duplicates drop 
drop requests offers 
reshape wide share, i(age) j(id_participe)
twoway line share* age, sort title("Probability of offer by age") ///
    ytitle("Offer probability") xtitle("Age")
graph export "$figures\IE3_supply_offerprob_age.png", replace
restore 


preserve 
keep age_q requests_age_q offers_age_q share_age_q id_participe
 duplicates drop 
drop requests offers 
reshape wide share, i(age) j(id_participe)
twoway line share* age, sort title("Probability of offer by age quintile") ///
    ytitle("Offer probability") xtitle("Age Quintile")
graph export "$figures\IE3_supply_offerprob_age_q.png", replace

restore 

preserve 
keep income_q requests_income_q offers_income_q share_income_q id_participe
duplicates drop 
drop requests offers 
rename share_income_q firm 
tostring id_participe, replace
replace id_participe = substr(id_participe, 1,4)
destring id_participe, replace
reshape wide firm, i(income_q) j(id_participe)
twoway line firm* income, sort title("Probability of offer by income quintile") ///
    ytitle("Offer probability") xtitle("Income Quintile")
graph export "$figures\IE3_supply_offerprob_income_q.png", replace

drop firm9971 firm9984 firm9999 firm1353 firm3451 firm6668 firm5132
twoway line firm* income, sort title("Probability of offer by income quintile") ///
    ytitle("Offer probability") xtitle("Income Quintile")
graph export "$figures\IE3_supply_offerprob_income_q(2).png", replace
restore 
	
////////////////////////////////////////////////
**# Bookmark #14 supply3
////////////////////////////////////////////////
	
use temp4_full, clear
est clear

keep if ind_oferta_externa == "N"

drop periodo_ingreso-val_uf_monto_eld
gen age = year - agno_nac
xtile age_q = age, nq(5)

tempfile base //   base dataset for looping

save `base'

// loop over years 
levelsof year, local(years)
foreach y of local years {

    use `base', clear
    keep if year == `y'

    duplicates report id_certificado_saldo sec_solicitud_oferta id_participe

    egen requests_age_q = nvals(id_certificado_saldo sec_solicitud_oferta), by(age_q)

    egen offers_age_q = nvals(id_certificado_saldo sec_solicitud_oferta), by(age_q id_participe)

    gen share_age_q = offers_age_q / requests_age_q

    keep age_q id_participe share_age_q
    duplicates drop

    reshape wide share_age_q, i(age_q) j(id_participe)

    twoway line share_age_q* age_q, sort ///
        title("Offer probability by age quintile, `y'") ///
        ytitle("Offer probability") xtitle("Age quintile")

    graph export "$figures/IE3_supply_offerprob_age_q_`y'.png", replace
}

 
 


	
////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////
/////////////// worked up to this point ///////////////// 	
	////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////	

	
/*

I wanted to see whether people who are expected to bargain get better or worse offers,
p_ext: ex-ante probability of bargaining 
resid: quality of the offer, a higher resid means that controling for age and gender the offer is good 

since the correlation between p_ext and resid is negative people who are expected to bargain get a lower offer.  

*/ 
use temp4_full, clear

drop id_aceptacion_oferta-id_aceptante per_dev_uc num_mes_cot-val_uf_pension_referencia ind_condicion_cobertura por_alternativa_art6 ind_eld tipo_monto_eld id_inter_oferta_ext-val_uf_comision_inter_o_ext

 

gen age = year - agno_nac
generate male = (sexo == "F")
bysort id_certificado_saldo sec_solicitud_oferta: egen external_any = max(ind_oferta_externa == "S")




drop first_cert 
bysort id_certificado_saldo sec_solicitud_oferta: gen first_cert = (_n ==1)

logit external_any   male val_uf_saldo age if first_cert

predict p_ext if first_cert



gen ratio = log(val_uf_pension/ val_uf_saldo)

reg ratio age male if first_cert
predict resid, residuals

reg resid p_ext




////////////////////////////////////////////////
**# Bookmark #14 look at date of death and whether correlates with something of the external offers. 
////////////////////////////////////////////////
///

drop ind_condicion_cobertura por_alternativa_art6 ind_eld tipo_monto_eld 

drop rut_agente por_comision_aceptada_rv-cod_super_adm_seleccionada