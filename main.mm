//
//  main.m
//  instruction_to_offset
//
//  Created by karek314 on 10/11/2017.
//  Copyright © 2017 karek314. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <iostream>
#include <mach/mach.h>
#include <libproc.h>

using namespace std;

mach_port_t task;
mach_vm_address_t StartAddr;
uint64_t OpCodeSize;
uint64_t AddressOfInstruction;
int pid;


template <typename type>
int VM_Read(task_t target, task_t self, mach_vm_address_t address, type * content) {
    vm_offset_t data;
    uint32_t sz;
    auto re = vm_read(target, address, sizeof(type), &data, &sz);
    if (re != 0){
        return -1;
    }
    *content = (type) *(type *)(data);
    vm_deallocate(self, data, sz);
    return 0;
}


int GetPid(const char *process_name, size_t size) {
    pid_t pids[1024];
    int numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pids));
    for (int i = 0; i < numberOfProcesses; ++i) {
        if (pids[i] == 0) { continue; }
        char name[1024];
        proc_name(pids[i], name, sizeof(name));
        if (!strncmp(name, process_name, size)) {
            return pids[i];
        }
    }
    return -1;
}


void help(){
    printf("\nUsage sudo ./instruction_to_offset processname bytecodesize address startaddress");
    printf("\nExample sudo ./instruction_to_offset example_app 0x6 0x12b38 0x0");
}


void ReadInstructionFromCodeAndExtractOffsetForAddress(uint64_t opcode_size, uint64_t mStartAddr, uint64_t offset, uint64_t * content) {
    NSMutableArray *array_of_bytes = [NSMutableArray new];
    printf("\nBytes: ");
    for (int i=0; i<opcode_size; i++) {
        char output;
        VM_Read<char>(task, current_task(), mStartAddr+offset+i, &output);
        NSString *tmp = [NSString stringWithFormat:@"%hhx",output];
        if ([tmp isEqualToString:@"0"]) {
            tmp = @"00";
        }
        if ([tmp length] == 1) {
            tmp = [NSString stringWithFormat:@"%i%@",0,tmp];
        }
        [array_of_bytes addObject:tmp];
        printf("%s ", [tmp UTF8String]);
    }
    printf("\n");
    NSString *reversed_instruction_string = [NSString stringWithFormat:@"0x%@%@%@%@",array_of_bytes[opcode_size-1],array_of_bytes[opcode_size-2],array_of_bytes[opcode_size-3],array_of_bytes[opcode_size-4]];
    uint64_t reversed_instruction;
    NSScanner* scanner = [NSScanner scannerWithString:reversed_instruction_string];
    [scanner scanHexLongLong:&reversed_instruction];
    printf("\nReversed Instruction: %llx", reversed_instruction);
    uint64_t real_instruction = offset + reversed_instruction + opcode_size;
    printf("\nReal Offset: 0x%llx", real_instruction);
    *content = real_instruction;
}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        printf("\nInstruction to Offset\n");
        if(argv[1] && argv[2] && argv[3] && argv[4]){
            const char *process_name = argv[1];
            pid = GetPid(process_name, sizeof(process_name));
            if (pid != -1) {
                printf("\nFound process id: %i",pid);
                kern_return_t error = task_for_pid(mach_task_self(), pid, &task);
                printf("\n%d -> %x [%d - %s]", pid, task, error, mach_error_string(error));
                if(task){
                    uint64_t result = 0x0;
                    OpCodeSize = std::stoul(argv[2], nullptr, 16);
                    StartAddr = std::stoul(argv[4], nullptr, 16);
                    AddressOfInstruction = std::stoul(argv[3], nullptr, 16);
                    printf("\nOpCodeSize: 0x%llx",OpCodeSize);
                    printf("\nStartAddress is: 0x%llx",StartAddr);
                    printf("\nAddress of instruction: 0x%llx",AddressOfInstruction);
                    ReadInstructionFromCodeAndExtractOffsetForAddress(OpCodeSize,StartAddr,AddressOfInstruction,&result);
                    printf("\nResult is: 0x%llx",result);
                } else {
                    printf("\nCan't get task for pid, check premissions");
                    help();
                }
            } else {
                printf("\nCan't find process id!");
                help();
            }
        } else {
            printf("\nSeems that you didn't provided all parms");
            help();
        }
    }
    printf("\n");
    return 0;
}
