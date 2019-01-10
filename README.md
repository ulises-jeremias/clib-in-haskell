# CLib in Haskell

> How To Link A C Library In Haskell

Example of how to link a C library in Haskell.

## Introduction

This repository shows how to link a C library in Haskell with the aim of studying and developing a simple environment to link the [SciC](https://github.com/ScientificC) libraries in future projects developed in haskell.

## Steps

### Develop a small C program

The C program is extremely simple. The `main.c` is calling a library function and printing the result. You can find the main file in the `clib` dir.

```c
#include <stdio.h>
#include "liba.h"

int main(int argc, char *argv[]) {
	printf("main.c: main()\n");
	double a = liba_func(1.0); // 42
	printf("main.c: a = %f\n", a);
}
```

### The static libraries

We can convert `lib*.o` into static libraries using `ar`. This tool creates a so called archive file which is basically just a collection of object files. In our case, both archives each contain only one object file. For completeness, we’ll let `gcc` link again the static libraries instead of the object files for `main`, too

Considering the final goal of this project, it is useful to have a way of importing the `lib*.a` files since it is the way in which the SciC libraries are compiled and installed.

In the `Makefile` you can see the commands executed to generate the static libraries.

One can inspect the archive content with `nm <file.a>`. We see that `libb.a` defines the function 
(_symbol_) `libb_func` and expects the symbol `fmod`. The latter comes from `math.h` and the actual function is linked by gcc (see -lm in the Makefile’s main target).

### Merging the libraries

The libraries developed by SciC have a great advantage and is that all projects are built from ||`CMake`, so there are certain problems that we do not know about. One of them is the merge of the static libraries, and this is because each one of the libraries ends up in a single `lib*.a` file. However, in this case we will need a mechanism that allows us to merge the two generated libraries.

Without going deeply into the topic, since researching it is very simple, there are problems using `ar` in the most intuitive way, `ar -csr libab.a liba.a libb.a`. Linked objects will not be found when it is generated in this way. That is why the following solution is proposed.

```bash
$ echo 'CREATE libab.a\nADDLIB liba.a\nADDLIB libb.a\nSAVE\nEND' | ar -M
$ nm libab.a
```

And it works! :D

### The Haskell program

The Haskell program is straight forward. I’ll let `stack` create the a simply project.

```bash
$ stack new haskell simple
```

And the `Main.hs`

```haskell
module Main where

import LibAb

main :: IO ()
main = do
  putStrLn "Please enter a number:"
  d <- fmap (read :: String -> Double) getLine
  a <- liba_func d
  putStrLn $ "The answer is: " ++ show a
```

### Linking to the C library

`stack` generates a `Cabal` file within the project. This file is kind of like the Makefile of a Haskell app.

> I do not particularly like writing Makefiles, so I really like the idea of someone or something generating them for me.

We can define GHC options within that file. In order to tell GHC to link to an external library, we have to give a library path and a library name (pretty similar to GCC). This is done by `-L<path>` and `-l<libname>` respectively. Fucking equal to GCC. So we could simply use stack’s ghc-options parameter to add these. However, it is recommended to use `extra-lib-dirs` and `extra-libaries` instead. This is how we need to adapt the cabal file:

```cabal
executable haskell
  hs-source-dirs:      src
  --  ghc-options:         -L../clib -lab when lib a & b are merged into lib ab
  -- extra-lib-dirs:      ../clib
  -- extra-libraries:     ab
  
  -- ghc-options:         -L../clib -la b
  extra-lib-dirs:      ../clib
  extra-libraries:     a b
  main-is:             Main.hs
  default-language:    Haskell2010
  build-depends:       base >= 4.7 && < 5
```

where `../clib` is the path to the aforementioned C program which contains `libab.a`, `liba.a` and `libb.a`.

In the future, when you use libraries like [cmath](https://scientificc.github.io/cmathl/), it will be as simple as adding the cml path and library.

### Using the C library

In the `haskell/src/LibAb.hs` file you can find a wrapper Haskell library (file) that exposes the functions of the C library. Calling the actual C functions is done trough Haskell’s [Foreign Function Interfarce](https://wiki.haskell.org/Foreign_Function_Interface). The source code is simple and listed below.

```haskell
{- enabling the FFI -}
{-# LANGUAGE ForeignFunctionInterface #-}

module LibAb where -- declaring the module

{- importing the C function -}
foreign import ccall "liba_func" c_liba_func :: Double -> IO Double

liba_func :: Double -> IO Double
-- wrapping the C function inside a Haskell function
liba_func = c_liba_func
```

Then execute

```bash
$ stack build --exec haskell
```

This is the outcome:

```bash
$ stack build --exec haskell
... 
Please enter a number:
1.0
liba.c:liba_func() side effects!
The answer is: 42.0
```

#### Important about side effects

Supose whe have `liba_func` like this:

```haskell
liba_func :: Double -> Double
-- wrapping the C function inside a Haskell function
liba_func = c_liba_func
```

Note how the pure Haskell function `liba_func :: Double -> Double` produces side effects! This is quite expected. The Haskell compiler cannot look into the compiled C functions and cannot differentiate pure from _impure code_. It merely links the foreign functions where asked to. The programmer needs to provide this information. In this case, it should have been `liba_func :: Double -> IO Double` to accommodate for the `printf` in the C function.
