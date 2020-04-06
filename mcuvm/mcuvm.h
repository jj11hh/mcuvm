#ifndef __MCUVM_H__
#define __MCUVM_H__
#include <stdint.h>
#include <stdbool.h>

extern uint8_t gMVM_regs[16];
extern uint16_t gMVM_pc;
extern bool gMVM_flagC;
extern bool gMVM_flagI;
extern bool gMVM_flagZ;

#define MVM_R(x) gMVM_regs[(x)]

#define MVM_INS_0A           0x00

#define MVM_INS_0A_NOP       0x00
#define MVM_INS_0A_INT       0x01
#define MVM_INS_0A_CLI       0x02
#define MVM_INS_0A_CLC       0x03
#define MVM_INS_0A_CLZ       0x04
#define MVM_INS_0A_JZ        0x05
#define MVM_INS_0A_JNZ       0x06
#define MVM_INS_0A_JI        0x07
#define MVM_INS_0A_JNI       0x08
#define MVM_INS_0A_JC        0x09
#define MVM_INS_0A_JNC       0x0A
#define MVM_INS_0A_RJMP      0x0B

#define MVM_INS_1A           0x40

#define MVM_INS_1A_STA       0x00
#define MVM_INS_1A_LD        0x01
#define MVM_INS_1A_LDI       0x02
#define MVM_INS_1A_AJMP      0x03

#define MVM_INS_2A           0x80

#define MVM_INS_2A_ROR       0x00
#define MVM_INS_2A_ROL       0x01
#define MVM_INS_2A_RSZ       0x02
#define MVM_INS_2A_RSA       0x03
#define MVM_INS_2A_LSZ       0x04
#define MVM_INS_2A_LSA       0x05
#define MVM_INS_2A_BXOR      0x06
#define MVM_INS_2A_BAND      0x07
#define MVM_INS_2A_BOR       0x08
#define MVM_INS_2A_MOV       0x09
#define MVM_INS_2A_JMP       0x0A
#define MVM_INS_2A_ADD       0x0B
#define MVM_INS_2A_SUB       0x0C
#define MVM_INS_2A_DIV       0x0D

#define MVM_INS_3A           0xC0

#define MVM_INS_3A_LADD      0x00
#define MVM_INS_3A_LSUB      0x01
#define MVM_INS_3A_MUL       0x02
#define MVM_INS_3A_DIVMOD    0x03

void MVM_decode( void );

#endif /* __MCUVM_H__ */

