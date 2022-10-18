/* name_view.sql */

/* DEPRECATED in favour of dwc_name_v */

drop materialized view if exists name_view;
create materialized view name_view
			( name_id,
			 "scientificName", "scientificNameHTML", "canonicalName", "canonicalNameHTML", "nameElement",
			 "scientificNameID", "nameType",
			 "taxonomicStatus", "nomenclaturalStatus", "scientificNameAuthorship", "cultivarEpithet", autonym, hybrid,
			 cultivar, formula,
			 scientific, "nomInval", "nomIlleg", "namePublishedIn", "namePublishedInID","namePublishedInYear", "nameInstanceType",
			 "nameAccordingToID", "nameAccordingTo", "originalNameUsage", "originalNameUsageID",
			 "originalNameUsageYear",
			 "typeCitation", kingdom, family, "genericName", "specificEpithet", "infraspecificEpithet", "taxonRank",
			 "taxonRankSortOrder", "taxonRankAbbreviation", "firstHybridParentName", "firstHybridParentNameID",
			 "secondHybridParentName",
			 "secondHybridParentNameID", created, modified, "nomenclaturalCode",  "datasetName", license,
			 "ccAttributionIRI"
				)
AS
SELECT distinct on (n.id) n.id                                                                                      AS "nsl:name_id",
                          n.full_name                                                                               AS "scientificName",
                          n.full_name_html                                                                          AS "scientificNameHTML",
                          n.simple_name                                                                             AS "canonicalName",
                          n.simple_name_html                                                                        AS "canonicalNameHTML",
                          n.name_element                                                                            AS "nameElement",
                          ((mapper_host.value)::text || n.uri)                                                      AS "scientificNameID",
                          nt.name                                                                                   AS "nameType",

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
	                          END                                                                                   AS "taxonomicStatus",


                          CASE
	                          WHEN ns.rdf_id !~ '(legitimate|default|available)' THEN ns.name
	                          END                                                                                   AS "nomenclaturalStatus",
                          CASE
	                          WHEN nt.autonym THEN NULL::text
	                          ELSE regexp_replace(
			                          "substring"((n.full_name_html)::text, '<authors>(.*)</authors>'::text),
			                          '<[^>]*>'::text,
			                          ''::text, 'g'::text)
	                          END                                                                                   AS "scientificNameAuthorship",
                          CASE
	                          WHEN (nt.cultivar = true) THEN n.name_element
	                          ELSE NULL::character varying
	                          END                                                                                   AS "cultivarEpithet",
                          nt.autonym,
                          nt.hybrid,
                          nt.cultivar,
                          nt.formula,
                          nt.scientific,
                          ns.nom_inval                                                                              AS "nomInval",
                          ns.nom_illeg                                                                              AS "nomIlleg",
                          COALESCE(primary_ref.citation, 'unknown'::character varying)                              AS "namePublishedIn",
                          primary_ref.id                                                                            AS "namePublishedInID",
                          COALESCE(substr(primary_ref.iso_publication_date, 1, 4),
                                   primary_ref.year::text)::INTEGER                                                 AS "namePublishedInYear",
                          primary_it.name                                                                           AS "nameInstanceType",
                          mapper_host.value || primary_inst.uri::text                                               AS "nameAccordingtoID",
                          primary_auth.name || CASE
	                                               WHEN coalesce(primary_ref.iso_publication_date, primary_ref.year::text) is not null
		                                               THEN
				                                               ' (' ||
				                                               coalesce(primary_ref.iso_publication_date, primary_ref.year::text) ||
				                                               ')'
	                                              END                                                    AS "nameAccordingto",
                          basionym.full_name                                                                        AS "originalNameUsage",
                          CASE
	                          WHEN basionym_inst.id IS NOT NULL
		                          THEN mapper_host.value || basionym_inst.id::text
	                          END                                                                         AS "originalNameUsageID",
                          COALESCE(substr(basionym_ref.iso_publication_date, 1, 4), basionym_ref.year::text)
                                                                                                                    AS "originalNameUsageYear",
                          CASE
	                          WHEN nt.autonym = true THEN parent_name.full_name
	                          ELSE (SELECT string_agg(regexp_replace((key1.rdf_id || ': ' || note.value)::text,
	                                                                 '[\r\n]+'::text, ' '::text, 'g'::text),
	                                                  '; '::text) AS string_agg
	                                FROM instance_note note
		                                     JOIN instance_note_key key1
		                                          ON key1.id = note.instance_note_key_id AND
		                                             key1.rdf_id ~* 'type$'
	                                WHERE note.instance_id in (primary_inst.id, basionym_inst.cites_id)
	                          )
	                          END                                                                                   AS "typeCitation",

                          COALESCE((SELECT find_tree_rank.name_element
                                    FROM find_tree_rank(coalesce(tve.element_link, tve2.element_link), (select sort_order from name_rank where rdf_id ~ '(regnum|kingdom)')) find_tree_rank(name_element, rank, sort_order)),
                                   CASE
	                                   WHEN code.value = 'ICN' THEN 'Plantae'
	                                   END)                                                               AS kingdom,


                          COALESCE((SELECT find_tree_rank.name_element
                                    FROM find_tree_rank(coalesce(tve.element_link, tve2.element_link), (select sort_order from name_rank where rdf_id ~ '(^family|^familia)')) find_tree_rank(name_element, rank, sort_order)),
                                   family_name.name_element)                                                        AS family,

                          (SELECT find_rank.name_element
                           FROM find_rank(n.id, (select sort_order from name_rank where rdf_id = 'genus')) find_rank(name_element, rank, sort_order))                     AS "genericName",
                          (SELECT find_rank.name_element
                           FROM find_rank(n.id, (select sort_order from name_rank where rdf_id = 'species')) find_rank(name_element, rank, sort_order))                     AS "specificEpithet",
                          (SELECT find_rank.name_element
                           FROM find_rank(n.id, (select sort_order from name_rank where rdf_id = 'subspecies')) find_rank(name_element, rank, sort_order))                     AS "infraspecificEpithet",
                          rank.name                                                                                 AS "taxonRank",
                          rank.sort_order                                                                           AS "taxonRankSortOrder",
                          rank.abbrev                                                                               AS "taxonRankAbbreviation",
                          first_hybrid_parent.full_name                                                             AS "firstHybridParentName",
                          ((mapper_host.value)::text || first_hybrid_parent.uri)                                    AS "firstHybridParentNameID",
                          second_hybrid_parent.full_name                                                            AS "secondHybridParentName",
                          ((mapper_host.value)::text || second_hybrid_parent.uri)                                   AS "secondHybridParentNameID",
                          n.created_at                                                                              AS created,
                          n.updated_at                                                                              AS modified,
                          COALESCE(code.value, 'ICN'::character varying)::text                                      AS "nomenclaturalCode",
                          dataset.value                                                                             AS "datasetName",
                          'https://creativecommons.org/licenses/by/3.0/'::text                                      AS license,
                          ((mapper_host.value)::text || n.uri)                                                      AS "ccAttributionIRI"
FROM name n
	     JOIN name_type nt ON n.name_type_id = nt.id
	     JOIN name_status ns ON n.name_status_id = ns.id
	     JOIN name_rank rank ON n.name_rank_id = rank.id
	     LEFT JOIN name parent_name ON n.parent_id = parent_name.id
	     LEFT JOIN name family_name ON n.family_id = family_name.id
	     LEFT JOIN name first_hybrid_parent
	               ON n.parent_id = first_hybrid_parent.id AND nt.hybrid
	     LEFT JOIN name second_hybrid_parent
	               ON n.second_parent_id = second_hybrid_parent.id AND nt.hybrid
	     LEFT JOIN instance primary_inst
	       JOIN instance_type primary_it ON primary_it.id = primary_inst.instance_type_id AND primary_it.primary_instance
	       JOIN reference primary_ref ON primary_inst.reference_id = primary_ref.id
	       Join author primary_auth ON primary_ref.author_id = primary_auth.id
	       LEFT JOIN instance basionym_rel
	        JOIN instance_type bt ON bt.id = basionym_rel.instance_type_id AND bt.rdf_id = 'basionym'
	        JOIN instance basionym_inst on basionym_rel.cites_id = basionym_inst.id
	          JOIN reference basionym_ref ON basionym_inst.reference_id = basionym_ref.id
	          JOIN name basionym ON basionym.id = basionym_inst.name_id
	       ON basionym_rel.cited_by_id = primary_inst.id
	     ON primary_inst.name_id = n.id
	     LEFT JOIN shard_config mapper_host ON mapper_host.name::text = 'mapper host'::text
	     LEFT JOIN shard_config dataset ON dataset.name::text = 'name label'::text
	     LEFT JOIN shard_config code ON code.name::text = 'nomenclatural code'::text
	     LEFT JOIN tree_element te
	          JOIN tree_version_element tve ON te.id = tve.tree_element_id
	          JOIN tree t ON tve.tree_version_id = t.current_tree_version_id AND t.accepted_tree
	     ON te.name_id = n.id
	     LEFT JOIN instance s
	        JOIN tree_element te2 on te2.instance_id = s.cited_by_id
	        JOIN tree_version_element tve2 ON te2.id = tve2.tree_element_id
	        JOIN tree t2 ON tve2.tree_version_id = t2.current_tree_version_id AND t2.accepted_tree
	     ON s.name_id = n.id -- and te.name_id is NULL

WHERE EXISTS(SELECT 1
             FROM instance
             WHERE instance.name_id = n.id
	)
  and nt.rdf_id !~ '(common|vernacular)'
  -- and n.name_path !~ '^C[^P]/*'
ORDER BY n.id, "namePublishedInYear", "originalNameUsageYear"
;

