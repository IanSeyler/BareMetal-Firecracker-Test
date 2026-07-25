#!/bin/bash
set -e

git clone https://github.com/ReturnInfinity/BareMetal-AppPort
git clone https://github.com/ReturnInfinity/BareMetal-Firecracker
mkdir BareMetal-AppPort/build/
cp files/* BareMetal-AppPort/build
