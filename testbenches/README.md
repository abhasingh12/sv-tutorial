# Introduction

This tutorial provides a basic introduction to testbenches and verification using various constructs in SystemVerilog. This is not intended to be a comprehensive tutorial, but 
provides a good starting point. The Universal Verification Methodology (UVM) is recommended for advanced testing.

# Overview

To test a design, we need a module to drive the inputs so we can verify the functionality. That module is usually referred to as a testbench. In its most simple form, a 
testbench simple applies a set of inputs, waits some amount of time for the outputs to change, then applies new inputs. In a slightly more advanced form, the testbench also
verifies that outputs are correct. In more advanced forms, the testbench should check to ensure that certain properties are always true, while also checking for different 
types of coverage (e.g., was every statement tested, were all relevant values tested, were all transitions tested, etc.). There are many strategies ranging from simple ad-hoc
testbench strategies, to more advanced and more formal strategies such as UVM.

# Suggested Study Order

## Basic testbench constructs

In the combinational and sequential logic tutorials, there are examples of non-ideal, but easy to understand testbenches for each examples. We will later improve upon all these
examples, here are are two simple examples to introduce the basic testbench constructs.

1. [2:1 Mux](../combinational/mux2x1_tb.sv)
    - Corresponding [module](../combinational/mux2x1.sv) and [testbench](../combinational/mux2x1_tb.sv).
    - Basic introduction into testbenches. Introduces timescale, waiting, functions, $timeformat, and $display.

1. [Register](../sequential/register_tb.sv)
    - Corresponding [module](../sequential/register.sv) and [testbench](../sequential/register_tb.sv).
    - Introduces clock generation, waiting for rising edges, $random, $stop, $finish, disable.

    
## Assertions

In the basic testbench examples above, we manually check for errors with if statements combined with error messages. Although useful for simple tests, assertions are a much 
more powerful construct that can be used to very that any condition is true at any point in time. Most importantly, assertions can be combined with properties and sequences
to verify complex behaviors concisely. In many cases, assertion propeties can completely eliminate the need for a separate reference model that provides correct functionality 
for comparison.

1. [2:1 Mux (Different than earlier example)](assertions/mux2x1_tb.sv)
    - Corresponding [module](assertions/mux2x1.sv) and [testbench](assertions/mux_2x1_tb.sv).
    - Shows basic syntax for immediate assertions.    
1. [Flip-flop](assertions/ff_tb.sv)
    - Corresponding [module](assertions/ff.sv) and [testbench](assertions/ff_tb.sv).
    - Introduces concurrent assertions (assertion properties) and implication.    
1. [Delay](assertions/delay.sv)
    - Corresponding [module](assertions/delay.sv) and [testbench](assertions/delay_tb.sv).
    - Introduces $past and $stable.
1. [FIFO](assertions/fifo.sv)
    - Corresponding [module](assertions/fifo.sv) and [testbench](assertions/fifo_tb.sv).
    - Introduces access of variables inside other modules, while also demonstrating using assertions to replace a reference model.

## Coverage

Whereas assertions are generally used to check for correct functionality, coverage constructs are used to ensure that desired tests actually occurred. For example, if we only
test 3 input combinations for a module and all the assertions pass, although we haven't found any problems, we have done very little to verify the design.
While there are many types of coverage, we will look at ways of sampling events and values to ensure that all desired tests have actually occurred. With the combination of 
high coverage and no failed assertions, we gain much more confidence in the correct functionality of a design.

1. [FIFO](coverage/fifo_tb.sv)
    - Corresponding [module](coverage/fifo.sv) and [testbench](coverage/fifo_tb.sv).
    - Introduces cover properties.
1. [Add](coverage/add_tb.sv)
    - Corresponding [module](coverage/add.sv) and [testbench](coverage/add_tb.sv).
    - Extends cover properties and introduces cover groups and cover points.

## Classes

1. TBD

## UVM
    
1. TBD