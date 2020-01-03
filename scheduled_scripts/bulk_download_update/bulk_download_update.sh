#!/bin/bash

conda activate sp
#source /home/aaron/sp/spenv/bin/activate
#fp_base="/home/mike/git/streampulse/server_copy/sp/"
fp_base="/home/aaron/sp/"
fp_bulk="../bulk_download_files/"
fp_py="scheduled_scripts/bulk_download_update/bulk_download_update.py"
python "$fp_base$fp_py"
globcsv="??.csv"

cd /var/lib/mysql-files/

#for fn in 'all_sp_data' 'all_neon_data' 'all_powell_data'
for fn in 'all_sp_data' 'all_neon_data'
do
    #change ownership of file from mysql to aaron
    #chown mike:mike $fn'.csv'
    chown aaron:aaron $fn'.csv'

    #move file to bulk file folder and change wd to that folder
    mv $fn'.csv' "$fp_base$fp_bulk"
    cd $fp_base$fp_bulk

    #replace \N with empty string
    sed -e 's/\\N/""/g' -i $fn'.csv'

    #split CSVs into 1GB chunks without breaking lines
    #split -C 1000m $fn'.csv' $fn -a 2 --additional-suffix=.csv --numeric-suffixes=1
    split -C 1000m $fn'.csv' $fn -a 2 --additional-suffix=.csv --hex-suffixes=1

    #replace header in all chunks and remove original file
    sed -i "1i $(head -n 1 $fn'.csv')" $fn$globcsv
    rm $fn'.csv'

    #zip together and remove CSVs
    zip -r $fn'.zip' $fn$globcsv
    rm $fn$globcsv

    #go back to mysql output folder
    cd /var/lib/mysql-files
done

for fn in 'all_grab_data' 'all_daily_model_results' 'all_model_summary_data'
do
    #fn="all_sp_data"
    #chown mike:mike $fn'.csv'
    chown aaron:aaron $fn'.csv'
    mv $fn'.csv' "$fp_base$fp_bulk"
    cd $fp_base$fp_bulk
    sed -e 's/\\N/""/g' -i $fn'.csv'
    #sed -e 's/\\N/"NA"/g; s/""/"NA"/g' -i $fn'.csv'
    zip $fn'.csv.zip' $fn'.csv'
    rm $fn'.csv'
    cd /var/lib/mysql-files
done

conda deactivate sp
