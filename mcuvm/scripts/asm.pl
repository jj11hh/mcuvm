BEGIN {
    require './MCUVM.pm';
    import MCUVM;
}

use v5.24;



print ASM {
    my $RI = r(14);
    my $RDPH = r(13);
    my $RDPL = r(12);
    my $WTPH = r(11);
    my $WTPL = r(10);

    ldi($RDPH, bh(":DATA"));
    ldi($RDPL, b(":DATA"));
label("HERE");
    addi($RDPL, v(1));
    ld($RI);
    test($RI);
    jz(v(":END"));
    int();
    ajmp(v(":HERE"));
label("END");
    rjmp(v(':END'));

label("DATA");
    db("Hello, world\n\0");
}
