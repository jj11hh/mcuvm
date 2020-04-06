#!/bin/env perl
# This is a Virtual Machine for low cost MCUs

# regesters list
# pc --> Program Counter
# r0 - r15 --> General Regester
# r15 --> Stack Pointer
# r14 --> Interrupt Register
# r13 --> rdph
# r12 --> rdpl
# r11 --> wtph
# r10 --> wtpl

# instructs list
# nop
# mov ry, rx; ry <- rx
# add ry, rx; ry <- ry + rx
# sub ry, rx; ry <- ry - rx
# mul rc, rb, ra; rc:rb <- ra * rb;
# div ry, rx; ry <- ry / rx;
# jz LABEL;
# jnz LABEL;
# jc LABEL;
# jnc LABEL;
# rjmp LABEL;
# jmp rx, ry; jump to rx:ry
# ajmp LABEL, rx; jump to LABEL + rx
# clz;
# clc;
# cli;
# ld rx, (ry);
# ldi rx, $xx;
# sta (ry), rx;
# mmov (ry), (rx);
# dmmov (ry), (rx); mmov x 2
# qmmov (ry), (rx); mmov x 4
# ommov (ry), (rx); mmov x 8
# band ry, rx;
# bor ry, rx;
# bxor ry, rx;
# bnor ry, rz;
# lsa ry, rx;
# lsz ry, rx;
# rsa ry, rx;
# rsz ry, rx;
# ror ry, rz;
# rol ry, rx;
# inc rx;
# dec rx;
# int;

# INSTRUCT:
# zero argument, one byte: 00 : xxxxxx
# int, nop, cli, clc, clz
# zero argument, two bytes: 00 : xxxxxx xxxxxxxx
# ji, jni, jz, jnz, jc, jnc, rjmp
# one argument, one byte: 01 : xx : xxxx
#                                   rx
# sta, ld
# one argument, two bytes: 01 : xx : xxxx xxxxxxxx
#                                    rx
# ajmp, ldi
# two arguments, two bytes: 10 : xxxxxx xxxx : xxxx
#                                       ry     rx
# ror, rol, rsa, lsz, lsa, bxor, bor, band, jmp, mov, add, sub, div
# three arguments, two bytes: 11 : xx : xxxx xxxx : xxxx
#                                       rz   ry     rx
# mul, divmod, ladd, lsub


package MCUVM;
use v5.24;
no warnings "experimental";

use Data::Dumper;
use Tie::IxHash;

use constant {
  MASK_AB => 0b01000000,
  MASK_MB => 0b10000000,
  MASK_0A => 0b00111111,
  MASK_1A => 0b00110000,
  MASK_2A => 0b00111111,
  MASK_3A => 0b00110000,

  SIG_0A => 0b00000000,
  SIG_1A => 0b01000000,
  SIG_2A => 0b10000000,
  SIG_3A => 0b11000000,

  INS_0A1B => 0,
  INS_0A2B => 1,
  INS_1A1B => 2,
  INS_1A2B => 3,
  INS_2A2B => 4,
  INS_3A2B => 5,

  INS_0A => "INS_0A",
  INS_1A => "INS_1A",
  INS_2A => "INS_2A",
  INS_3A => "INS_3A",
};

our $OPCODE;
our $RX;
our $RY;
our $RZ;
our $OPR;
our @CODES;
our @LABEL_TO_FILL;
our $TOTAL_BYTE;
our %LABELS;

our %INSTRUCTS = ();
our %OPCODES = ();
my $t = tie %INSTRUCTS, 'Tie::IxHash';

sub import {
  no strict "refs";
  my ($exporter, @imports) = @_;
  my ($caller, $file, $line) = caller;

  *{$caller.'::emit_code'} = \&emit_code;
  *{$caller.'::ASM'} = \&ASM;
  *{$caller.'::v'} = \&v;
  *{$caller.'::label'} = \&label;
  *{$caller.'::db'} = \&db;
  *{$caller.'::r'} = \&r;
  *{$caller.'::b'} = \&b;
  *{$caller.'::bh'} = \&bh;


  export_opcode($caller);
}

sub def_instru{
  my %args = @_;
  my ($insname, $type, $emit) = ($args{name}, $args{type}, $args{emit});

  my $oldtype = do {
    given ($type){
      INS_0A when INS_0A1B;
      INS_0A when INS_0A2B;
      INS_1A when INS_1A1B;
      INS_1A when INS_1A2B;
      INS_2A when INS_2A2B;
      INS_3A when INS_3A2B;
    }
  };

  push $INSTRUCTS{$oldtype}->@*, [$insname, $oldtype, $emit, $type];
}

sub emit_code {

  open STDOUT, ">mcuvm.h";

  print <<EOF;
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

EOF

  $t->SortByKey;

  my $instypeid = 0;
  while (my ($instype, $instructs) = each %INSTRUCTS) {
    my $insid = 0;
    printf "#define %-20s 0x%02X\n\n", "MVM_".uc($instype), $instypeid<<6;
    $instypeid ++;
    for my $ins ( $instructs->@*){
      my ($insname, $type, $emit, $newtype) = $ins->@*;

      $OPCODES{$insname} = {
        type => $newtype,
        opcode => $insid,
      };
      printf "#define %-20s 0x%02X\n", "MVM_".uc($type)."_".uc($insname), $insid;
      $insid ++;
    }

    say ;
  }

  say <<EOF;
void MVM_decode( void );

#endif /* __MCUVM_H__ */
EOF



  open STDOUT, ">mcuvm.c";

  say <<EOF;
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
EOF

  my $instypeid = 0;
  while (my ($instype, $instructs) = each %INSTRUCTS) {
    my $insid = 0;
    printf "    case %s:\n", "MVM_".uc($instype);

    if ($instype eq INS_0A || $instype eq INS_2A){
      say <<EOF;
    ins = code & 0b00111111;
    switch (ins){
EOF
    }
    else {
      say <<EOF;
    ins = code & 0b00110000;
    ins = ins >> 4;
    switch (ins){
EOF
    }
    $instypeid ++;
    for my $ins ( $instructs->@*){
      my ($insname, $type, $emit) = $ins->@*;


      printf "      case %-20s:\n", "MVM_".uc($type)."_".uc($insname);
      $emit->();
      say "      break;";
      $insid ++;
    }
    say '    }';
    say '    break;'
  }

say '  }';
say '}';
}

sub ASM (&) {
  my $fun = shift;
  my $bytecode;
  local $TOTAL_BYTE = 0;
  local @CODES = ();

  $fun ->();

  for my $gen (@CODES){
    $bytecode .= $gen->();
  }

  return $bytecode;
}

sub _deref{
  my $v = shift;
  if (ref($v) eq "CODE"){
    $v = $v->();
  }
  $v;
}

sub v {
  my $value = shift;

  if ($value =~ /^::/){
    my $labels = \%LABELS;
    my $cur = $TOTAL_BYTE;
    $value =~ s/^:://;
    return sub {
      $labels->{$value};
    };
  }
  elsif ($value =~ /^:/){
    my $labels = \%LABELS;
    my $cur = $TOTAL_BYTE;
    $value =~ s/^://;
    return sub {
      $labels->{$value} - $cur - 1;
    };
  }
  else {
    return sub { $value };
  }
}

sub r {
  my $v = v(shift);
  sub {
    $v->() & 0x0F;
  };
}

sub b {
  my $v = v(shift);
  sub {
    $v -> () & 0xFF;
  }
}

sub bh {
  my $v = v(shift);
  sub {
    ($v->() >> 8) & 0xFF;
  }
}

sub label {
  my $label = shift;
  $LABELS{$label} = $TOTAL_BYTE;
}

sub db {
  my $data = shift;
  $TOTAL_BYTE += length($data);
  push @CODES, sub{$data};
}

sub export_opcode {
  my $caller = shift;
  $t->SortByKey;

  my $instypeid = 0;
  while (my ($instype, $instructs) = each %INSTRUCTS) {
    my $insid = 0;
    $instypeid ++;
    for my $ins ( $instructs->@*){
      my ($insname, $type, $emit, $newtype) = $ins->@*;
      $OPCODES{$insname} = {
        type => $newtype,
        opcode => $insid,
      };
      $insid ++;
    }
  }


  while (my ($instru, $v) = each %OPCODES){
    my $opcode = $v->{opcode};
    my $type = $v->{type};
    if ($instru eq 'sub'){
      $instru = "subr";
    }

    my $asm = do {
      given ($type){
        when (INS_0A1B){
          sub {
            $TOTAL_BYTE += 1;
            push @CODES, sub {
              local $OPCODE = $opcode;
              asm_0A1B();
            }
          }
        }
        when (INS_0A2B){
          sub {
            $TOTAL_BYTE += 2;
            my @args = @_;
            push @CODES, sub {
              local ($OPR) = @args;
              local $OPCODE = $opcode;
              $OPR = _deref($OPR);
              asm_0A2B();
            }
          }
        }
        when (INS_1A1B){
          sub {
            $TOTAL_BYTE += 1;
            my @args = @_;
            push @CODES, sub {
              local ($RX) = @args;
              local $OPCODE = $opcode;
              $RX = _deref($RX);
              asm_1A1B();
            }
          }
        }
        when (INS_1A2B){
          sub {
            $TOTAL_BYTE += 2;
            my @args = @_;
            push @CODES, sub {
              local ($RX, $OPR) = @args;
              local $OPCODE = $opcode;
              $RX = _deref($RX);
              $OPR = _deref($OPR);
              asm_1A2B();
            }
          }
        }
        when (INS_2A2B){
          sub {
            $TOTAL_BYTE += 2;
            my @args = @_;
            push @CODES, sub {
              local ($RY, $RX) = @args;
              local $OPCODE = $opcode;
              $RX = _deref($RX);
              $RY = _deref($RY);
              asm_2A2B();
            }
          }
        }
        when (INS_3A2B){
          sub {
            $TOTAL_BYTE += 2;
            my @args = @_;
            push @CODES, sub {
              local ($RZ, $RY, $RX) = @_;
              local $OPCODE = $opcode;
              $RX = _deref($RX);
              $RY = _deref($RY);
              $RZ = _deref($RZ);
              asm_3A2B();
            }
          }
        }
      }
    };

    no strict "refs";
    my $sym = $caller."::".lc($instru);
    *{$sym} = \&$asm;   
  }
}

sub emit_0A1B {
  my ($emit) = @_;
  sub {
    $emit->();
  }
}

sub asm_0A1B {
  return pack 'C', $OPCODE;
}

sub emit_0A2B {
  my ($emit) = @_;
  sub {
    my $sp = ' ' x 8;
    say $sp."byte = MVM_dataLoad(++ gMVM_pc);";

    $emit->();
  }
}

sub asm_0A2B {
  return pack('C', $OPCODE).pack('C', $OPR);
}

sub emit_1A1B {
  my ($emit) = @_;
  sub {
    my $sp = ' ' x 8;
    say $sp."rx = code & 0b00001111;";

    $emit->();
  }
}
sub asm_1A1B {
  return pack('C', (1 << 6) | pack('C', $OPCODE << 4) | $RX);
}

sub emit_1A2B {
  my ($emit) = @_;
  sub {
    my $sp = ' ' x 8;
    say $sp."rx = code & 0b00001111;";
    say $sp."byte = MVM_dataLoad(++ gMVM_pc);";

    $emit->();
  }
}

sub asm_1A2B {
  return pack('C', (1<<6) | ($OPCODE << 4) | $RX).pack('C', $OPR);
}

sub emit_2A2B {
  my ($emit) = @_;
  sub {
    my $sp = ' ' x 8;
    say $sp."byte = MVM_dataLoad(++ gMVM_pc);";
    say $sp."rx = byte & 0b00001111;";
    say $sp."ry = (byte & 0b11110000) >> 4;";

    $emit->();
  }
}

sub asm_2A2B {
  return pack('C', (2<<6) | $OPCODE).pack('C', $RX | ($RY << 4));
}

sub emit_3A2B {
  my ($emit) = @_;
  sub {
    my $sp = ' ' x 8;
    say $sp."rz = code & 0b00001111;";
    say $sp."byte = MVM_dataLoad(++ gMVM_pc);";
    say $sp."rx = byte & 0b00001111;";
    say $sp."ry = (byte & 0b11110000) >> 4;";

    $emit->();
  }
}

sub asm_3A2B {
  return pack('C', (3<<6) | ($OPCODE<<4) | $RZ).pack('C', $RX | ($RY << 4));
}

def_instru(
  name => "nop", 
  type => INS_0A1B, 
  emit => emit_0A1B(sub {
    say "gMVM_pc ++;";
  }),
);
def_instru(
  name => "int", 
  type => INS_0A1B, 
  emit => emit_0A1B(sub {
  say <<EOF;
  MVM_userInt();
  gMVM_pc ++;
EOF
  }),
);
def_instru(
  name => "cli", 
  type => INS_0A1B, 
  emit => emit_0A1B(sub {
  say <<EOF;
  gMVM_flagI = 0;
  gMVM_pc ++;
EOF
  }),
);
def_instru(
  name => "clc",
  type => INS_0A1B, 
  emit => emit_0A1B(sub {
  say <<EOF;
  gMVM_flagC = 0;
  gMVM_pc ++;
EOF
  }),
);
def_instru(
  name => "clz",
  type => INS_0A1B,
  emit => emit_0A1B(sub {
  say <<EOF;
  gMVM_flagZ = 0;
  gMVM_pc ++;
EOF
  }),
);

def_instru(
  name => "jz",
  type => INS_0A2B, 
  emit => emit_0A2B(sub {
  say <<EOF;
  if (gMVM_flagZ) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
  gMVM_flagZ = 0;
EOF
  }),
);

def_instru(
  name => "jnz",
  type => INS_0A2B,
  emit => emit_0A2B(sub {
  say <<EOF;
  if (!gMVM_flagZ) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
EOF
  }),
);

def_instru(
  name => "ji",
  type => INS_0A2B,
  emit => emit_0A2B(sub {
  say <<EOF;
  if (gMVM_flagI) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
  gMVM_flagI = 0;
EOF
  }),
);
def_instru(
  name => "jni", 
  type => INS_0A2B, 
  emit => emit_0A2B(sub {
  say <<EOF;
  if (!gMVM_flagI) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
EOF
}));
def_instru(
  name => "jc", 
  type => INS_0A2B,
  emit => emit_0A2B(sub {
  say <<EOF;
  if (gMVM_flagC) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
  gMVM_flagC = 0;
EOF
}));
def_instru(
  name => "jnc",
  type => INS_0A2B,
  emit => emit_0A2B(sub {
  say <<EOF;
  if (!gMVM_flagC) gMVM_pc += (int8_t) byte;
  else gMVM_pc ++;
EOF
}));
def_instru(
  name => "rjmp",
  type => INS_0A2B,
  emit => emit_0A2B(sub {
  say <<EOF;
  gMVM_pc += (int8_t) byte;
EOF
}));

def_instru(
  name => "sta",
  type => INS_1A1B, 
  emit => emit_1A1B(sub {
  say <<EOF;
  wtp = gMVM_regs[11];
  wtp = wtp << 8;
  wtp |= gMVM_regs[10];
  MVM_dataStore(wtp, gMVM_regs[rx]);
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "ld", 
  type => INS_1A1B,
  emit => emit_1A1B(sub {
  say <<EOF;
  rdp = gMVM_regs[13];
  rdp = rdp << 8;
  rdp |= gMVM_regs[12];
  gMVM_regs[rx] = MVM_dataLoad(rdp);
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "ldi",
  type => INS_1A2B,
  emit =>emit_1A2B(sub {
  say <<EOF;
  gMVM_regs[rx] = byte;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "ajmp",
  type => INS_1A2B,
  emit => emit_1A2B(sub {
  say <<EOF;
  gMVM_pc += (int8_t) byte;
  gMVM_pc += gMVM_regs[rx];
EOF
}));

def_instru(
  name => "test",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  if (!byte){
    gMVM_flagZ = 1;
  }
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "ror",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  byte = byte % 8;
  if (byte) {
      rtemp = gMVM_regs[ry] >> byte;
      rtemp |= gMVM_regs[ry] << (8 - byte);
  }
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "rori",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = ry;
  byte = byte % 8;
  if (byte) {
      rtemp = gMVM_regs[rx] >> byte;
      rtemp |= gMVM_regs[rx] << (8 - byte);
  }
  gMVM_regs[rx] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "rol",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  byte = byte % 8;
  if (byte) {
      rtemp = gMVM_regs[ry] << byte;
      rtemp |= gMVM_regs[ry] >> (8 - byte);
  }
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "roli",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = ry;
  byte = byte % 8;
  if (byte) {
      rtemp = gMVM_regs[rx] << byte;
      rtemp |= gMVM_regs[rx] >> (8 - byte);
  }
  gMVM_regs[rx] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "rsz",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] >> byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "rszi",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = ry;
  rtemp = gMVM_regs[rx] >> byte;
  gMVM_regs[rx] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "rsa",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  rtemp = (int8_t) gMVM_regs[ry] >> byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "rsai",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = ry;
  rtemp = (int8_t) gMVM_regs[rx] >> byte;
  gMVM_regs[rx] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "lsz",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] << byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "lszi",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = ry;
  rtemp = gMVM_regs[rx] << byte;
  gMVM_regs[rx] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "lsa",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  rtemp = (int8_t) gMVM_regs[ry] << byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "lsai",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = ry;
  rtemp = (int8_t) gMVM_regs[rx] << byte;
  gMVM_regs[rx] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "bxor",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] ^ byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));
def_instru(
  name => "band",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] & byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));
def_instru(
  name => "bor",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  byte = gMVM_regs[rx];
  rtemp = gMVM_regs[ry] | byte;
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));
def_instru(
  name => "mov",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  gMVM_regs[ry] = gMVM_regs[rx];
  gMVM_pc ++;
EOF
}));
def_instru(
  name => "jmp",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  gMVM_pc = gMVM_regs[ry];
  gMVM_pc = gMVM_pc << 8;
  gMVM_pc |= gMVM_regs[rx];
EOF
}));
def_instru(
  name => "add",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  rtemp = gMVM_regs[ry] + gMVM_regs[rx];
  if (rtemp < gMVM_regs[ry] || rtemp < gMVM_regs[rx]){
    gMVM_flagC = 1;
  }
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "addi",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  rtemp = gMVM_regs[rx] + ry;
  if (rtemp < gMVM_regs[rx]){
    gMVM_flagC = 1;
  }
  gMVM_regs[rx] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "sub",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  rtemp = gMVM_regs[ry] - gMVM_regs[rx];
  if (rtemp > gMVM_regs[ry] || rtemp > gMVM_regs[rx]){
    gMVM_flagC = 1;
  }
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "subi",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  rtemp = gMVM_regs[rx] - ry;
  if (rtemp < gMVM_regs[rx]){
    gMVM_flagC = 1;
  }
  gMVM_regs[rx] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => "div",
  type => INS_2A2B,
  emit => emit_2A2B(sub {
  say <<EOF;
  rtemp = gMVM_regs[ry] / gMVM_regs[rx];
  gMVM_regs[ry] = rtemp;
  gMVM_pc ++;
EOF
}));

def_instru(
  name => 'ladd',
  type => INS_3A2B,
  emit => emit_3A2B(sub {
  say <<EOF;
  wtp = gMVM_regs[rz];
  wtp |= gMVM_regs[ry];
  rdp = gMVM_regs[rx];
  wtp += rdp;
  gMVM_regs[ry] = wtp;
  gMVM_regs[rz] = wtp >> 8;
  gMVM_pc ++;
EOF
}));
def_instru(
  name => 'lsub',
  type => INS_3A2B,
  emit => emit_3A2B(sub {
  say <<EOF;
  wtp = gMVM_regs[rz];
  wtp |= gMVM_regs[ry];
  rdp = gMVM_regs[rx];
  wtp -= rdp;
  gMVM_regs[ry] = wtp;
  gMVM_regs[rz] = wtp >> 8;
  gMVM_pc ++;
EOF
}));
def_instru(
  name => 'mul',
  type => INS_3A2B,
  emit => emit_3A2B(sub {
  say <<EOF;
  wtp = gMVM_regs[ry];
  rdp = gMVM_regs[rx];
  wtp *= rdp;
  gMVM_regs[ry] = wtp;
  gMVM_regs[rz] = wtp >> 8;
  gMVM_pc ++;
EOF
}));
def_instru(
  name => 'divmod',
  type => INS_3A2B,
  emit => emit_3A2B(sub {
  say <<EOF;
  gMVM_regs[ry] = gMVM_regs[ry] / gMVM_regs[rx];
  gMVM_regs[rz] = gMVM_regs[ry] % gMVM_regs[rx];
  gMVM_pc ++;
EOF
}));

#emit_code();

1;