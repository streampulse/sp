#!/bin/bash
conda activate sp
#source /home/aaron/sp/spenv/bin/activate
python /home/aaron/sp/scheduled_scripts/sitelist_update_neon.py
conda deactivate
