cd ..
global figures "writeup_SCOMP\figures"
global tables "writeup_SCOMP\Tables"


////////////////////////////
// Save the data in chuncks as a .dta 
	local chunk_size =  5e6 
		
	local row_start = (`part' - 1) * `chunk_size' + 1
	disp `row_start'
	while 1 {
		local row_end = `row_start' + `chunk_size' - 1
		
		// Try importing a chunk
		capture noisily import delimited "Data/2_ofertas/2_ofertas.csv", clear rowrange(`row_start':`row_end')
		
		// Check if the import succeeded (0 = success, nonzero = failure)
		if _rc != 0 {
			di as txt "No more rows to import. Stopping loop."
			continue, break
		}
		
		 if _N == 0 {
			di as txt "No rows imported. Stopping loop."
			continue, break
		}

		// Save this chunk
		save "Data/2_ofertas/part`part'.dta", replace

		// Prepare for next chunk
		local row_start = `row_end' + 1
		local part = `part' + 1
	}

/////////////////////////////////////////////////
// Select only annuities and join the chuncks

* Create an empty dataset to start
clear
gen temp = .
save "Data/2_ofertas.dta", replace

* Loop through all the files
forvalues part = 1/29 {
    * Load the chunk
    use "Data/2_ofertas/part`part'.dta", clear
    
    * Apply the selection
    keep if cod_modalidad_pension == 1
	tostring periodo_ingreso, gen(aux) 
	gen year = substr(aux, 1, 4) 
	destring year, replace
	drop aux
	keep if inrange(year, 2012, 2019)
    
    * Append to main dataset
    append using "Data/2_ofertas.dta"
    
    * Save as main (replacing the previous version)
    save "Data/2_ofertas.dta", replace
    
    * Display progress
    di as txt "Processed and appended part `part'"
}

* Drop the temporary variable if it still exists
capture drop temp

* Save the final dataset
save "Data/2_ofertas.dta", replace

di as txt "All files processed and merged successfully"