-- Test case 1: single commented line
-- select 1

-- Test case 2: multiple commented lines
-- select * 
-- from `project.dataset.table`
-- where id = 1

-- Test case 3: mixed (should not uncomment)
-- This is a comment explaining the query
select * from `project.dataset.table`

-- Test case 4: indented comments
--    select * from `project.dataset.table`
--    where condition = true

-- Test case 5: empty lines between comments
-- select *

-- from `project.dataset.table`
-- where id = 1

-- Test case 6: whitespace-only lines (tabs and spaces)
-- select *
	  
-- from `project.dataset.table`

-- Test case 7: comments without space after --
--select count(*)
--from `project.dataset.table`

-- Test case 8: only comment markers
--
-- select 1
--