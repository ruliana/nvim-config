" Additional BigQuery syntax for SQL files
" This adds BigQuery pipe operator support to regular SQL files

" BigQuery Pipe Operator
syn match sqlBQPipeOperator "|>" 

" Highlight the pipe operator
hi sqlBQPipeOperator guifg=#ff79c6 ctermfg=212 gui=bold cterm=bold

" BigQuery-specific functions that might appear in SQL files
syn keyword sqlFunction farm_fingerprint countif sumif avgif
syn keyword sqlFunction array_agg array_concat array_length
syn keyword sqlFunction current_datetime current_timestamp
syn keyword sqlFunction regexp_extract regexp_replace regexp_contains
syn keyword sqlFunction safe_cast safe_divide

" BigQuery backtick table references
syn region sqlBQTableRef start=/`/ end=/`/
hi def link sqlBQTableRef Identifier