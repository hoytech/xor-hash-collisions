use strict;

my $accum;

while(<>) {
    chomp;
    /^([0-9a-f]+)/ || next;
    my $curr = [ split //, pack("H*", $1) ];

    if (!defined $accum) {
        $accum = $curr;
        next;
    }

    for (my $i = 0; $i < @$curr; $i++) {
        $accum->[$i] ^= $curr->[$i];
    }
}

print unpack("H*", (join '', @$accum)), "\n";
