 cd ..
 
//////////// //////////// //////////// ////////////
**# Bookmark #1 Clean '3.Aceptaciones' 
//////////// //////////// //////////// ////////////

import delimited "Data/3_aceptaciones/3_aceptaciones.csv", clear 

duplicates report id_certificado_saldo
duplicates report  id_oferta
duplicates report id_certificado_saldo sec_bene // IS ID: no duplicates. 

bysort id_certificado_saldo: gen aux = _N 
sort aux id_certificado_saldo sec_bene
order aux id_certificado_saldo sec_bene
drop aux 

// check variation within id_certificado_saldo 

	* First, get list of all variables except the identifier variables and aux
	ds id_certificado_saldo sec_beneficiario , not
	local varlist `r(varlist)'

	* Create consistency indicators for all variables
	foreach var of local varlist {
		capture drop `var'_v
		bysort id_certificado_saldo: gen `var'_v = (`var' != `var'[1])
	}

	* Summarize to see if any groups have variations
	foreach var of local varlist {
		display "Variable: `var'"
		tab `var'_v
		display "---"
	}

	drop *_v
		
	bysort id_certificado_saldo (sec_beneficiario): keep if _n == 1 
	tab sec_beneficiario
	drop sec_beneficiario
	
tostring periodo_aceptacion, gen(aux) 
gen year = substr(aux, 1, 4)
drop aux
destring year , replace

save Data/3_aceptaciones, replace 
use Data/3_aceptaciones, clear

keep if inrange(year, 2012, 2019)

save Data/3_aceptaciones_12to19, replace 
 
//////////// //////////// //////////// ////////////
**# Bookmark #2  Clean '4.clasificacion_riesgo'
//////////// //////////// //////////// ////////////

import delimited "Data/4_clasificacion_riesgo\4_clasificacion_riesgo.csv", clear

tab clasificacion

tostring fecha_clasificacion, gen(str_ym) format(%06.0f)   
gen year = substr(str_ym, 1, 4)
gen month = substr(str_ym, 5, 5)
destring year month, replace
gen fecha = ym(year, month)
format fecha %tmMon_YY 


gen Nrisk = 0 if strpos(clasificacion, "E") > 0 
replace Nrisk = 2 if strpos(clasificacion, "B") > 0
replace Nrisk = 5 if strpos(clasificacion, "BB") > 0 
replace Nrisk = 8 if strpos(clasificacion, "BBB") > 0 
replace Nrisk = 11 if strpos(clasificacion, "A") > 0
replace Nrisk = 14 if strpos(clasificacion, "AA") > 0 
replace Nrisk = 17 if strpos(clasificacion, "AAA") > 0 

replace Nrisk = Nrisk + 1 if strpos(clasificacion, "+") > 0 
replace Nrisk = Nrisk - 1 if strpos(clasificacion, "-") > 0 

bysort rut_compania: gen m_active = _N
drop if m_active < 24  
drop if Nrisk == 0 // probably error, since by law they are not allowed to sell 


bysort rut_compania: egen rating_sd = sd(Nrisk)

sort rut_compania fecha 
twoway ///
    (line Nrisk fecha if rut_compania == 40507147, legend(label(1 "40507147")))   ///
    (line Nrisk fecha if rut_compania == 13160011, legend(label(2 "13160011"))) ///
	(line Nrisk fecha if rut_compania == 51324851, legend(label(3 "51324851"))),  ///
    ylab(0(1)17, valuelabel angle(h))    ///
    xtitle("Month") ytitle("Credit rating (higher = better)")  ///
    title("Credit-rating history for two companies")  ///
    legend(order(1 2 3) col(1) size(small))
graph export "Figures/IE1_credit_history.png", replace

	
xtset rut_compania fecha
 xtline Nrisk, overlay                           /// one line per company
       ylab(0(1)17, valuelabel angle(h))        /// show rating labels
       ytitle("Credit rating")  xtitle("Month") legend(col(1) size(small))  ///
       title("Evolution of credit ratings by company")
	   

//////////// //////////// //////////// ////////////
**# Bookmark #3 Clean '2_ofertas_muestra_acep'
//////////// //////////// //////////// ////////////

import delimited "Data/2_ofertas_muestra_acep/2_ofertas_sample_acep.csv", clear // rowrange(1:1000000)

// label vars 
label define modalidad_pension 1 "RV inmediata"  2 "R. temporal con renta vitalicia diferida" ///
    3 "RV inmediata con retiro programado"
label values cod_modalidad_pension modalidad_pension

la var id_participe "Insurer" // same numbers as the file "4_clasificacion_riesgo"
la var tipo_int "Tipo intermediario"
la var ind_oferta_externa "Indicador Oferta externa"
// 

tostring periodo_ingreso, gen(aux) 
gen year = substr(aux, 1, 4)
gen month = substr(aux, 5, 6)
drop aux
destring year month, replace
drop if year < 2006 | year > 2019


keep if cod_modalidad_pension ==  1 
drop cod_modalidad_pension ind_oferta_rta_vit_inmediata ind_oferta_rta_vit_diferida ind_oferta_rta_vit_inm_r_pro 

tab num_anos_diferidos  num_meses_diferidos   //no variation in this vars
tab  val_uf_renta_temporal //no variation in this vars

graph bar (mean) val_uf_pension, ///
    over(year) ytitle("Offer in UF") ///
    title("Average Offer by Year") note("The sample are accepted offers with a simple annuity, excluded contracts combining PW with an annuity.")

tab ind_oferta_externa // only 2% of the offers are external. 

//which variables vary within id_oferta : no variable is fixed within id_oferta 
	preserve 
	bysort id_oferta: gen aux = _N 
	drop if aux == 1 
	drop aux
		ds id_oferta, not
		local varlist `r(varlist)'

		* Create consistency indicators for all variables
		foreach var of local varlist {
			bysort id_oferta: gen `var'_vo = (`var' != `var'[1])
		}

		* Summarize to see if any groups have variations
		foreach var of local varlist {
			display "Variable: `var'"
			tab `var'_vo
			display "---"
		}
	restore

save Data/2_ofertas_acep_sampleRV, replace
use Data/2_ofertas_acep_sampleRV, clear

keep if inrange(year, 2012, 2019)
	
save Data/2_ofertas_acep_12to19RV, replace
