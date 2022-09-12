/* view_tools.sql */
             

/* copied here for reference only:  DDL lives in domain plugin.

select coalesce ( (SELECT find_tree_rank.name_element
                   FROM find_tree_rank( null, 10)), 'XXX'); */

create or replace function find_tree_rank(tve_id text, rank_sort_order integer)
    returns TABLE
        (
        name_element text,
        rank         text,
        sort_order   integer
        )
    language sql
    as
$$
WITH RECURSIVE walk (parent_id, name_element, rank, sort_order) AS (
    SELECT tve.parent_id,
           n.name_element,
           r.name,
           r.sort_order
    FROM tree_version_element tve
             JOIN tree_element te ON tve.tree_element_id = te.id
             JOIN name n ON te.name_id = n.id
             JOIN name_rank r ON n.name_rank_id = r.id
    WHERE tve.element_link = tve_id
      AND r.sort_order >= rank_sort_order -- or r.rdf_id = 'higher-taxon'
    UNION ALL
    SELECT tve.parent_id,
           n.name_element,
           r.name,
           r.sort_order
    FROM walk w,
         tree_version_element tve
             JOIN tree_element te ON tve.tree_element_id = te.id
             JOIN name n ON te.name_id = n.id
             JOIN name_rank r ON n.name_rank_id = r.id
    WHERE tve.element_link = w.parent_id
      AND r.sort_order >= rank_sort_order -- or r.rdf_id = 'higher-taxon'
)
SELECT w.name_element,
       w.rank,
       w.sort_order
FROM walk w
WHERE w.sort_order = rank_sort_order
    limit 1
$$;



create function find_rank(name_id bigint, rank_sort_order integer)
    returns TABLE
        (
        name_element text,
        rank         text,
        sort_order   integer
        )
    language sql
    as
$$
WITH RECURSIVE walk (parent_id, name_element, rank, sort_order) AS (
    SELECT parent_id,
           n.name_element,
           r.name,
           r.sort_order
    FROM name n
             JOIN name_rank r ON n.name_rank_id = r.id
    WHERE n.id = name_id
      AND r.sort_order >= rank_sort_order
    UNION ALL
    SELECT n.parent_id,
           n.name_element,
           r.name,
           r.sort_order
    FROM walk w,
         name n
             JOIN name_rank r ON n.name_rank_id = r.id
    WHERE n.id = w.parent_id
      AND r.sort_order >= rank_sort_order
)
SELECT w.name_element,
       w.rank,
       w.sort_order
FROM walk w
WHERE w.sort_order >= rank_sort_order
order by w.sort_order asc
    limit 1
$$;

/* */
