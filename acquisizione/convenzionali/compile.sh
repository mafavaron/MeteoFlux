#!/bin/bash
./setup_ad4000.py            build_ext --inplace
./setup_aggregation_funcs.py build_ext --inplace
./setup_almpro.py            build_ext --inplace
./setup_base_funcs.py        build_ext --inplace
./setup_dataset.py           build_ext --inplace
./setup_file_mgmt.py         build_ext --inplace
./setup_local_site.py        build_ext --inplace
./setup_msglog.py            build_ext --inplace
./setup_nrt.py               build_ext --inplace
./setup_process.py           build_ext --inplace
./setup_rs485.py             build_ext --inplace
./setup_sa8000.py            build_ext --inplace
./setup_timing.py            build_ext --inplace
