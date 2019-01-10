{- enabling the FFI -}
{-# LANGUAGE ForeignFunctionInterface #-}

module LibAb where -- declaring the module

{- importing the C function -}
foreign import ccall "liba_func" c_liba_func :: Double -> IO Double

liba_func :: Double -> IO Double
-- wrapping the C function inside a Haskell function
liba_func = c_liba_func
