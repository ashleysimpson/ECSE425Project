# Group 7 assembler
# ECSE 425

import math
import re
import io
import sys
import os

# method that formats the code for binary conversion
def format_code(file):
    
    # opens the input file (MIPS code) and an output file (binary code), check for filename error
    try:
        f_in = open(file,'r')
    except IOError:
        print "Please enter a correct filename!"
        return
    f_out = open('bitoutput.txt','w')

    # code runs throught file, removes extra whites space and tabs, comments, and empty lines
    for line in f_in:
    
        # removes comments
        line = line.split('#')[0]
    
        # strips extra spaces
        line = " ".join(line.split())
    
        # if empty line skip
        if line == "":
            continue
    
        # adds newline to keep original structure
        line = line + '\n'
        f_out.write(line)

    # close files after opening
    f_in.close()
    f_out.close()

# method that adds no-ops to sws, sbs, lws, lbs
def check_mem_accesses():
    f_in = open('bitoutput.txt','r')
    f_out = open('mod_output.txt','w')
    one_behind = -1

    # read through the file and check for store words
    for line in f_in:

        # used to differentiate the branch pointers
        check_branch = line.rsplit(': ')
        
        # check jumps and branch instructions
        check_inst = ''
        check_one_noop = 0

        # initialize for calculation
        split_reg = []

        # check for the branch tag and adjust accordingly
        if line == check_branch[0]:
            # split the command at the reg
            split_reg = line.rsplit('$')
            check_inst = line.rsplit(' ')
        else:
            # split the command at the reg, taking into account the branch tag
            split_reg = check_branch[1].rsplit('$')
            check_inst = check_branch[1].rsplit(' ')
        count = 0
        
        # if a branching instruction then need to create a stall no matter what
        if (check_inst[0] == "j" or check_inst[0] == "jr" or check_inst[0] == "jal" or check_inst[0] == "bne" or check_inst[0] == "beq"):
            # check if a sw stall already exists
            if (one_behind != -2):
                new_line = "sll $0, $0, 0"
                f_out.write(new_line + "\n")

            f_out.write(line)
            check_one_noop = 1
        
        # keep track of the new registers
        new_regs = []
        
        # check each reg
        for regs in split_reg:
            
            if (len(split_reg) == 1):
                break
                
            # continue if just the instruction
            if (count == 0):
                count = count + 1
                continue
                
            # if a comma then get the value there
            get_reg = split_reg[count].rsplit(',')
            # else we at an offset so need to split at the bracket
            if (len(get_reg) == 1):
                get_reg = split_reg[count].rsplit(')')
    
            new_regs = new_regs + [get_reg[0]]
    
            count = count + 1

        # check that only one no_op is added but also make sure to keep the memory
        if (check_one_noop == 1):
            if (len(split_reg) != 1):
                one_behind = new_regs[0]
            else :
                one_behind = -1
            continue

        if (len(split_reg) != 1):
            # check through the list of dependencies from previous line of code
            for reg in new_regs:
                if (int(reg) == int(one_behind)):
                    new_line = "sll $0, $0, 0"
                    f_out.write(new_line + "\n")
                    break

        # add actual operation to the next line
        f_out.write(line)

        # if sw, sb, lw, lb then need to add store afterwards
        if (check_inst[0] == "sw" or check_inst[0] == "sb" or check_inst[0] == "lw" or check_inst[0] == "lb"):
            new_line = "sll $0, $0, 0"
            f_out.write(new_line + "\n")
            one_behind = -2 # signals a store word stall
            continue

        # set the one_behind for next line of code
        if (len(split_reg) != 1):
            one_behind = new_regs[0]

    f_in.close()
    f_out.close()
    os.remove('bitoutput.txt')

# method that removes branches from code and returns the lines where th branches take place
def remove_branches():
    f_in = open('mod_output.txt','r')
    f_out = open('binary.txt','w')
    branch_list = {} # keeps track of the branch list
    count = 0 # keeps track of the line count

    # goes through files and finds the branch labels
    for line in f_in:
        new_line = line.rsplit(': ')

        # if no branch then no reference, otherwise add the reference
        if line == new_line[0]:
            f_out.write(line)
            count = count + 4
            continue
        else:
            branch_list.update({new_line[0]:count})
            f_out.write(new_line[1])
            count = count + 4

    # cleanup and remove the old files
    f_in.close()
    f_out.close()
    os.remove('mod_output.txt')
    return branch_list

# int to binary converter
def bin(int, length, sign_ext):
    
    binary_output = ""
    
    # check for negative
    neg = 0
    if sign_ext == 1 and int < 0:
        neg = 1
    
    # if zero then simply return
    if int == 0:
        i = 0
        while (i < length):
            binary_output = binary_output + "0"
            i = i + 1
        return binary_output

    # otherwise go through each bit individually
    while len(binary_output) < length:
        if int & 1 == 1:
            binary_output = "1" + binary_output
        elif int == 0:
            if sign_ext == 1 and neg == 1:
                binary_output = "1" + binary_output
            else:
                binary_output = "0" + binary_output
        else:
            binary_output = "0" + binary_output

        int >>= 1
    return binary_output

# go through all the commands and change them to binary
# http://www.mrc.uidaho.edu/mrc/people/jff/digital/MIPSir.html website for binary conversion
def binary_conv(branches,output_name):
    f_in = open('binary.txt','r')
    f_out = open(output_name, 'w')

    # case statements that decode the different commands
    for line in f_in:
        
        # removes commas, splits up the command
        output = line.replace("," , " ")
        output = " ".join(output.split())
        output = output.split(' ')
        output = output[:-1] + [output[-1].split('\n')[0]]

        if "add" == output[0]:
            
            binary = "000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000100000\n"
            f_out.write(binary)
        
        elif "sub" == output[0]:
        
            binary = "000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000100010\n"
            f_out.write(binary)
        
        elif "addi" == output[0]:
            
            binary = "001000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "slt" == output[0]:
            
            binary = "000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000101010\n"
            f_out.write(binary)
        
        elif "slti" == output[0]:
            
            binary = "001010"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "mult" == output[0]:
            
            binary = "000000"
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + "0000000000011000\n"
            f_out.write(binary)

        elif "div" == output[0]:
        
            binary = "000000"
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + "0000000000011010\n"
            f_out.write(binary)

        elif "mfhi" == output[0]:
            
            binary = "0000000000000000"
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000010000\n"
            f_out.write(binary)

        elif "mflo" == output[0]:
            
            binary = "0000000000000000"
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000010010\n"
            f_out.write(binary)

        elif "lui" == output[0]:
            
            binary = "00111100000"
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[2]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "and" == output[0]:
            
            binary = "000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000100100\n"
            f_out.write(binary)

        elif "or" == output[0]:
            
            binary = "000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000100101\n"
            f_out.write(binary)

        elif "andi" == output[0]:
                                  
            binary = "001100"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)
                                  
        elif "ori" == output[0]:
            
            binary = "001101"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)
        
        elif "xor" == output[0]:
            
            binary = "000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000100110\n"
            f_out.write(binary)

        elif "nor" == output[0]:

            binary = "000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "00000100111\n"
            f_out.write(binary)

        elif "xori" == output[0]:
            
            binary = "001110"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "sll" == output[0]:
            
            binary = "00000000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 5, 0)
            binary = binary + "000000\n"
            f_out.write(binary)

        elif "srl" == output[0]:
            
            binary = "00000000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 5, 0)
            binary = binary + "000010\n"
            f_out.write(binary)

        elif "sra" == output[0]:
            
            binary = "00000000000"
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 5, 0)
            binary = binary + "000011\n"
            f_out.write(binary)

        elif "lw" == output[0]:
            
            offset_instruction = output[2].split('($')
            
            binary = "100011"
            binary = binary + bin(int(offset_instruction[1].strip(')')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(offset_instruction[0]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "sw" == output[0]:
            
            offset_instruction = output[2].split('($')
            
            binary = "101011"
            binary = binary + bin(int(offset_instruction[1].strip(')')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(offset_instruction[0]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "lb" == output[0]:
            
            offset_instruction = output[2].split('($')
            
            binary = "100000"
            binary = binary + bin(int(offset_instruction[1].strip(')')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(offset_instruction[0]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "sb" == output[0]:
            
            offset_instruction = output[2].split('($')
            
            binary = "101000"
            binary = binary + bin(int(offset_instruction[1].strip(')')), 5, 0)
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(offset_instruction[0]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "beq" == output[0]:
            
            # if branching to a jump point then set jump point, else just set offset point
            if output[3] in branches:
                output[3] = branches[output[3]]
            else:
                output[3] = int(output[3]) * 4
            
            binary = "000100"
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)
                                  
        elif "bne" == output[0]:
        
            # if branching to a jump point then set jump point, else just set offset point
            if output[3] in branches:
                output[3] = branches[output[3]]
            else:
                output[3] = int(output[3]) * 4
            
            binary = "000101"
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + bin(int(output[2].strip('$')), 5, 0)
            binary = binary + bin(int(output[3]), 16, 1)
            binary = binary + "\n"
            f_out.write(binary)

        elif "j" == output[0]:

            # if branching to a jump point then set jump point, else just set offset point
            if output[1] in branches:
                output[1] = branches[output[1]]
            else:
                output[1] = int(output[1]) * 4
            
            binary = "000010"
            binary = binary + bin(int(output[1]), 26, 1)
            binary = binary + "\n"
            f_out.write(binary)
                
        elif "jr" == output[0]:

            binary = "000000"
            binary = binary + bin(int(output[1].strip('$')), 5, 0)
            binary = binary + "000000000000000001000\n"
            f_out.write(binary)

        elif "jal" == output[0]:
            
            # if branching to a jump point then set jump point, else just set offset point
            if output[1] in branches:
                output[1] = branches[output[1]]
            else:
                output[1] = int(output[1]) * 4
            
            binary = "000011"
            binary = binary + bin(int(output[1]), 26, 1)
            binary = binary + "\n"
            f_out.write(binary)

        else:
            
            print "Error in code! No such command as " + output[0] + "!"
            f_in.close()
            f_out.close()
            os.remove('output.txt')
            os.remove('binary.txt')
            return

    f_in.close()
    f_out.close()
    os.remove('binary.txt')

# main part of the code

# deals with command line input and the assemble into binary output
try:
    if len(sys.argv) == 3:
        format_code(str(sys.argv[1]))
        check_mem_accesses()
        branches = remove_branches()
        binary_conv(branches,str(sys.argv[2]))
    else:
        print "Incorrect input! Command: python assembler.py [input] [output]"
except IndexError:
    print "Incorrect input! Command: python assembler.py [input] [output]"