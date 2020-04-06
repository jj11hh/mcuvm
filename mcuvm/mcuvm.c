#include "mcuvm_hal.h"
#include "mcuvm.h"

uint8_t gMVM_regs[16];
uint16_t gMVM_pc = 0;
bool gMVM_flagC = 0;
bool gMVM_flagI = 0;
bool gMVM_flagZ = 0;

void MVM_decode( void ){
  uint8_t code = MVM_dataLoad(gMVM_pc);
  uint8_t type = code & 0b11000000;
  uint8_t ins = 0;
  uint16_t rdp = 0;
  uint16_t wtp = 0;

  uint8_t rx, ry, rz, rtemp, byte;

  switch (type) {

    case MVM_INS_0A:
    ins = code & 0b00111111;
    switch (ins){

      case MVM_INS_0A_NOP      :
gMVM_pc ++;
      break;
      case MVM_INS_0A_INT      :
  MVM_userInt();
  gMVM_pc ++;

      break;
      case MVM_INS_0A_CLI      :
  gMVM_flagI = 0;
  gMVM_pc ++;

      break;
      case MVM_INS_0A_CLC      :
  gMVM_flagC = 0;
  gMVM_pc ++;

      break;
      case MVM_INS_0A_CLZ      :
  gMVM_flagZ = 0;
  gMVM_pc ++;

      break;
      case MVM_INS_0A_JZ       :
        byte = MVM_dataLoad(++ gMVM_pc);
  if (gMVM_flagZ) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
  gMVM_flagZ = 0;

      break;
      case MVM_INS_0A_JNZ      :
        byte = MVM_dataLoad(++ gMVM_pc);
  if (!gMVM_flagZ) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;

      break;
      case MVM_INS_0A_JI       :
        byte = MVM_dataLoad(++ gMVM_pc);
  if (gMVM_flagI) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
  gMVM_flagI = 0;

      break;
      case MVM_INS_0A_JNI      :
        byte = MVM_dataLoad(++ gMVM_pc);
  if (!gMVM_flagI) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;

      break;
      case MVM_INS_0A_JC       :
        byte = MVM_dataLoad(++ gMVM_pc);
  if (gMVM_flagC) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
  gMVM_flagC = 0;

      break;
      case MVM_INS_0A_JNC      :
        byte = MVM_dataLoad(++ gMVM_pc);
  if (!gMVM_flagC) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;

      break;
      case MVM_INS_0A_RJMP     :
        byte = MVM_dataLoad(++ gMVM_pc);
  gMVM_pc += (int8_t) byte;

      break;
    }
    break;
    case MVM_INS_1A:
    ins = code & 0b00110000;
    ins = ins >> 4;
    switch (ins){

      case MVM_INS_1A_STA      :
        rx = code & 0b00001111;
  wtp = gMVM_regs[11];
  wtp = wtp << 8;
  wtp |= gMVM_regs[10];
  MVM_dataStore(wtp, gMVM_regs[rx]);
  gMVM_pc ++;

      break;
      case MVM_INS_1A_LD       :
        rx = code & 0b00001111;
  rdp = gMVM_regs[13];
  rdp = rdp << 8;
  rdp |= gMVM_regs[12];
  gMVM_regs[rx] = MVM_dataLoad(rdp);
  gMVM_pc ++;

      break;
      case MVM_INS_1A_LDI      :
        rx = code & 0b00001111;
        byte = MVM_dataLoad(++ gMVM_pc);
  gMVM_regs[rx] = byte;
  gMVM_pc ++;

      break;
      case MVM_INS_1A_AJMP     :
        rx = code & 0b00001111;
        byte = MVM_dataLoad(++ gMVM_pc);
  gMVM_pc += (int8_t) byte;
  gMVM_pc += gMVM_regs[rx];

      break;
    }
    break;
    case MVM_INS_2A:
    ins = code & 0b00111111;
    switch (ins){

      case MVM_INS_2A_ROR      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  byte = byte % 8;
  if (byte) {
      rtemp = gMVM_regs[ry] >> byte;
      rtemp |= gMVM_regs[ry] << (8 - byte);
  }
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_ROL      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  byte = byte % 8;
  if (byte) {
      rtemp = gMVM_regs[ry] << byte;
      rtemp |= gMVM_regs[ry] >> (8 - byte);
  }
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_RSZ      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] >> byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_RSA      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  rtemp = (int8_t) gMVM_regs[ry] >> byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_LSZ      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] << byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_LSA      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  rtemp = (int8_t) gMVM_regs[ry] << byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_BXOR     :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] ^ byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_BAND     :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] & byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_BOR      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] | byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_MOV      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  gMVM_regs[ry] = gMVM_regs[rx];
  gMVM_pc ++;

      break;
      case MVM_INS_2A_JMP      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  gMVM_pc = gMVM_regs[ry];
  gMVM_pc = gMVM_pc << 8;
  gMVM_pc |= gMVM_regs[rx];

      break;
      case MVM_INS_2A_ADD      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  rtemp = gMVM_regs[ry] + gMVM_regs[rx];
  if (rtemp < gMVM_regs[ry] || rtemp < gMVM_regs[rx]){
    gMVM_flagC = 1;
  }
  if (rtemp == 0){
    gMVM_flagZ = 1;
  }
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_SUB      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  rtemp = gMVM_regs[ry] - gMVM_regs[rx];
  if (rtemp > gMVM_regs[ry] || rtemp > gMVM_regs[rx]){
    gMVM_flagC = 1;
  }
  if (rtemp == 0){
    gMVM_flagZ = 1;
  }
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
      case MVM_INS_2A_DIV      :
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  rtemp = gMVM_regs[ry] / gMVM_regs[rx];
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;

      break;
    }
    break;
    case MVM_INS_3A:
    ins = code & 0b00110000;
    ins = ins >> 4;
    switch (ins){

      case MVM_INS_3A_LADD     :
        rz = code & 0b00001111;
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  wtp = gMVM_regs[rz];
  wtp |= gMVM_regs[ry];
  rdp = gMVM_regs[rx];
  wtp += rdp;
  gMVM_regs[ry] = wtp;
  gMVM_regs[rz] = wtp >> 8;
  gMVM_pc ++;

      break;
      case MVM_INS_3A_LSUB     :
        rz = code & 0b00001111;
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  wtp = gMVM_regs[rz];
  wtp |= gMVM_regs[ry];
  rdp = gMVM_regs[rx];
  wtp -= rdp;
  gMVM_regs[ry] = wtp;
  gMVM_regs[rz] = wtp >> 8;
  gMVM_pc ++;

      break;
      case MVM_INS_3A_MUL      :
        rz = code & 0b00001111;
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  wtp = gMVM_regs[ry];
  rdp = gMVM_regs[rx];
  wtp *= rdp;
  gMVM_regs[ry] = wtp;
  gMVM_regs[rz] = wtp >> 8;
  gMVM_pc ++;

      break;
      case MVM_INS_3A_DIVMOD   :
        rz = code & 0b00001111;
        byte = MVM_dataLoad(++ gMVM_pc);
        rx = byte & 0b00001111;
        ry = (byte & 0b11110000) >> 4;
  gMVM_regs[ry] = gMVM_regs[ry] / gMVM_regs[rx];
  gMVM_regs[rz] = gMVM_regs[ry] % gMVM_regs[rx];
  gMVM_pc ++;

      break;
    }
    break;
  }
}
