// work with data for only 2014 to make it easier for now

cd .. 

////////////////////////////////////////////////
**# Bookmark #1 Data Cleaning 
////////////////////////////////////////////////


use Data/1_solicitudes_14to18, clear
		
	keep if cod_mod_pension == 1
	drop cod_mod_pension year 
	keep if tipo_consultante == "A"
	drop tipo_consultante
	
use Data/2_ofertas_sol_14to18, clear
	keep if cod_mod == 1
	drop cod_mod
	sort id_certificado_saldo num_meses_garantizados id_oferta
	tab tipo_pension
	keep if tipo_pension == "PE" 
	drop tipo_pension
	
	tab ind_oferta_rta_vit_inmediata
	tab ind_oferta_rta_vit_diferida
	tab ind_oferta_rta_vit_inm_r_pro
	
	drop ind_oferta_rta*
	drop aux
	
	tab num_ano 
	drop periodo_ingreso num_anos_diferidos
	
	tab num_meses_diferidos
	drop num_meses_diferidos
			
	
use Data/2_ofertas_acep_14to18RV, clear

	sort id_certificado_saldo num_meses_garantizados id_oferta

	tab tipo_pension
	keep if tipo_pension == "PE"

	drop tipo_pension
	drop periodo_ingreso
	tab num_anos_diferidos num_meses_diferidos

	drop num_anos_diferidos num_meses_diferidos

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
	
	
merge m:1 id_certificado_saldo using Data/3_aceptaciones_14to18
* I DO NOT UNDERSTAND WHY SOME _merge == 1, I THOUGH THAT ALL THE CERTIFICADO SALDOS HERE WOULD HAVE AN ACCEPTED

keep if _merge == 3
keep if cod_modalidad_pension == 1 // otherwise they accepted offers that are not annuities

save temp, replace
use temp, clear



gen accepted = 1 if id_oferta1 == id_oferta
bysort id_certificado_saldo: egen aux = sum(accepted) 
tab aux 

gen accepted2 = 1 if id_oferta1 == id_oferta & sec_oferta1 == sec_oferta 
bysort id_certificado_saldo: egen aux2 = sum(accepted2) 
tab aux2
** !!!! one problem is that many of the observations are not matched to 

drop if aux2 == 0 // DO NOT UNDERSTAND WHY THE ACCEPTED OFFER IS NOT IN THE OFFERS 
drop aux aux2 accepted
order accepted2 

drop id_oferta sec_oferta	
	

save temp2, replace


use Data/1_solicitudes_14to18, clear 
bysort id_certificado_saldo: egen aux = sd(val_uf_saldo) 
summ aux, d

keep id_certificado_saldo val_uf_saldo year
bysort id_certificado_saldo: keep if _n == 1 
	
save temp3, replace 


use temp2, clear 

merge m:1 id_certificado_saldo using temp3, gen(_merge2) 
keep if _merge2 == 3  

save temp4, replace

use temp4, clear

egen n_unique = nvals(id_certificado_saldo)
tab n_unique 
drop n_unique


keep if num_meses_garantizados == 0 & val_uf_monto_eld == 0 // to compare only simle annuities 


save temp5, replace
	





////////////////////////////////////////////////
**# Bookmark #2 Magnitude of search: some basic descriptives.
////////////////////////////////////////////////


use temp4, clear
	
	bysort id_certificado_saldo: egen n_ext = total(ind_oferta_externa == "S") // number external offers 

	bysort id_certificado_saldo: gen byte first_cert = (_n==1)
	tab n_ext if first_cert 
	
	gen ext_cat = n_ext // truncated number of external offers. 
	replace ext_cat = 5 if ext_cat > 8
	
	*label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5+", replace
	label define extcat 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8+", replace

	label values ext_cat extcat

	graph bar (percent) first_cert if first_cert, over(ext_cat)  /// 
	ytitle("Share (%)") title("Dist. Num. External Offers")

	graph export "Figures\IE2_dist_external_offers.png", replace

	
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
		graph export "Figures\IE2_CDF_number_extoffers.png", replace
 
		
	twoway line hazard ext_cat if tag, sort ///
		xlabel( ,valuelabel) ///
		ytitle("Hazard rate") title("Hazard of k External Offers")
		graph export "Figures\IE2_hazard_number_extoffers.png", replace
	
		
 

////////////////////////////////////////////////
**# Bookmark #3 Search and its relation to income
////////////////////////////////////////////////

			
use temp4, clear

bysort id_certificado_saldo: gen byte first_cert = (_n==1)

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
regress n_ext z_saldo if first_cert // one standard deviation in income creates .8 extra searches. 


graph bar (mean) n_ext if first_cert, ///
    over(income_q) ///
    ytitle("Average # External Offers") ///
    title("External Offers by Income Quintile")
graph export "Figures\IE2_search_by_income_quintile.png", replace

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
	
graph export "Figures\IE2_search_CDF_by_income_quintile.png", replace

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
 
graph export "Figures\IE2_search_hazardrate_by_income_quintile.png", replace






	
////////////////////////////////////////////////	
**# Bookmark #2 within group are offers the same? 
////////////////////////////////////////////////

* group are defined as a combination of 1) savings quintile, 2) 
use temp5, clear

bysort id_certificado_saldo: gen byte first_cert = (_n==1)
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

bysort id_certificado_saldo (accepted2): gen aux = accepted2[1]



drop if ind_oferta_externa == "S"
keep id_certificado_saldo edad  income_q sex id_participe year  val_uf_saldo  val_uf_pension

gen edad_g = edad - mod(edad,5)

gen ratio = val_uf_saldo / val_uf_pension

egen group = group(edad_g income_q sex id_participe year) // offers made by an insurer to individuals that are similar. 
egen group2 = group(edad val_uf_saldo sex id_participe year) 

bysort group: gen size = _N 

bysort group2: gen size2 = _N 
bysort group: egen sd_ratio    = sd(ratio)
bysort group2: egen sd_ratio2    = sd(ratio)

reghdfe ratio, absorb(group)
reghdfe ratio, absorb(group2)







use temp4, clear
br if id_certificado_saldo == 249467
keep if num_meses_garantizados == 0 


gen aux = 1 if val_uf_monto_eld > 0 
replace aux = 0 if val_uf_monto_eld == 0 
tab aux , missing


	

order val_uf_saldo
















 /// variation of pension per dollar of savings. 



gen ratio = val_uf_saldo / val_uf_pension 
histogram ratio 
	
histogram ratio if accepted2 == 1 // still have to control by 

	
	
	
	
	
	

	
	
	
	
	
	
/*
duplicates report id_certificado_saldo id_oferta
bysort id_certificado_saldo id_oferta: gen aux = _N 
sort id_certificado_saldo id_oferta
order id_certificado_saldo id_oferta aux 
*/
foreach var of varlist * {
    rename `var' `var'_1
}


rename id_certificado_saldo_1 id_certificado_saldo
rename id_oferta_1 id_oferta
rename sec_oferta_1 sec_oferta 
rename num_meses_garantizados_1 num_meses_garantizados

merge m:1 id_certificado_saldo  id_oferta sec_oferta using Data/aceptaciones 
drop if _merge == 2 // accepted offers not in the 10% of the sample. 

gen accepted = 1 if _merge == 3 
bysort id_certificado_saldo: egen matched = max(accepted)
tab matched, m 


tab ind_oferta_externa_1 if accepted == 1 // 80% of the accepted offers are external offers. 

//number of external offers 
bysort id_certificado_saldo: egen count_total = total(ind_oferta_externa_1 == "S")
bysort id_certificado_saldo num_meses_garantizados: egen count_garant = total(ind_oferta_externa_1 == "S")

bysort id_certificado_saldo: gen temp = 1 if _n == 1 
tab count_total if temp == 1, m

bysort id_certificado_saldo num_meses_garantizados: gen temp2 = 1 if _n == 1 
tab count_garant if temp2 == 1, m



order id_certificado_saldo count* sec* accepted matched, a(id_oferta)
sort count_garant id_certificado_saldo num_meses_garantizados id_participe_1
br if count_garant < 5 // includes 99% of the combinationf of id_certificado_saldo and num_meses_garantizados
///////////


br if id_certificado_saldo == 4103
br if id_oferta == 16800040
sort id_certificado_saldo id_oferta id_participe_1 num_meses_garantizados 



sort count_total id_certificado num_meses_garantizados id_participe_1

sort id_certificado_saldo id_oferta sec_oferta


drop ind_condicion_cobertura_1 por_alternativa_art6* ind_eld* tipo_monto_eld* tipo_pension_1 
*use Data/aceptaciones, clear