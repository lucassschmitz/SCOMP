cd ..
 
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
	
save Data/aceptaciones, replace 
use Data/aceptaciones, clear