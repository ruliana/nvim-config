" BigQuery file type detection
" Detect .bq files as BigQuery SQL
autocmd BufRead,BufNewFile *.bq set filetype=bigquery

" Also detect .sql files that contain BigQuery pipe syntax
autocmd BufRead,BufNewFile *.sql call s:DetectBigQuery()

function! s:DetectBigQuery()
  " Check first 50 lines for BigQuery-specific syntax
  let n = 1
  while n <= 50 && n <= line("$")
    let line = getline(n)
    " Look for pipe operator or BigQuery-specific keywords
    if line =~ '|>' || 
       \ line =~ '\<from\s\+`' ||
       \ line =~ 'farm_fingerprint' ||
       \ line =~ 'INT64\|FLOAT64\|STRING' ||
       \ line =~ '_TABLE_SUFFIX\|_PARTITIONDATE'
      set filetype=bigquery
      return
    endif
    let n = n + 1
  endwhile
endfunction