#!/bin/bash
sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d'