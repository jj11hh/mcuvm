#!/bin/env perl
package MCUVM::ASM;
use v5.24;

our @CODES;
our @LABEL_TO_FILL;
our $TOTAL_BYTE;
our %LABELS;

sub assemble (&) {
    local @CODES;
    local @LABEL_TO_FILL;
    local %LABELS;
    local $TOTAL_BYTE;

    my $fun = shift;
    $fun ->();

    for my $code (@CODES)
}

sub v {
    my $labels = \%LABELS;
    my $value = shift;

    if ($value =~ /^:/){
        $value =~ s/^://;
        return sub {
            $labels->{$value};
        };
    }
    else {
        return sub { $value };
    }
}

sub label {
    my $label = shift;
    %LABELS{$label} = $TOTAL_BYTE;
}

sub nop {
    $TOTAL_BYTE ++;
    push @CODES, {
        name => "nop",
        byte => 1,
        args => [],
        emit => sub {
            return chr 0x00;
        }
    };
}

sub int {

}