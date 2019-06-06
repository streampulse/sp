SPsites.csv doesn't appear to be used for anything
sitelist.csv is used for mapping GMT offsets to core sites so that raw logger files can be ingested. it's also the de facto catalogue of core site names. this file is currently edited manually. users supply the relevant site data through correspondence before they upload data for the new site. pretty crude. however, modifying the upload data flow to allow this stuff to be entered by the user would require massive reworking.
another related problem: GMT offsets change with DST. this file does not take that into account. Pretty big problem. Not enough time to solve it atm.
sitelist_pseudo_core.csv allows leveraged sites to upload raw logger files. works just like sitelist.csv
