# XOR Hash Collision Generator

The paper [A New Paradigm for Collision-free Hashing: Incrementality at Reduced Cost](https://cseweb.ucsd.edu/~mihir/papers/inc-hash.pdf) by Mihir Bellare and Daniele Micciancio described a GF(2) gaussian elimination attack on an incremental hash function they called XHASH. I couldn't find an actual implementation of that attack anywhere, so I built one.

## Concept

Can you generate a set of input values that when hashed and then bitwise XORed together equal some target value? The perhaps surprising answer is yes.

Suppose you want your target value to start with `fd`. Run the following:

    $ perl gen-collision.pl fd
    6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b (1)
    ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d (5)
    7902699be42c8a8e46fbbb4501726517e86b22c56a189f7625a6da49081b2451 (7)

The values in parentheses are the input values, and the long hex values are their SHA-256 hashes, which you can verify like so:

    $ for i in 1 5 7; do echo -n $i | sha256sum; done
    6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b  -
    ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d  -
    7902699be42c8a8e46fbbb4501726517e86b22c56a189f7625a6da49081b2451  -

If we bitwise XOR the first bytes of these hashes together, we get our target value of `fd`:

    $ perl -e 'printf("%x\n", 0x6b ^ 0xef ^ 0x79)'
    fd

In this repo there's also a convenience script for XORing together values from standard input, one per line:

    $ perl gen-collision.pl fd | perl xor-input.pl 
    fda9c995f863e24471405a4e1b63562135d9a41db31939f05b7f07c1db339c87

Now let's try to target all 256 bits. We feed the output of our `gen-collision.pl` script into the `xor-input.pl` convenience script:

    $ perl gen-collision.pl ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff | perl xor-input.pl 
    ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

The collision is generated by XORing together 132 values, and takes about 2 seconds on my laptop:

    $ time perl gen-collision.pl ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff | wc -l
    132

    real    0m1.791s
    user    0m1.758s
    sys     0m0.012s


## Implementation

### Finding a basis

First we try to find a vector basis. To do this, we generate `2N` input values, where `N` is the targeted number of bits. `2N` is used to make it (extremely) likely we will be able to find N linearly independent vectors.

For convenience, to generate input values we are just using sequential integers (stringifed in ASCII decimal). With a small modification to the script, any arbitrary values could be used instead. Or, alternatively, you could use pre-existing items if it is not possible to insert your own.

Next we hash each input value and format it as a vector where each element is a bit of the hash. These vectors are then put into a `2N x N` matrix, one input hash per row, and then converted into reduced row echelon form using gaussian elimination. The field GF(2) is used, which means XOR is substituted for addition. I adapted a gaussian elimination [sub-routine](https://github.com/flavioeverardo/gauss_jordan_elimination) written by Flavio Everardo for this.

When performing the gaussian elimination, every time a row is swapped, we track its new position in the matrix so we can recover the original input. Afterwards, we collect the first `N` rows from the matrix, skipping over any all-zero rows (they were not linearly independent of the other rows, so cannot be used for our basis), and recover the corresponding original input rows.

These `N` rows represent our basis, and can be used to generate collisions for any target value.

### Building the collision

The `N` basis rows are put into a new matrix, and this matrix is then transposed. Note that if a square matrix's rows are linearly independent, then so are its columns. The target value is appended as an additional column, resulting in an `N x (N+1)` augmented matrix.

Next, another GF(2) gaussian elimination is run. The augmented column now indicates which items from our basis should be included. For each row, the item at the corresponding index should only be included if the entry in the augmented column is `1`. The included items are output, along with their hashes.


## Author

Doug Hoyte, 2023
