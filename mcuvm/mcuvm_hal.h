#ifndef __MCUVM_HAL_H__
#define __MCUVM_HAL_H__
#include <stdint.h>
#include <stdio.h>
#include "mcuvm.h"

#define MVM_CODEPAGE 2048
#define MVM_DATAPAGE 2048

extern uint8_t MVM_CODEMEM[MVM_CODEPAGE];
extern uint8_t MVM_DATAMEM[MVM_DATAPAGE];

static inline uint8_t MVM_dataLoad(uint16_t addr){
    if (addr < MVM_CODEPAGE + MVM_DATAPAGE){
        if (addr >= MVM_CODEPAGE)
            return MVM_DATAMEM[addr - MVM_CODEPAGE];
        else
            return MVM_CODEMEM[addr];
    }
    else {
        return 0;
    }
}

static inline void MVM_dataStore(uint16_t addr, uint8_t value){
    if (addr >= MVM_CODEPAGE){
        MVM_DATAMEM[addr - MVM_CODEPAGE] = value;
    }
    else {
        // do nothing
    }
}

static inline void MVM_userInt(){
    putchar(gMVM_regs[14]);
}

#endif /* __MCUVM_HAL_H__ */