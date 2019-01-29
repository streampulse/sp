site_update_stored_procedure.sql updates the variableList and coverage fields in the sitelist tables

it is called by sitelist_update_one-off.py (manual)
    usgs_sync.py (on cron schedule)
    update_neon_site_data.py (on cron schedule)
    app.py (whenever someone uploads new data)
