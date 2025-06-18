cd ..
 
import delimited "Data/2_ofertas_muestra_sol/2_ofertas_sample_sol.csv", clear 
 
sort id_oferta 
keep if cod_modalidad_pension ==  1 

save Data/2ofertas_sol, replace 
use Data/2ofertas_sol


/*
hypothesis 
- id_oferta: unique id for each offer -> should not have repeated values (F: does have repeated values)

sec_oferta: 


--- isid id_oferta sec_oferta -> not unique identifier. I do not understand exactly what 


*/ 

isid id_oferta 
duplicates report id_oferta 
isid id_oferta sec_oferta
duplicates report id_oferta sec_oferta

isid id_oferta id_certificado
duplicates report id_oferta id_certificado

by id_certificado: gen N = _N 
by id_certificado: gen temp  = (_n == 1)  
tab N if temp == 1  
summ N if temp == 1 

bysort id_certificado: egen aux = max(val_uf_pension)
bysort id_certificado: egen aux2 = min(val_uf_pension)
gen range = aux - aux2
bysort id_certificado: egen sd = sd(val_uf_pension)

summ range if temp == 1 // mean 3 
summ val_uf_pension if temp == 1 // mean 12 
summ sd if temp == 1 // mean 1


estpost summarize range val_uf_pension aux3 if temp==1 

 sort id_certificado id_oferta