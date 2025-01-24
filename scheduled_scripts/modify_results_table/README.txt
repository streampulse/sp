this stuff is not actually "scheduled." rather, modifications to sp/shiny/model_viz/data trigger one of update_results.R, delete_results.R.

the results_setup.R was only run once, after i set up the results table in the database.

if you ever need to manually move outputs from sp/shiny/model_viz/former_best_models back into /sp/shiny/model_viz/data, be sure to move the modOut file before moving the predictions file. Likewise if youadding outputs to the data folder for any reason. it's the predictions file that triggers automatic update of the database via /home/aaron/bin/inotifywait_dispatch.sh.
