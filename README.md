# Systolic-Array-for-Matrix-Multiplication
This repository contains the design of the following:

1.Processing element: does multiplication and accumulation
2.Counter: A simple counter that counts from 0 to N_SIZE – 1, used as MUX selector to pass PEs output
3.Simple pipelining register
4.Systolic Array: Top module: instantiate PEs grid, delaying registers, MUXes and counter and connect them all with internal 
wires
5.Testbench
