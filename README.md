# BareMetal-App

A quick way to get going with testing BareMetal-Firecracker, BareMetal-AppPort, and uploading your program to the [BareMetal VPS](https://baremetal.returninfinity.com).

## Clone

Run `git clone https://github.com/ReturnInfinity/BareMetal-App`

## Setup

Run `./setup.sh`

This will complete a "pre-flight" check to verify the per-requisites are installed, pull the required repositories, pull the libraries (if needed), and build them.

## Test

Create a new test C program:

`echo -e '#include <stdio.h>\n\nint main(void) {\n    printf("Hello, World!\\n");\n    return 0;\n}' > hello.c`

Run `./test.sh hello.c`

This will build your program and test it locally. After the test is complete you have the option of uploading it to run on the BareMetal VPS.
