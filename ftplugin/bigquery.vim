" BigQuery filetype plugin
" Sets proper indentation and other settings for BigQuery files

" Set indentation to 3 spaces for BigQuery pipe syntax
setlocal shiftwidth=3
setlocal tabstop=3
setlocal softtabstop=3
setlocal expandtab

" Enable automatic indentation
setlocal autoindent
setlocal smartindent

" Set comment format
setlocal commentstring=--\ %s

" Set format options
setlocal formatoptions-=t
setlocal formatoptions+=croql

" Match pairs for % command
setlocal matchpairs+=<:>

" Set text width (optional, can be removed if not desired)
" setlocal textwidth=100

" Folding settings (optional)
" setlocal foldmethod=indent
" setlocal foldlevel=99