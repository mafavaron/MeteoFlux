#!/usr/bin/env python

from distutils.core import setup
from Cython.Build import cythonize

setup(ext_modules=cythonize("base_funcs.pyx"))

