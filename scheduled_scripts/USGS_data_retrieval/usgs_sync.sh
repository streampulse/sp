#!/bin/bash
conda activate sp
#source /home/aaron/sp/spenv/bin/activate
python /home/aaron/sp/scheduled_scripts/USGS_data_retrieval/usgs_sync.py
conda deactivate

