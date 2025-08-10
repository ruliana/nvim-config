" BigQuery SQL syntax file
" Language:     BigQuery SQL
" Maintainer:   Ronie
" Last Change:  2024

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Start with standard SQL syntax as base
runtime! syntax/sql.vim
unlet b:current_syntax

" BigQuery Pipe Operator (most important!)
syn match bqPipeOperator "|>" 

" BigQuery-specific keywords for pipe syntax
syn keyword bqPipeKeyword from where select group order limit offset as by
syn keyword bqPipeKeyword join inner left right full cross on using
syn keyword bqPipeKeyword union intersect except distinct all
syn keyword bqPipeKeyword window partition rows between unbounded preceding following current row
syn keyword bqPipeKeyword qualify having

" BigQuery-specific functions
syn keyword bqFunction array_agg array_concat array_length array_to_string
syn keyword bqFunction countif sumif avgif maxif minif
syn keyword bqFunction date datetime timestamp time
syn keyword bqFunction extract date_add date_sub date_diff datetime_add datetime_sub
syn keyword bqFunction current_date current_datetime current_timestamp current_time
syn keyword bqFunction format_date format_datetime format_timestamp parse_date parse_datetime
syn keyword bqFunction regexp_extract regexp_replace regexp_contains regexp_extract_all
syn keyword bqFunction split string_agg concat
syn keyword bqFunction farm_fingerprint md5 sha1 sha256 sha512
syn keyword bqFunction row_number rank dense_rank percent_rank cume_dist ntile
syn keyword bqFunction lag lead first_value last_value
syn keyword bqFunction any_value approx_count_distinct approx_quantiles approx_top_count
syn keyword bqFunction st_geogpoint st_distance st_contains st_within
syn keyword bqFunction safe_cast safe_divide safe_multiply safe_add safe_subtract

" BigQuery data types
syn keyword bqType INT64 FLOAT64 NUMERIC BIGNUMERIC BOOL STRING BYTES
syn keyword bqType DATE DATETIME TIME TIMESTAMP
syn keyword bqType ARRAY STRUCT GEOGRAPHY JSON INTERVAL
syn keyword bqType RECORD REPEATED

" BigQuery system variables and pseudo columns
syn match bqSystemVar "\<_TABLE_SUFFIX\>"
syn match bqSystemVar "\<_PARTITIONDATE\>"
syn match bqSystemVar "\<_PARTITIONTIME\>"
syn match bqSystemVar "\<_FILE_NAME\>"

" BigQuery table references
" Support both 2-part (dataset.table) and 3-part (project.dataset.table) references
" Table references must be enclosed in backticks

" Table references WITH backticks
" IMPORTANT: 3-part must come before 2-part to match correctly

" 3-part: `project.dataset.table`
syn match bqTableRef3Backtick /`[^`]\+\.[^`]\+\.[^`]\+`/
hi bqTableRef3Backtick guifg=#8be9fd ctermfg=117

" 2-part: `dataset.table` 
syn match bqTableRef2Backtick /`[^`]\+\.[^`]\+`/
hi bqTableRef2Backtick guifg=#8be9fd ctermfg=117

" BigQuery comments (same as SQL but reinforced)
syn match bqComment "--.*$"
syn match bqComment "#.*$"
syn region bqComment start="/\*" end="\*/"

" BigQuery strings
syn region bqString start=+"+ end=+"+ contains=@Spell
syn region bqString start=+'+ end=+'+ contains=@Spell
syn region bqString start=+"""+ end=+"""+ contains=@Spell
syn region bqString start=+'''+ end=+'''+ contains=@Spell

" BigQuery template strings (for dynamic SQL)
syn region bqTemplate start=/@\w\+/ end=/\>/

" Highlight groups - link to standard vim highlight groups
hi def link bqPipeOperator    Operator
hi def link bqPipeKeyword     Statement
hi def link bqFunction        Function
hi def link bqType           Type
hi def link bqSystemVar      Special
hi def link bqComment        Comment
hi def link bqString         String
hi def link bqTemplate       PreProc

" Special highlighting for pipe operator to make it stand out
hi bqPipeOperator guifg=#ff79c6 ctermfg=212 gui=bold cterm=bold

" Make BigQuery functions stand out
hi bqFunction guifg=#8be9fd ctermfg=117 gui=NONE cterm=NONE

let b:current_syntax = "bigquery"