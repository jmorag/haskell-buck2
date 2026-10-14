# Buck2 prelude for Haskell projects

This is a version of the [Buck2
prelude](https://github.com/facebook/buck2/tree/main/prelude) with a
few tweaks (that will hopefully be upstreamed at some point) and some
support code for building Haskell projects.

You probably don't want this by itself---instead take a look at
[cabal-buck2](https://hackage.haskell.org/package/cabal-buck2) which
extends `cabal` with a `buck2` command so that you can use Buck2 as
the build tool for your Cabal project.

# Build modes

The Buck2 build system has two build modes:

  * `dev`: the default, builds everything with `-O0` and dynamic linking. This is intended to give you the quickest edit-compile-test turnaround.
  * `opt`: enable `-O` and link statically. This takes longer but the code runs faster.

To build with `opt`, use `-m opt`, e.g.

```
buck2 build my-package:my-program -m opt
```

There are other build options that can be selected in a similar way, such as `-m prof` to enable profiling. See `constraints/BUCK` for details.

# Testing this repo

This repository has no tests or CI of its own: it is the Buck2 support code for
[cabal-buck2](https://github.com/simonmar/cabal-buck2), which includes it as a
submodule (`buck2/`) and tests it, with an example project (`example/`:
Template Haskell, hsc2hs, C++ via FFI and a Hackage dependency) and with its
own build. Update the submodule there to test a change here.

`template/` has the `.buckconfig` and `PACKAGE` that `cabal buck2` copies to a
project that doesn't have them.
