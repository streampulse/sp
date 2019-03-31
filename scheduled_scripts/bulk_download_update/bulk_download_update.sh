#!/bin/bash

#conda activate python2
source /home/aaron/sp/spenv/bin/activate
#fp_base="/home/mike/git/streampulse/server_copy/sp/"
fp_base="/home/aaron/sp/"
fp_bulk="../bulk_download_files/"
fp_py="scheduled_scripts/bulk_download_update/bulk_download_update.py"
python "$fp_base$fp_py"

cd /var/lib/mysql-files/

#for fn in 'all_sp_data' 'all_neon_data' 'all_grab_data' 'all_daily_model_results' 'all_model_summary_data' 'all_powell_data'
for fn in 'all_sp_data' 'all_neon_data' 'all_grab_data' 'all_daily_model_results' 'all_model_summary_data'
do
    #fn="all_sp_data"
    #chown mike:mike $fn'.csv'
    chown aaron:aaron $fn'.csv'
    mv $fn'.csv' "$fp_base$fp_bulk"
    cd $fp_base$fp_bulk
    zip $fn'.csv.zip' $fn'.csv'
    rm $fn'.csv'
    cd /var/lib/mysql-files
done
