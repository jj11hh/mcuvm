#include <stdio.h>
#include "mcuvm.h"
#include "mcuvm_hal.h"

uint8_t MVM_CODEMEM[2048] = {
        0x60, 0x30, // ldi r0, $30h
        0x61, 0x01, // ldi r1, $01h
        0x62, 0x0a, // ldi r2, $10
        0x6a, 0x00, // ldi r10(wtpl), $0
        0x6b, 0x08, // ldi r11(wtph), $0
        0x89, 0xe0, // mov r14, r0
        0x01,       // int
        0x4e,       // sta r14;
        0x6e, 0x0a, // ldi r14, $5ch
        0x01,       // int
        0x8b, 0x01, // add r0, r1
        0x8b, 0xa1, // add r10, r1
        0x8c, 0x21, // sub r2, r1
        0x06, 0xf2,
        0x0b, 0xff  // rjmp $f6h
};
uint8_t MVM_DATAMEM[2048];

int main (){
    while (1){
        MVM_decode();
    }
}
