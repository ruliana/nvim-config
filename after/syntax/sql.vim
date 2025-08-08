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

" BigQuery table references with backticks
" 3-part: `project.dataset.table`
syn match sqlBQTable3 /`[^`]*\.[^`]*\.[^`]*`/
" 2-part: `dataset.table`  
syn match sqlBQTable2 /`[^`]*\.[^`]*`/

hi sqlBQTable3 guifg=#bd93f9 ctermfg=141
hi sqlBQTable2 guifg=#bd93f9 ctermfg=141