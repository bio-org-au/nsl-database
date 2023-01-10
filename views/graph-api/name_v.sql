--  name_v.sql
--  Base name view for graphQL
--    A dynamic view aiming to return a name object with metadata links
--    depends on functions:
--      name_walk(nameid bigint, rank text) in name_walk_f.sql


drop view if exists NAME_V;
create view NAME_V
    --      column names
	--		(
	--		id, identifier, full_name, nomenclatural_status, full_name_html, simple_name, simple_name_html, name_type,
	--		authorship, basionym_id, primary_usage_id, primary_usage_type, primary_usage_year, rank_rdf_id, taxon_rank,
	--		taxon_rank_abbreviation, is_changed_combination, is_autonym, is_cultivar, is_name_formula, is_scientific,
	--		is_nom_inval, is_nom_illeg, type_citation, kingdom, family, uninomial, infrageneric_epithet, generic_name,
	--		specific_epithet, infraspecific_epithet, cultivar_epithet, is_hybrid, first_hybrid_parent_name, first_hybrid_parent_name_id,
	--		second_hybrid_parent_name, second_hybrid_parent_name_id, created, modified, nomenclatural_code, dataset_name, license,
	--		cc_attribution_iri, source_id, source_id_string, sort_name, taxon_rank_sort_order
	--		)
AS
SELECT * FROM (  -- so query can use aliases
   SELECT
                      n.id                                                                  AS id,
                      ((mapper_host.value)::text || n.uri)                                  AS identifier,
                      n.full_name                                                           AS full_name,
	                  -- [todo] nomenclatural_status voc-uri --
	                  CASE WHEN ns.rdf_id !~ 'default' THEN ns.name END                     AS nomenclatural_status,
	                  n.full_name_html /* RDFa ? */                                         AS full_name_html,
	                  n.simple_name                                                         AS simple_name,
	                  n.simple_name_html                                                    AS simple_name_html,
	                  --  [todo] experiment to see if name_element is needed --
                      --  n.name_element                                                    AS name_element,
	                  -- [todo] name-type voc-uri --
                      nt.rdf_id                                                             AS name_type ,

                      CASE ng.rdf_id
	                      WHEN 'zoological' THEN
		                      CASE
			                      WHEN n.changed_combination THEN
				                      '(' || a.abbrev || coalesce(', ' || n.published_year, '') || ')'
			                      ELSE
				                      a.abbrev || coalesce(', ' || n.published_year, '')
			                      END
	                      WHEN 'botanical' THEN
		                      CASE
			                      WHEN nt.autonym THEN NULL::text
			                      ELSE
					                      coalesce('(' || coalesce(xb.abbrev || ' ex ', '') || b.abbrev || ') ', '') ||
					                      coalesce(coalesce(xa.abbrev || ' ex ', '') || a.abbrev, '')
			                      END
	                      END                                                               AS authorship,

                      basionym_inst.id                                                      AS basionym_id,
                      primary_inst.id                                                       AS primary_usage_id,
                      primary_it.rdf_id                                                     AS primary_usage_type,
                      COALESCE(substr(basionym_ref.iso_publication_date, 1, 4),
                               basionym_ref.year::text)                                     AS primary_usage_year,

                      rank.rdf_id                                                           AS rank_rdf_id,
                      rank.name                                                             AS taxon_rank,
                      rank.abbrev                                                           AS taxon_rank_abbreviation,

                      coalesce((n.base_author_id::integer)::boolean, n.changed_combination) AS is_changed_combination,
                      nt.autonym                                                            AS is_autonym,
                      nt.cultivar                                                           AS is_cultivar,
                      nt.formula                                                            AS is_name_formula,
                      nt.scientific                                                         AS is_scientific,
                      ns.nom_inval                                                          AS is_nom_inval,
                      ns.nom_illeg                                                          AS is_nom_illeg,

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
	                            WHERE note.instance_id = primary_inst.id)
	                      END /* nest in 1ºinstance */                                      AS type_citation,


                      COALESCE((SELECT ftk.name_element
                                FROM find_tree_rank(coalesce(tve.element_link, tve2.element_link),
                                                    kingdom.sort_order) ftk),
                               CASE
	                               WHEN code.value = 'ICN' THEN 'Plantae'
	                               WHEN code.value = 'ICZN' THEN 'Animalia'
	                               END)                                                     AS kingdom,

                      CASE
	                      when rank.sort_order > family.sort_order THEN
		                      coalesce((SELECT ftf.name_element
		                                FROM find_tree_rank(
				                                     coalesce(tve.element_link, tve2.element_link),
				                                     family.sort_order) ftf),
		                               (
			                               (SELECT fcf.name_element
			                                FROM find_tree_rank(
					                                     coalesce(
							                                     (select element_link
							                                      from tree_version_element tvg
								                                           join tree_element e
								                                                on tvg.tree_element_id = e.id
									                                                and e.name_id =
									                                                    ((select name_walk(n.id, 'genus')) ->> 'id')::bigint
							                                      limit 1),
							                                     (select element_link
							                                      from tree_version_element tvs
								                                           join tree_element es on tvs.tree_element_id = es.id
								                                           join instance gi
								                                                on es.instance_id = gi.cited_by_id
									                                                and gi.name_id =
									                                                    ((select name_walk(n.id, 'genus')) ->> 'id')::bigint
							                                      limit 1)
						                                     ),
					                                     family.sort_order) fcf)),
		                               (
			                               -- genus_family.name_element
			                               select f.name_element
			                               from name f
				                                    join name g on g.family_id = f.id
				                               and g.id = ((select name_walk(n.id, 'genus')) ->> 'id')::bigint),
		                               (
			                               family_name.name_element
			                               )
			                      )
	                      END                                                               AS family,

                      CASE
	                      WHEN coalesce(n.simple_name, ' ') !~ '\s'
		                      and n.simple_name = n.name_element and nt.scientific
		                      and rank.sort_order <= genus.sort_order
		                      THEN n.simple_name
	                      END                                                               AS uninomial,
                      CASE
	                      when pk.rdf_id = 'genus' and nt.scientific
		                      and rank.rdf_id <> 'species' then
		                      n.name_element
	                      END                                                               as infrageneric_epithet,

                      CASE
	                      when rank.sort_order >= genus.sort_order and nt.scientific then
		                      coalesce(name_walk(n.id, 'genus') ->> 'element', -- p.tk[1] )
		                               (array_remove(string_to_array(regexp_replace(rtrim(substr(n.simple_name, 1,
		                                                                                         length(n.simple_name) -
		                                                                                         length(n.name_element))),
		                                                                            '(^cf\. |^aff[,.] )', '', 'i'),
		                                                             ' '), 'x') ||
		                                n.name_element::text)[1])
	                      END                                                               AS generic_name,

                      CASE
	                      WHEN rank.sort_order > species.sort_order and nt.scientific then
		                      coalesce(name_walk(n.id, 'species') ->> 'element', -- p.tk[2] )
		                               (array_remove(string_to_array(regexp_replace(rtrim(substr(n.simple_name, 1,
		                                                                                         length(n.simple_name) -
		                                                                                         length(n.name_element))),
		                                                                            '(^cf\. |^aff[,.] )', '', 'i'),
		                                                             ' '), 'x') ||
		                                n.name_element::text)[2])
	                      WHEN rank.sort_order = species.sort_order and nt.scientific then
		                      n.name_element
	                      END                                                               AS specific_epithet,

                      CASE
	                      WHEN rank.sort_order > species.sort_order and nt.scientific then
		                      n.name_element
	                      END                                                               AS infraspecific_epithet,
                      CASE
	                      WHEN (nt.cultivar = true) THEN n.name_element
	                      END                                                               AS cultivar_epithet,


                      nt.hybrid                                                             AS is_hybrid,
                      first_hybrid_parent.full_name                                         AS first_hybrid_parent_name,
                      ((mapper_host.value)::text || first_hybrid_parent.uri)                AS first_hybrid_parent_name_id,
                      second_hybrid_parent.full_name                                        AS second_hybrid_parent_name,
                      ((mapper_host.value)::text || second_hybrid_parent.uri)               AS second_hybrid_parent_name_id,
                      n.created_at                                                          AS created,
                      n.updated_at                                                          AS modified,
                      COALESCE(code.value, 'ICN'::character varying)::text                  AS nomenclatural_code,
                      dataset.value                                                         AS dataset_name,
                      -- change to 4.0 ?
                      'https://creativecommons.org/licenses/by/3.0/'::text                  AS license,
                      ((mapper_host.value)::text || n.uri)                                  AS cc_attribution_iri,
                      n.source_id,
                      n.source_id_string,
                      -- [todo] replace sort_name with flora sort
                      n.sort_name                                                           AS sort_name,
                      rank.sort_order                                                       AS taxon_rank_sort_order
               FROM name n
	                    JOIN name_type nt
	                    JOIN name_group ng on ng.id = nt.name_group_id
	                         ON n.name_type_id = nt.id
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

                        -- primary instance [todo] denormalize to name.primary_instance_id & name.year
	                    LEFT JOIN instance primary_inst

	                     JOIN instance_type primary_it
	                         ON primary_it.id = primary_inst.instance_type_id AND primary_it.primary_instance
	                     JOIN reference primary_ref ON primary_inst.reference_id = primary_ref.id
	                     JOIN author primary_auth ON primary_ref.author_id = primary_auth.id

                        -- the basionym [todo] denormalize to name.basionym_id
	                     LEFT JOIN instance basionym_rel
	                      JOIN instance_type bt ON bt.id = basionym_rel.instance_type_id AND bt.rdf_id = 'basionym'
	                      JOIN instance basionym_inst
	                      JOIN name basionym ON basionym.id = basionym_inst.name_id
	                      JOIN reference basionym_ref ON basionym_inst.reference_id = basionym_ref.id
	                         ON basionym_rel.cites_id = basionym_inst.id
	                         ON basionym_rel.cited_by_id = primary_inst.id
	                    ON primary_inst.name_id = n.id

	                    /* -- for lectotypification if needed
	                     LEFT JOIN instance type_inst
			                     JOIN instance_type type_it
				                      ON type_it.id = type_inst.instance_type_id
			                     JOIN instance_note nt ON type_inst.id = nt.instance_id
			                     JOIN instance_note_key tnk ON nt.instance_note_key_id = tnk.id
					                       and tnk.rdf_id ~ 'type$'
	                      ON type_inst.name_id = n.id AND NOT type_it.primary_instance
	                      */

	                    LEFT JOIN shard_config mapper_host ON mapper_host.name::text = 'mapper host'::text
	                    LEFT JOIN shard_config dataset ON dataset.name::text = 'name label'::text
	                    LEFT JOIN shard_config code ON code.name::text = 'nomenclatural code'::text
	                    LEFT JOIN shard_config path on path.name = 'services path name element'::text

	                    join name_rank kingdom on kingdom.rdf_id ~ '(regnum|kingdom)'
	                    join name_rank family on family.rdf_id ~ '(^family|^familia)'
	                    join name_rank genus on genus.rdf_id = 'genus'
	                    join name_rank species on species.rdf_id = 'species'

                        -- rank and rank parent
	                    join name_rank rank
	                    left join name_rank pk
	                              on rank.parent_rank_id = pk.id
	                              on n.name_rank_id = rank.id

	                    JOIN tree accepted_tree on accepted_tree

                        -- for the family if accepted name [todo] can we use name_mv?
	                    LEFT JOIN tree_element te
	                    JOIN tree_version_element tve
	                    JOIN tree t ON tve.tree_version_id = t.current_tree_version_id AND t.accepted_tree
	                         ON te.id = tve.tree_element_id
	                         ON te.name_id = n.id

	                    -- for the family if synonym
	                    LEFT JOIN tree_element te2
	                    JOIN tree_version_element tve2 ON te2.id = tve2.tree_element_id
	                    JOIN tree t2 ON tve2.tree_version_id = t2.current_tree_version_id AND t2.accepted_tree
	                         ON te2.instance_id = (select cited_by_id
	                                               from instance s
		                                                    JOIN instance_type st on st.id = s.instance_type_id and synonym
	                                               where s.name_id = n.id
	                                               LIMIT 1)

               WHERE EXISTS(SELECT 1
                            FROM instance
                            WHERE instance.name_id = n.id
	                     )
--
         ) nv
;


