/* taxon_view.sql */

/* DEPRECATED in favour of dwc_taxon_v */
/* materialized view to export shard taxonomy using the instance graph */
/* NSL-4152: Include nomInval and nomIIeg in taxon_mv and associated objects */

/*
drop materialized view if exists taxon_view;
create materialized view taxon_view
			("taxonID", "nameType", "acceptedNameUsageID", "acceptedNameUsage", "nomenclaturalStatus",
			    "nomIlleg", "nomInval",
			 "taxonomicStatus", "proParte", "scientificName", "scientificNameID", "canonicalName",
			 "scientificNameAuthorship", "parentNameUsageID", "taxonRank", "taxonRankSortOrder", kingdom,
			 class, subclass, family,  "taxonConceptID", "nameAccordingTo",
			 "nameAccordingToID", "taxonRemarks", "taxonDistribution", "higherClassification",
			 "firstHybridParentName", "firstHybridParentNameID", "secondHybridParentName",
			 "secondHybridParentNameID", "nomenclaturalCode", created, modified, "datasetName", "dataSetID", license, "ccAttributionIRI")
AS
SELECT (tree.host_name || '/' || syn_inst.uri)                           AS "taxonID",
       syn_nt.name                                                       AS "nameType",
       (tree.host_name || tve.taxon_link)                                AS "acceptedNameUsageID",
       acc_name.full_name                                                AS "acceptedNameUsage",
       CASE
	       WHEN syn_ns.rdf_id !~ '(legitimate|default|available)' THEN syn_ns.name
END                                                           AS "nomenclaturalStatus",
       syn_ns.nom_illeg,
       syn_ns.nom_inval,
       syn_it.name                                                       AS "taxonomicStatus",
       syn_it.pro_parte                                                  AS "proParte",
       syn_name.full_name                                                AS "scientificName",
       (tree.host_name || '/' || syn_name.uri)                           AS "scientificNameID",
       syn_name.simple_name                                              AS "canonicalName",
       CASE
           WHEN ng.rdf_id = 'zoological' THEN (select abbrev from author where id = syn_name.author_id)
	       WHEN syn_nt.autonym THEN NULL::text
	       ELSE regexp_replace(
			       "substring"((syn_name.full_name_html)::text, '<authors>(.*)</authors>'::text),
			       '<[^>]*>'::text, ''::text, 'g'::text)
       END                                                           AS "scientificNameAuthorship",
       NULL::text                                                        AS "parentNameUsageID",
       syn_rank.name                                                     AS "taxonRank",
       syn_rank.sort_order                                               AS "taxonRankSortOrder",
       (SELECT find_tree_rank.name_element
        FROM find_tree_rank(tve.element_link, (select sort_order from name_rank where rdf_id ~ '(regnum|kingdom)')) find_tree_rank(name_element, rank, sort_order)
        ORDER BY find_tree_rank.sort_order
        LIMIT 1)                                                         AS kingdom,
       (SELECT find_tree_rank.name_element
        FROM find_tree_rank(tve.element_link, (select sort_order from name_rank where rdf_id ~ '^class')) find_tree_rank(name_element, rank, sort_order)
        ORDER BY find_tree_rank.sort_order
        LIMIT 1)                                                         AS class,
       (SELECT find_tree_rank.name_element
        FROM find_tree_rank(tve.element_link, (select sort_order from name_rank where rdf_id ~ '^subclass')) find_tree_rank(name_element, rank, sort_order)
        ORDER BY find_tree_rank.sort_order
        LIMIT 1)                                                         AS subclass,
       (SELECT find_tree_rank.name_element
        FROM find_tree_rank(tve.element_link, (select sort_order from name_rank where rdf_id ~ '(^familia|^family)')) find_tree_rank(name_element, rank, sort_order)
        ORDER BY find_tree_rank.sort_order
        LIMIT 1)                                                         AS family,
       (tree.host_name || '/' || syn_inst.uri)                           AS "taxonConceptID",
       syn_ref.citation                                                  AS "nameAccordingTo",
       ((((tree.host_name || '/reference/'::text) || lower((name_space.value)::text)) || '/'::text) ||
        syn_ref.id)                                                      AS "nameAccordingToID",

       NULL::text                                                        AS "taxonRemarks",
       NULL::text                                                        AS "taxonDistribution",
       regexp_replace(tve.name_path, '/'::text, '|'::text, 'g'::text)    AS "higherClassification",
       CASE
	       WHEN (firsthybridparent.id IS NOT NULL) THEN firsthybridparent.full_name
	       ELSE NULL::character varying
END                                                           AS "firstHybridParentName",
       CASE
	       WHEN (firsthybridparent.id IS NOT NULL)
		       THEN ((tree.host_name || '/'::text) || firsthybridparent.uri)
	       ELSE NULL::text
END                                                           AS "firstHybridParentNameID",
       CASE
	       WHEN (secondhybridparent.id IS NOT NULL) THEN secondhybridparent.full_name
	       ELSE NULL::character varying
END                                                           AS "secondHybridParentName",
       CASE
	       WHEN (secondhybridparent.id IS NOT NULL)
		       THEN ((tree.host_name || '/'::text) || secondhybridparent.uri)
	       ELSE NULL::text
END                                                           AS "secondHybridParentNameID",
       ((SELECT COALESCE((SELECT shard_config.value
                          FROM shard_config
                          WHERE ((shard_config.name)::text = 'nomenclatural code'::text)),
                         'ICN'::character varying) AS "coalesce"))::text AS "nomenclaturalCode",
       syn_name.created_at                                               AS created,
       syn_name.updated_at                                               AS modified,
       tree.name                                                         AS "datasetName",
       tree.host_name || '/tree/' || tree.current_tree_version_id        AS "dataSetID",
       'http://creativecommons.org/licenses/by/3.0/'::text               AS license,
       (tree.host_name || '/' || syn_inst.uri)                           AS "ccAttributionIRI"
FROM tree_version_element tve
	JOIN tree ON (tve.tree_version_id = tree.current_tree_version_id AND
	               tree.accepted_tree = true)
	JOIN tree_element te ON tve.tree_element_id = te.id
	JOIN instance acc_inst ON te.instance_id = acc_inst.id
	JOIN name acc_name ON te.name_id = acc_name.id
	     JOIN instance syn_inst on ( te.instance_id = syn_inst.cited_by_id and syn_inst.name_id != acc_name.id )
	     JOIN reference syn_ref on syn_inst.reference_id = syn_ref.id
	     JOIN instance_type syn_it on syn_inst.instance_type_id = syn_it.id
									and relationship and ( synonym or misapplied )
									and rdf_id !~* '(isonym|common|vernacular|trade|synonymy|taxonomy)'
	     JOIN name syn_name on syn_inst.name_id = syn_name.id
	     JOIN name_rank syn_rank on syn_name.name_rank_id = syn_rank.id
	     JOIN name_type syn_nt on syn_name.name_type_id = syn_nt.id
              join name_group ng on syn_nt.name_group_id = ng.id
	     JOIN name_status syn_ns on syn_name.name_status_id = syn_ns.id
	     LEFT JOIN name firsthybridparent
	               ON (syn_name.parent_id = firsthybridparent.id AND syn_nt.hybrid)
	     LEFT JOIN name secondhybridparent
	               ON (syn_name.second_parent_id = secondhybridparent.id AND syn_nt.hybrid)
	     LEFT JOIN shard_config name_space ON name_space.name::text = 'name space'::text
UNION
SELECT (tree.host_name || tve.taxon_link)                                AS "taxonID",
       acc_nt.name                                                       AS "nameType",
       (tree.host_name || tve.taxon_link)                                AS "acceptedNameUsageID",
       acc_name.full_name                                                AS "acceptedNameUsage",
       CASE
	       WHEN acc_ns.rdf_id !~ '(legitimate|default|available)' THEN acc_ns.name
	       END                                                           AS "nomenclaturalStatus",
       acc_ns.nom_illeg,
       acc_ns.nom_inval,
       CASE
	       WHEN te.excluded THEN 'excluded'::text
	       ELSE 'accepted'::text
	       END                                                           AS "taxonomicStatus",
       false                                                             AS "proParte",
       acc_name.full_name                                                AS "scientificName",
       (tree.host_name || '/') || acc_name.uri                     AS "scientificNameID",
       acc_name.simple_name                                              AS "canonicalName",
       CASE
	       WHEN ng.rdf_id = 'zoological' THEN (select abbrev from author where id = acc_name.author_id)
	       WHEN acc_nt.autonym THEN NULL::text
	       ELSE regexp_replace(
			       "substring"((acc_name.full_name_html)::text, '<authors>(.*)</authors>'::text),
			       '<[^>]*>'::text, ''::text, 'g'::text)
	       END                                                           AS "scientificNameAuthorship",
       nullif((tree.host_name || pve.taxon_link), tree.host_name)        AS "parentNameUsageID",
       te.rank                                                           AS "taxonRank",
       acc_rank.sort_order                                               AS "taxonRankSortOrder",
       (SELECT find_tree_rank.name_element
        FROM find_tree_rank(tve.element_link, (select sort_order from name_rank where rdf_id ~ '(regnum|kingdom)')) find_tree_rank(name_element, rank, sort_order)
        ORDER BY find_tree_rank.sort_order
        LIMIT 1)                                                         AS kingdom,
       (SELECT find_tree_rank.name_element
        FROM find_tree_rank(tve.element_link, (select sort_order from name_rank where rdf_id ~ '^class')) find_tree_rank(name_element, rank, sort_order)
        ORDER BY find_tree_rank.sort_order
        LIMIT 1)                                                         AS class,
       (SELECT find_tree_rank.name_element
        FROM find_tree_rank(tve.element_link, (select sort_order from name_rank where rdf_id ~ '^subclass')) find_tree_rank(name_element, rank, sort_order)
        ORDER BY find_tree_rank.sort_order
        LIMIT 1)                                                         AS subclass,
       (SELECT find_tree_rank.name_element
        FROM find_tree_rank(tve.element_link, (select sort_order from name_rank where rdf_id ~ '(^family|^familia)')) find_tree_rank(name_element, rank, sort_order)
        ORDER BY find_tree_rank.sort_order
        LIMIT 1)                                                         AS family,
       te.instance_link                                                  AS "taxonConceptID",
       acc_ref.citation                                                  AS "nameAccordingTo",
       ((((tree.host_name || '/reference/'::text) || lower((name_space.value)::text)) || '/'::text) ||
        acc_ref.id)                                                      AS "nameAccordingToID",
       ((te.profile -> (tree.config ->> 'comment_key'::text)) ->>
        'value'::text)                                                   AS "taxonRemarks",
       ((te.profile -> (tree.config ->> 'distribution_key'::text)) ->>
        'value'::text)                                                   AS "taxonDistribution",
       regexp_replace(tve.name_path, '/'::text, '|'::text, 'g'::text)    AS "higherClassification",
       CASE
	       WHEN (firsthybridparent.id IS NOT NULL) THEN firsthybridparent.full_name
	       ELSE NULL::character varying
	       END                                                           AS "firstHybridParentName",
       CASE
	       WHEN (firsthybridparent.id IS NOT NULL)
		       THEN ((tree.host_name || '/'::text) || firsthybridparent.uri)
	       ELSE NULL::text
	       END                                                           AS "firstHybridParentNameID",
       CASE
	       WHEN (secondhybridparent.id IS NOT NULL) THEN secondhybridparent.full_name
	       ELSE NULL::character varying
	       END                                                           AS "secondHybridParentName",
       CASE
	       WHEN (secondhybridparent.id IS NOT NULL)
		       THEN ((tree.host_name || '/'::text) || secondhybridparent.uri)
	       ELSE NULL::text
	       END                                                           AS "secondHybridParentNameID",
       ((SELECT COALESCE((SELECT shard_config.value
                          FROM shard_config
                          WHERE ((shard_config.name)::text = 'nomenclatural code'::text)),
                         'ICN'::character varying) AS "coalesce"))::text AS "nomenclaturalCode",
       acc_name.created_at                                               AS created,
       acc_name.updated_at                                               AS modified,
       tree.name                                                         AS "datasetName",
       tree.host_name || '/tree/' || tree.current_tree_version_id        AS "dataSetID",
       'http://creativecommons.org/licenses/by/3.0/'::text               AS license,
       (tree.host_name || tve.taxon_link)                                AS "ccAttributionIRI"
FROM tree_version_element tve
	     JOIN tree ON (tve.tree_version_id = tree.current_tree_version_id AND
	                   tree.accepted_tree = true)
	     JOIN tree_element te ON tve.tree_element_id = te.id
	     JOIN instance acc_inst ON te.instance_id = acc_inst.id
	     JOIN instance_type acc_it ON acc_inst.instance_type_id = acc_it.id
	     JOIN reference acc_ref ON acc_inst.reference_id = acc_ref.id
	     JOIN name acc_name ON te.name_id = acc_name.id
	     JOIN name_type acc_nt ON acc_name.name_type_id = acc_nt.id
	     join name_group ng on acc_nt.name_group_id = ng.id
	     JOIN name_status acc_ns ON acc_name.name_status_id = acc_ns.id
	     JOIN name_rank acc_rank ON acc_name.name_rank_id = acc_rank.id
	     LEFT JOIN tree_version_element pve on pve.element_link = tve.parent_id
	     LEFT JOIN name firsthybridparent ON (acc_name.parent_id = firsthybridparent.id AND acc_nt.hybrid)
	     LEFT JOIN name secondhybridparent ON (acc_name.second_parent_id = secondhybridparent.id AND acc_nt.hybrid)
	     LEFT JOIN shard_config name_space ON name_space.name::text = 'name space'::text
ORDER BY 27
;


comment on materialized view taxon_view is 'The Taxon View provides a listing of the "accepted" classification for the sharda as Darwin Core taxon records (almost): All taxa and their synonyms.';

comment on column taxon_view."taxonID" is 'The record identifier (URI): The node ID from the "accepted" classification for the taxon concept; the Taxon_Name_Usage (relationship instance) for a synonym. For higher taxa it uniquely identifiers the subtended branch.';

comment on column taxon_view."nameType" is 'A categorisation of the name, e.g. scientific, hybrid, cultivar';

comment on column taxon_view."acceptedNameUsageID" is 'For a synonym, the "taxon_id" in this listing of the accepted concept. Self, for a taxon_record';

comment on column taxon_view."acceptedNameUsage" is 'For a synonym, the accepted taxon name in this classification.';

comment on column taxon_view."nomenclaturalStatus" is 'The nomencultural status of this name. http://rs.gbif.org/vocabulary/gbif/nomenclatural_status.xml';

comment on column taxon_view."taxonomicStatus" is 'Is this record accepted, excluded or a synonym of an accepted name.';

comment on column taxon_view."proParte" is 'A flag on a synonym for a partial taxonomic relationship with the accepted taxon';

comment on column taxon_view."scientificName" is 'The full scientific name including authority.';

comment on column taxon_view."scientificNameID" is 'The identifier (URI) for the scientific name in this shard.';

comment on column taxon_view."canonicalName" is 'The name without authorship.';

comment on column taxon_view."scientificNameAuthorship" is 'Authorship of the name.';

comment on column taxon_view."parentNameUsageID" is 'The identifier ( a URI) in this listing for the parent taxon in the classification.';

comment on column taxon_view."taxonRank" is 'The taxonomic rank of the scientificName.';

comment on column taxon_view."taxonRankSortOrder" is 'A sort order that can be applied to the rank.';

comment on column taxon_view.kingdom is 'The canonical name of the kingdom in this branch of the classification.';

comment on column taxon_view.class is 'The canonical name of the class in this branch of the classification.';

comment on column taxon_view.subclass is 'The canonical name of the subclass in this branch of the classification.';

comment on column taxon_view.family is 'The canonical name of the family in this branch of the classification.';

comment on column taxon_view.created is 'Date the record for this concept was created. Format ISO:86 01';

comment on column taxon_view.modified is 'Date the record for this concept was modified. Format ISO:86 01';

comment on column taxon_view."datasetName" is 'the Name for this ibranch of the classification  (tree). e.g. APC, AusMoss';

comment on column taxon_view."taxonConceptID" is 'The URI for the congruent "published" concept cited by this record.';

comment on column taxon_view."nameAccordingTo" is 'The reference citation for the congruent concept.';

comment on column taxon_view."nameAccordingToID" is 'The identifier (URI) for the reference citation for the congriuent concept.';

comment on column taxon_view."taxonRemarks" is 'Comments made specifically about this taxon in this classification.';

comment on column taxon_view."taxonDistribution" is 'The State or Territory distribution of the taxon.';

comment on column taxon_view."higherClassification" is 'The taxon hierarchy, down to (and including) this taxon, as a list of names separated by a "|".';

comment on column taxon_view."firstHybridParentName" is 'The scientificName for the first hybrid parent. For hybrids.';

comment on column taxon_view."firstHybridParentNameID" is 'The identifier (URI) the scientificName for the first hybrid parent.';

comment on column taxon_view."secondHybridParentName" is 'The scientificName for the second hybrid parent. For hybrids.';

comment on column taxon_view."secondHybridParentNameID" is 'The identifier (URI) the scientificName for the second hybrid parent.';

comment on column taxon_view."nomenclaturalCode" is 'The nomenclatural code governing this classification.';

comment on column taxon_view.license is 'The license by which this data is being made available.';

comment on column taxon_view."ccAttributionIRI" is 'The attribution to be used when citing this concept.';
*/
