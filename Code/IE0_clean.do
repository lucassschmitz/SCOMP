cd ..
 
global figures "writeup_SCOMP\figures"
global tables "writeup_SCOMP\Tables"
* some plots and transform files into .dta. 
 
////////////////////////////////////////////////////
**# Bookmark #1 Clean '1.solicitudes'
 ////////////////////////////////////////////////////
	import delimited "Data/1_solicitudes/1_solicitudes.csv", clear

	 
	 // understand sources of variation 
	*for a given certificate the savings is constant.
	bysort id_certificado_saldo (val_uf_saldo): gen inconsistent = val_uf_saldo!= val_uf_saldo[1]
	tab inconsistent

	*num_solicitud_oferta varies within certificate but not within certificat-sec_solicitud_oferta pair. 
	bysort id_certificado_saldo (num_solicitud_oferta): gen inconsistent2 = num_solicitud_oferta!= num_solicitud_oferta[1]
	tab inconsistent2

	bysort id_certificado_saldo sec_solicitud_oferta (num_solicitud_oferta): gen inconsistent3 = num_solicitud_oferta!= num_solicitud_oferta[1]
	tab inconsistent3

	duplicates report id_certificado_saldo sec_solicitud_oferta 
	duplicates report id_certificado_saldo sec_oferta_modalidad
	duplicates report id_certificado_saldo sec_oferta_modalidad sec_solicitud_oferta // unique identifier

	* does each group start at 1 and then increment by exactly 1?
	bysort id_certificado_saldo sec_solicitud_oferta (sec_oferta_modalidad): gen byte d = sec_solicitud_oferta - sec_solicitud_oferta[_n-1] if _n>1
	tabulate d

	drop inconsistent* 	d	 
	 
	 
	sort id_certificado_saldo sec_solicitud_oferta sec_oferta_modalidad

	
	bysort id_certificado_saldo: gen N = _N if _n == 1
	summ N, d // on average consumers request 10 quotes for 10.5 products. 
	
	
	histogram periodo_solicitud
	
	label define modalidad_pension 1 "RV inmediata"  2 "R. temporal con renta vitalicia diferida" ///
    3 "RV inmediata con R. prog." 4 "R. Prog."
	
	label values cod_mod_pension modalidad_pension

	tostring periodo_solicitud, gen(aux) 
	gen year = substr(aux, 1, 4) 
	destring year, replace
	drop aux

	save Data/1_solicitudes, replace
	use Data/1_solicitudes, clear
	
	
	keep if inrange(year, 2012, 2019) 
	keep if cod_mod_pension == 1 
	drop cod_mod_pension
	tab num_anos_diferidos num_meses_diferidos // no variation 
	drop num_anos_diferidos num_meses_diferidos
	save Data/1_solicitudes_12to19RV, replace
	
	// Descriptives
	use Data/1_solicitudes, clear
	
	keep if inrange(year, 2006, 2018)
	graph bar (count) id_certificado_saldo, over(year, gap(1)) /// 
		title("Requests by year") 	b1title("Year") note("An individual makes multiple requests.")
	graph export "$figures\IE0_plot0.png", replace

		
		gen val_uf_saldo2 = val_uf_saldo
		summ val_uf_saldo, d
		replace val_uf_saldo2 = r(p99) if val_uf_saldo2 > r(p99)
		
		histogram val_uf_saldo2 
	graph export "$figures\IE0_plot1.png", replace


 

* 2) Compute, for each (year × modality), the number of requests
bysort year cod_mod_pension: egen req_count = count(sec_oferta_modalidad)

* 3) Tag one observation per (year × modality) so we don't overplot
bysort year cod_mod_pension: gen byte toplot = (_n==1)

  
 twoway  ///
  (line req_count year if cod_mod_pension==1 & toplot, sort) ///
  (line req_count year if cod_mod_pension==2 & toplot, sort) ///
  (line req_count year if cod_mod_pension==3 & toplot, sort) ///
  (line req_count year if cod_mod_pension==4 & toplot, sort) ///
,  ///
 xlabel(2006(2)2017)  ///
  xtitle("Year")  ytitle("Number of Requests") title("Evolution of Requests by Pension Modality") ///
  plotregion(margin(10 0 0 0))  /// ← adds extra space at top so title/legend don't overlap the lines
  legend( ///
    order(1 "RV inmediata"  2 "R. temporal con renta vitalicia diferida" 3 "RV inmediata con R. prog."  4 "R. Prog.")  ///
    ring(1) pos(5) cols(2) )
 
 graph export "$figures\IE0_plot2.png", replace


 bysort year: egen total_req = total(req_count) if toplot
gen share = req_count / total_req if toplot 
  twoway ///
  (line share year if toplot & cod_mod_pension==1, sort) ///
  (line share year if toplot & cod_mod_pension==2, sort) ///
  (line share year if toplot & cod_mod_pension==3, sort) ///
  (line share year if toplot & cod_mod_pension==4, sort) ///
, ///
 xlabel(2009(2)2017)  ///
  xtitle("Year")                ///
  ytitle("Share of Requests")   ///
  title("Share of Requests by Pension Modality") ///
  legend(                       ///
    order(1 "RV inmediata"      ///
          2 "R. temporal con renta vitalicia diferida" ///
          3 "RV inmediata con R. prog."  ///
          4 "R. Prog.")        ///
    ring(1) pos(5) cols(2)      ///
  )
  
graph export "$figures\IE0_plot3.png", replace
  
  
	
* 1) Count requests by balance and modality, tag one obs per (saldo × modality)
bysort val_uf_saldo2 cod_mod_pension: egen req_count2 = count(sec_oferta_modalidad)
bysort val_uf_saldo2 cod_mod_pension: gen byte toplot2 = (_n==1)

* 2) Compute total requests at each balance and share by modality
bysort val_uf_saldo2: egen total_req2 = total(req_count2) if toplot2
gen share2 = req_count2 / total_req2 if toplot2


* 3b) Plot share vs. balance
twoway  ///
  (line share2 val_uf_saldo2 if toplot2 & cod_mod_pension==1, sort) ///
  (line share2 val_uf_saldo2 if toplot2 & cod_mod_pension==2, sort) ///
  (line share2 val_uf_saldo2 if toplot2 & cod_mod_pension==3, sort) ///
  (line share2 val_uf_saldo2 if toplot2 & cod_mod_pension==4, sort) ///
, ///
  xtitle("Certificate Balance (UF)") ytitle("Share of Requests")          ///
  title("Share of Requests by Pension Modality across UF Balances") ///
  legend(                              ///
    order(1 "RV inmediata"             ///
          2 "R. temporal con renta vitalicia diferida" ///
          3 "RV inmediata con R. prog." ///
          4 "R. Prog.")               ///
    ring(1) pos(5) cols(2))

graph export "$figures\IE0_plot4.png", replace


bysort id_certificado_saldo: egen n_requests = nvals(sec_solicitud_oferta)
bysort id_certificado_saldo: gen byte first_cert = (_n == 1)
estpost tabulate n_requests if first_cert, missing
drop first_cert

esttab using "$tables/IE0_requests_per_certificate.tex", ///
    cells("count(fmt(0))")           ///
    varlabels(n_requests "Requests per Certificate") ///
    nonumber nomtitle replace	
	
set seed 20250618
gen byte sample1 = runiform() < 0.01

twoway scatter num_meses_diferidos num_meses_garantizados if sample1, jitter(2) ///
    xtitle("Guaranteed Months") ///
    ytitle("Deferred Months") ///
    title("Guaranteed vs. Deferred Months ") ///
    by(cod_mod_pension, cols(2) ///
        title("By Pension Modality") ///
        note("Sampled 1% to reduce overplotting")) ///
    legend(off)
graph export "$figures\IE0_plot5.png", replace

* clean up
drop sample1	
	
drop val_uf_saldo2-n_requests
	
	
////////////////////////////////////////////////////
**# Bookmark #2 Clean '5.beneficiarios' 
 ////////////////////////////////////////////////////
  
  
	import delimited "Data/5_beneficiarios/5_beneficiarios.csv", clear
	 
	label define parentesco ///
		1 "Cónyuge sin hijos"  2  "Cónyuge con hijos"  3 "Hijo de cónyuge"   /// 
		4 "Hijo p/m con derecho" 5 "Hijo p/m sin derecho" 6 "Padre/madre sin hijos"  /// 
		7 "Padre/madre con hijos" 8 "Padre afiliado" 9 "Madre afiliado" 10 "Conviviente sin hijos" ///
		11 "Conviviente con hijos comunes"  12 "Conviviente c/comunes y causante" ///
		13 "Conviviente sólo causante"  14 "Hijo de conviviente"              
	label values cod_parentesco parentesco

	 
	tab sec_beneficiario cod_parentesco 
	 
	save Data/5_beneficiarios, replace
	 
 
 
 
 
 ////////////////////////////////////////////////////
**# Bookmark #3 Clean '2.ofertas_muestra_sol'
 ////////////////////////////////////////////////////
import delimited "Data/2_ofertas_muestra_sol/2_ofertas_sample_sol.csv", clear 
 
sort id_oferta 
keep if cod_modalidad_pension ==  1 

save Data/2_ofertas_sol, replace 
use Data/2_ofertas_sol, clear
tostring periodo_ingreso, gen(aux) 
gen year = substr(aux, 1, 4)
gen month = substr(aux, 5, 6)

destring year month, replace
keep if inrange(year, 2012, 2019) 

save Data/2_ofertas_sol_12to19, replace 
