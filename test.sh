#!/bin/bash
set -e

cd BareMetal-AppPort
./clean.sh
./setup.sh
./build-app.sh https_crawler.c
cp https_crawler.app ../BareMetal-Firecracker/sys
cd ..

cd BareMetal-Firecracker
./build.sh https_crawler.app
./baremetal.sh start
sleep 15
./baremetal.sh output --full
cd ..
