use strict;

use Clone;
use Digest::SHA;
use List::Util;


my $targetHex = shift // die "need target hash";
my $targetBits = splitBits(pack("H*", $targetHex));
my $numTargetBits = @$targetBits;

my $items = buildCollision($targetBits, $numTargetBits);

for my $item (@$items) {
    print unpack("H*", Digest::SHA::sha256("$item")), " ($item)\n";
}




sub splitBits {
    my ($inp) = @_;
    return [ map { 0 + $_ } split //, unpack("B*", $inp) ];
}

sub transpose {
    my $inp = shift;
    my $m = [];

    for (my $i = 0; $i < @{ $inp->[0] }; $i++) {
        for (my $j = 0; $j < @$inp; $j++) {
            $m->[$i][$j] = $inp->[$j][$i];
        }
    }

    return $m;
}

sub findBasis {
    my ($numBits) = @_;

    my $vecs = [];

    for (my $i = 0; $i < $numBits * 2; $i++) {
        my @itemBits = @{ splitBits(Digest::SHA::sha256("$i")) };
        push @$vecs, [ @itemBits[0 .. ($numBits-1)] ];
    }

    my $origVecs = Clone::clone($vecs);

    my ($rref, $pos) = gaussianElim($vecs);

    my $keepPos = [];

    for (my $i = 0; $i < @$rref; $i++) {
        if (List::Util::sum(@{ $rref->[$i] }) != 0) {
            push @$keepPos, $pos->[$i];
            last if @$keepPos == $numBits;
        }
    }

    my $basis = [ map { $origVecs->[$_] } @$keepPos ];

    return ($basis, $keepPos);
}

sub buildCollision {
    my ($target, $numBits) = @_;

    my ($basis, $inps) = findBasis($numBits);

    push @$basis, $target;

    my $m = transpose($basis);

    my ($n, $npos) = gaussianElim($m);
    $n = transpose($n);
    $n = $n->[-1];

    my $output = [];

    for (my $i = 0; $i < @$n; $i++) {
        if ($n->[$i]) {
            push @$output, $inps->[$i];
        }
    }

    return $output;
}

## Adapted from https://github.com/flavioeverardo/gauss_jordan_elimination

sub gaussianElim {
    my $m = shift;
    my $pos = [(0 .. (@$m - 1))];

    my $swap = sub {
        my ($i, $j) = @_;
        ($m->[$i], $m->[$j]) = ($m->[$j], $m->[$i]);
        ($pos->[$i], $pos->[$j]) = ($pos->[$j], $pos->[$i]);
    };

    my $xor = sub {
        my ($i, $j) = @_;
        for (my $e = 0; $e < @{ $m->[0] }; $e++) {
            $m->[$j][$e] ^= $m->[$i][$e];
        }
    };

    ## Forward elimination

    my $r = 0;
    my $right_most_col = 0;
    my $lowest_row = 0;

    for my $c (0 .. (@{ $m->[0] } - 2)) {
        my ($_swap, $_xor);

        for (my $j = $r+1; $j < @$m; $j++) {
            if ($m->[$r][$c] == 0 && $m->[$j][$c] == 1) {
                $swap->($r, $j);
                $_swap = 1;
            }

            if ($m->[$r][$c] == 1) {
                $_xor = 1;
                if ($m->[$j][$c] == 1) {
                    $xor->($r, $j);
                }
            }
        }

        if ($m->[$r][$c] == 1) {
            $right_most_col = $c;
            $lowest_row = $r;
        }

        if ($_swap || $_xor) {
            $r++;
        }
    }

    ## Backward substitution

    $r = $lowest_row;

    for (my $c = $right_most_col; $c > 0; $c--) {
        my $_xor;
        for (my $j = $r - 1; $j > -1; $j--) {
            if ($m->[$r][$c] == 1 && $m->[$j][$c] == 1) {
                $_xor = 1;
                $xor->($r, $j)
            }
        }

        if ($m->[$r][$c-1] == 0) {
            $r--;
        }
    }

    return ($m, $pos);
}
