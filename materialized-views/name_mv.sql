/* name_mv.sql */
/* NSL-4180 :   Create new materialised views with camel case to provide base views for NAME and TAXON */
/* Builds name_mv and dependent views dwc_name_v and ( soon, name_view) */


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

	-- return null;

	select sort_order into f from name_rank where rdf_id = 'family';
	select sort_order into s from name_rank where rdf_id = rank;

	SELECT into p, rorder, name, element, fid parent_id, sort_order, simple_name, name_element, family_id from public.name
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

/*
  name_mv: 'A snake_case listing of a shard's scientific_names with status according to the current default tree version,using Darwin_Core semantics'
  has dependents: dwc_name_view
*/
drop materialized view if exists public.name_mv cascade;
create materialized view public.name_mv
			(name_id, basionym_id,
			 scientific_name, scientific_name_html, canonical_name, canonical_name_html, name_element,
			 scientific_name_id, name_type,
			 nomenclatural_status, scientific_name_authorship, changed_combination,
			 autonym, hybrid, cultivar, formula, scientific, nom_inval, nom_illeg,
			 name_published_in, name_published_in_id, name_published_in_year,
			 name_instance_type,
			 name_according_to_id, name_according_to, original_name_usage, original_name_usage_id,
			 original_name_usage_year,
			 type_citation, kingdom, family, uninomial, infrageneric_epithet, generic_name, specific_epithet,
			 infraspecific_epithet, cultivar_epithet, rank_rdf_id, taxon_rank,
			 taxon_rank_sort_order, taxon_rank_abbreviation, first_hybrid_parent_name, first_hybrid_parent_name_id,
			 second_hybrid_parent_name,
			 second_hybrid_parent_name_id, created, modified, nomenclatural_code, dataset_name,
			 taxonomic_status, status_according_to,
			 license, cc_attribution_iri
				)   
AS
select *
from (
	     SELECT distinct on (n.id) n.id                                                         AS name_id,
	                               basionym_inst.name_id                                        AS basionym_id,
	                               n.full_name                                                  AS scientific_name,
	                               n.full_name_html                                             AS scientific_name_html,
	                               n.simple_name                                                AS canonical_name,
	                               n.simple_name_html                                           AS canonical_name_html,
	                               n.name_element                                               AS name_element,
	                               ((mapper_host.value)::text || n.uri)                         AS scientific_name_id,
	                               nt.rdf_id                                                      AS name_type,
	                               CASE
		                               WHEN ns.rdf_id !~ 'default' THEN ns.name
		                           END                                                      AS nomenclatural_status,
                                   CASE ng.rdf_id
                                    WHEN 'zoological' THEN
                                      CASE WHEN n.changed_combination THEN
			                              '('||a.abbrev || coalesce(', '||n.published_year,'')||')'
                                      ELSE
                                           a.abbrev ||coalesce(', '||n.published_year,'')
                                      END
                                    WHEN 'botanical' THEN
	                                 CASE
		                                WHEN nt.autonym THEN NULL::text
		                                ELSE
	                                      coalesce( '('|| coalesce( xb.abbrev||' ex ','') || b.abbrev||') ','') ||
	                                          coalesce( coalesce( xa.abbrev||' ex ','') || a.abbrev,'')
	                                  END
		                            END                                                      AS scientific_name_authorship,

	                               coalesce((n.base_author_id::integer)::boolean, n.changed_combination) AS changed_combination,
	                               nt.autonym,
	                               nt.hybrid,
	                               nt.cultivar,
	                               nt.formula,
	                               nt.scientific,
	                               ns.nom_inval                                                 AS nom_inval,
	                               ns.nom_illeg                                                 AS nom_illeg,
	                               CASE WHEN coalesce(primary_ref.abbrev_title,'null') != 'AFD' THEN
	                                  primary_ref.citation || ' [' || primary_inst.page || ']'  END                                 AS name_published_in,
	                               CASE WHEN coalesce(primary_ref.abbrev_title,'null') != 'AFD' THEN
	                                    mapper_host.value || 'reference/' || path.value || '/' || primary_ref.id  END AS name_published_in_id,
	                               CASE WHEN coalesce(primary_ref.abbrev_title,'null') != 'AFD' THEN
	                               COALESCE(substr(primary_ref.iso_publication_date, 1, 4),
	                                        primary_ref.year::text)::INTEGER  END               AS name_published_in_year,
	                               primary_it.name                                              AS name_instance_type,
	                               mapper_host.value || primary_inst.uri::text                  AS name_according_to_id,
	                               primary_auth.name ||
	                                       CASE
		                                       WHEN coalesce(primary_ref.iso_publication_date, primary_ref.year::text) is not null
			                                       THEN
					                               ' (' || coalesce(primary_ref.iso_publication_date, primary_ref.year::text) || ')'
		                                     END                                                      AS name_according_to,
	                               basionym.full_name                                           AS original_name_usage,
	                               CASE
		                               WHEN basionym_inst.id IS NOT NULL
			                               THEN mapper_host.value || basionym_inst.uri::text
		                               END                                                      AS original_name_usage_id,
	                               COALESCE(substr(basionym_ref.iso_publication_date, 1, 4),
	                                        basionym_ref.year::text)
	                                                                                            AS original_name_usage_year,
	                               CASE
		                               WHEN nt.autonym = true THEN parent_name.full_name
		                               ELSE (SELECT string_agg(regexp_replace(
				                                                       (key1.rdf_id || ': ' || note.value)::text,
				                                                       '[\r\n]+'::text, ' '::text, 'g'::text),
		                                                       '; '::text) AS string_agg
		                                     FROM instance_note note
			                                          JOIN instance_note_key key1
			                                               ON key1.id = note.instance_note_key_id AND
			                                                  key1.rdf_id ~* 'type$'
		                                     WHERE note.instance_id in (primary_inst.id, basionym_inst.cites_id)
		                               )
		                               END                                                      AS type_citation,

	                               COALESCE((SELECT find_tree_rank.name_element
	                                         FROM find_tree_rank(coalesce(tve.element_link, tve2.element_link),
	                                                             kingdom.sort_order) find_tree_rank(name_element, rank, sort_order)),
	                                        CASE
		                                        WHEN code.value = 'ICN' THEN 'Plantae'
		                                        END)                                            AS kingdom,

	                               CASE
		                               when rank.sort_order > family.sort_order THEN
			                               coalesce((SELECT find_tree_rank.name_element
			                                         FROM find_tree_rank(
					                                              coalesce(tve.element_link, tve2.element_link),
					                                              family.sort_order) find_tree_rank(name_element, rank, sort_order)),
			                                   (
			                                    (SELECT find_tree_rank.name_element
			                                     FROM find_tree_rank(
					                                          coalesce(
					                                               (  select element_link from tree_version_element tvg
					                                                       join tree_element e on tvg.tree_element_id = e.id
					                                                          and e.name_id =  ((select  name_walk(n.id, 'genus')) ->> 'id')::bigint
					                                                       limit 1
					                                                   ),
					                                               (  select element_link from tree_version_element tvs
						                                                   join tree_element es on tvs.tree_element_id = es.id
						                                                     join instance gi on es.instance_id = gi.cited_by_id
						                                                       and gi.name_id =  ((select  name_walk(n.id, 'genus')) ->> 'id')::bigint
					                                                       limit 1
					                                                   )
					                                           ),
					                                          family.sort_order) find_tree_rank(name_element, rank, sort_order)
				                                   )),
			                                        (
				                                        -- genus_family.name_element
			                                            select f.name_element from name f
			                                                join name g on g.family_id = f.id
			                                                  and g.id = ((select  name_walk(n.id, 'genus')) ->> 'id')::bigint
				                                        ),
			                                        (
				                                        family_name.name_element
				                                        )
				                               )
		                               END                                                      AS family,
	                               CASE WHEN coalesce(n.simple_name,' ') !~ '\s'
		                               and n.simple_name =  n.name_element
		                               and  rank.sort_order <= genus.sort_order
		                                    THEN  n.simple_name
		                               END                                                     AS uninomial,
	                               CASE
		                               when pk.rdf_id = 'genus'
			                               and rank.rdf_id <> 'species' then
			                               n.name_element
		                               END                                                      as infrageneric_epithet,

	                               CASE
		                               when rank.sort_order >= genus.sort_order then
		                                   coalesce( name_walk(n.id, 'genus') ->> 'element', -- p.tk[1] )
		                                             (array_remove(string_to_array(regexp_replace(rtrim(substr(n.simple_name,1,length(n.simple_name)-length(n.name_element))), '(^cf\. |^aff[,.]  )', '', 'i'), ' '), 'x')|| n.name_element::text )[1] )

		                              END                                                      AS generic_name,

	                               CASE
		                               WHEN rank.sort_order > species.sort_order then
			                               coalesce( name_walk(n.id, 'species') ->> 'element', -- p.tk[2] )
			                                         (array_remove(string_to_array(regexp_replace(rtrim(substr(n.simple_name,1,length(n.simple_name)-length(n.name_element))), '(^cf\. |^aff[,.]  )', '', 'i'), ' '), 'x')|| n.name_element::text )[2] )
		                               WHEN rank.sort_order = species.sort_order then
			                               n.name_element
		                               END                                                      AS specific_epithet,

	                               CASE
		                               WHEN rank.sort_order > species.sort_order then
			                               n.name_element
		                               END                                                      AS infraspecific_epithet,
	                               CASE
		                               WHEN (nt.cultivar = true) THEN n.name_element
		                               ELSE NULL::character varying
		                               END                                                      AS cultivar_epithet,

	                               rank.rdf_id                                                  AS rank_rdf_id,
	                               rank.name                                                    AS taxon_rank,
	                               rank.sort_order                                              AS taxon_rank_sort_order,
	                               rank.abbrev                                                  AS taxon_rank_abbreviation,
	                               first_hybrid_parent.full_name                                AS first_hybrid_parent_name,
	                               ((mapper_host.value)::text || first_hybrid_parent.uri)       AS first_hybrid_parent_name_id,
	                               second_hybrid_parent.full_name                               AS second_hybrid_parent_name,
	                               ((mapper_host.value)::text || second_hybrid_parent.uri)      AS second_hybrid_parent_name_id,
	                               n.created_at                                                 AS created,
	                               n.updated_at                                                 AS modified,
	                               COALESCE(code.value, 'ICN'::character varying)::text         AS nomenclatural_code,
	                               dataset.value                                                AS dataset_name,

	                               CASE
		                               WHEN t.accepted_tree THEN
			                               CASE
				                               WHEN te.excluded THEN 'excluded'::text
				                               ELSE 'accepted'::text
				                               END
		                               WHEN t2.accepted_tree THEN
			                               CASE
				                               WHEN te2.excluded THEN 'excluded'::text
				                               ELSE 'included'::text
				                               END
		                               ELSE
			                               'unplaced'::text
		                               END                                                      AS taxonomic_status,

	                               accepted_tree.name                                           AS status_according_to,
	                               'https://creativecommons.org/licenses/by/3.0/'::text         AS license,
	                               ((mapper_host.value)::text || n.uri)                         AS cc_attribution_iri
	     FROM name n
		          JOIN name_type nt ON n.name_type_id = nt.id
	                JOIN name_group ng on ng.id = nt.name_group_id
		          JOIN name_status ns ON n.name_status_id = ns.id
		          LEFT JOIN name parent_name ON n.parent_id = parent_name.id
		          LEFT JOIN name family_name ON n.family_id = family_name.id

	              LEFT JOIN author b on n.base_author_id = b.id
		          LEFT JOIN author xb on n.ex_base_author_id = xb.id
		          LEFT JOIN author a on n.author_id = a.id
		          LEFT JOIN author xa on n.ex_author_id = xa.id

		          LEFT JOIN name first_hybrid_parent
		                    ON n.parent_id = first_hybrid_parent.id AND nt.hybrid
		          LEFT JOIN name second_hybrid_parent
		                    ON n.second_parent_id = second_hybrid_parent.id AND nt.hybrid

		          LEFT JOIN instance primary_inst
		            JOIN instance_type primary_it
		               ON primary_it.id = primary_inst.instance_type_id AND primary_it.primary_instance
		            JOIN reference primary_ref ON primary_inst.reference_id = primary_ref.id
		            JOIN author primary_auth ON primary_ref.author_id = primary_auth.id
		          ON primary_inst.name_id = n.id

		          LEFT JOIN instance basionym_rel
		              JOIN instance_type bt ON bt.id = basionym_rel.instance_type_id AND bt.rdf_id = 'basionym'
		              JOIN instance basionym_inst on basionym_rel.cites_id = basionym_inst.id
		                 JOIN name basionym ON basionym.id = basionym_inst.name_id
		                 JOIN reference basionym_ref ON basionym_inst.reference_id = basionym_ref.id
		          ON basionym_rel.cited_by_id = primary_inst.id

		          LEFT JOIN shard_config mapper_host ON mapper_host.name::text = 'mapper host'::text
		          LEFT JOIN shard_config dataset ON dataset.name::text = 'name label'::text
		          LEFT JOIN shard_config code ON code.name::text = 'nomenclatural code'::text
	              LEFT JOIN shard_config path on path.name = 'services path name element'::text

		          join name_rank kingdom on kingdom.rdf_id ~ '(regnum|kingdom)'
		          join name_rank family on family.rdf_id ~ '(^family|^familia)'
		          join name_rank genus on genus.rdf_id = 'genus'
		          join name_rank species on species.rdf_id = 'species'

		          join name_rank rank
		            left join name_rank pk
		               on rank.parent_rank_id = pk.id
		          on n.name_rank_id = rank.id

	              JOIN tree accepted_tree on accepted_tree

		          LEFT JOIN tree_element te
		           JOIN tree_version_element tve ON te.id = tve.tree_element_id
		           JOIN tree t ON tve.tree_version_id = t.current_tree_version_id AND t.accepted_tree
		          ON te.name_id = n.id

		          LEFT JOIN instance s
		           JOIN tree_element te2 on te2.instance_id = s.cited_by_id
		           JOIN tree_version_element tve2 ON te2.id = tve2.tree_element_id
		           JOIN tree t2 ON tve2.tree_version_id = t2.current_tree_version_id AND t2.accepted_tree
		          ON s.name_id = n.id

	         /*
	             left join lateral ( select  name_walk(n.id, 'genus')) pg(value)
		             join name g on g.id = (pg.value ->> 'id')::bigint
		               join name genus_family on g.family_id = genus_family.id
		         on true

	          */

	     WHERE EXISTS(SELECT 1
	                  FROM instance
	                  WHERE instance.name_id = n.id
		     )
		   and  nt.rdf_id !~ '(common|vernacular)'
	       and n.name_element !~* 'unplaced'
	     ORDER BY n.id, name_published_in_year, original_name_usage_year
	     --  limit 1000
              ) nv
 order by family, generic_name, specific_epithet, infraspecific_epithet, cultivar_epithet
;

create unique index name_mv_name_id_i on name_mv(scientific_name_id);
create index name_mv_name_i on name_mv(scientific_name);
create index name_mv_id_i on name_mv (name_id);
create index name_mv_canonical_i on name_mv (canonical_name);
create index name_mv_family_i on name_mv (family);

COMMENT ON MATERIALIZED VIEW NAME_MV is 'A snake_case listing of a shard''s scientific_names with status according to the current default tree version,using Darwin_Core semantics';

