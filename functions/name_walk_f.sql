-- name_walk_f.sql
--  A function to ascend the name tree to family
--   1º use is to find parent name parts when all else fails
--
drop function if exists name_walk(bigint, text) cascade;
create function name_walk(nameid bigint, rank text)
	-- nameid = name.id
	-- rank = name_rank.rdf_id
	-- walk up the name_part_tree to collect name_element at rank
	returns
		jsonb   -- at rankid
	language plpgsql
as
$$
declare
    name_id bigint;
	rorder integer;
	p bigint;
	f bigint;
	s integer;
	name text;
	element text;
	fid bigint;
begin

	select sort_order into f from name_rank where rdf_id = 'family';
	select sort_order into s from name_rank where rdf_id = rank;

    SELECT into p, rorder, name, element, fid parent_id, sort_order, simple_name, name_element, family_id
    from public.name
	         join public.name_rank on name.name_rank_id = name_rank.id
    WHERE name.id = nameid;

    while  rorder > s and p is not null and s < f loop

			name_id := p;

            SELECT into p, rorder, name, element,  fid parent_id, sort_order, simple_name,name_element, family_id from public.name
	                join public.name_rank on name.name_rank_id = name_rank.id
            WHERE name.id = name_id;

    end loop;

	if s = rorder then
	    return jsonb_build_object ('id', name_id, 'name', name, 'element', element, 'family_id', fid);
    else
		return null;
    end if;

end;
$$;