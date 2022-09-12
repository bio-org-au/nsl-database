/* taxon_mv.sql */
/* NSL-4180   Create TAXON_MV based on the existing TAXON_VIEW using camelCase */
/* materialized snake_case view to support exports of a shard taxonomy using the current version of the default tree*/
/* Builds taxon_mv and dependent views dwc_taxon_v and ( soon, taxon_view) */
/* ghw 20220316  based on "taxon_view" */
/* ghw 20220426  separate taxon_mv into accepted_usage and cited_usage */

drop materialized view if exists taxon_mv cascade;

create materialized view taxon_mv
			(taxon_id, name_type, accepted_name_usage_id, accepted_name_usage, nomenclatural_status,
			 nom_illeg, nom_inval,
			 taxonomic_status, pro_parte, scientific_name, scientific_name_id, canonical_name,
			 scientific_name_authorship, parent_name_usage_id, taxon_rank, taxon_rank_sort_order, kingdom,
			 class, subclass, family,  taxon_concept_id, name_according_to,
			 name_according_to_id, taxon_remarks, taxon_distribution, higher_classification,
			 first_hybrid_parent_name, first_hybrid_parent_name_id, second_hybrid_parent_name,
			 second_hybrid_parent_name_id, nomenclatural_code, created, modified, dataset_name, dataset_id,
			 license, cc_attribution_iri,
			 tree_version_id, tree_element_id, instance_id, name_id, homotypic, heterotypic,
			 misapplied, relationship, synonym, excluded_name, accepted, accepted_id, rank_rdf_id,
			 name_space, tree_description, tree_label)
AS
SELECT (tree.host_name || '/' || syn_inst.uri)                           AS taxon_id,
       syn_nt.name                                                       AS name_type,
       (tree.host_name || tve.taxon_link)                                AS accepted_name_usage_id,
       acc_name.full_name                                                AS accepted_name_usage,
       CASE
	       WHEN syn_ns.rdf_id !~ 'default' THEN syn_ns.name
       END                                                           AS nomenclatural_status,
       syn_ns.nom_illeg,
       syn_ns.nom_inval,
       syn_it.name                                                       AS taxonomic_status,
       syn_it.pro_parte                                                  AS pro_parte,
       syn_name.full_name                                                AS scientific_name,
       (tree.host_name || '/' || syn_name.uri)                           AS scientific_name_id,
       syn_name.simple_name                                              AS canonical_name,
       CASE
           WHEN ng.rdf_id = 'zoological' THEN (select abbrev from author where id = syn_name.author_id)
	       WHEN syn_nt.autonym THEN NULL::text
	       ELSE regexp_replace(
			       substring((syn_name.full_name_html)::text, '<authors>(.*)</authors>'::text),
			       '<[^>]*>'::text, ''::text, 'g'::text)
       END                                                           AS scientific_name_authorship,
       NULL::text                                                        AS parent_name_usage_id,
       syn_rank.name                                                     AS taxon_rank,
       syn_rank.sort_order                                               AS taxon_rank_sort_order,
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
       (tree.host_name || '/' || syn_inst.uri)                           AS taxon_concept_id,
       syn_ref.citation                                                  AS name_according_to,
       ((((tree.host_name || '/reference/') || p.value) || '/') ||
        syn_ref.id)                                                      AS name_according_to_id,

       NULL::text                                                        AS taxon_remarks,
       NULL::text                                                        AS taxon_distribution,
       regexp_replace(tve.name_path, '/'::text, '|'::text, 'g'::text)    AS higher_classification,
       CASE
	       WHEN (firsthybridparent.id IS NOT NULL) THEN firsthybridparent.full_name
	       ELSE NULL::character varying
END                                                           AS first_hybrid_parent_name,
       CASE
	       WHEN (firsthybridparent.id IS NOT NULL)
		       THEN ((tree.host_name || '/'::text) || firsthybridparent.uri)
	       ELSE NULL::text
END                                                           AS first_hybrid_parent_name_id,
       CASE
	       WHEN (secondhybridparent.id IS NOT NULL) THEN secondhybridparent.full_name
	       ELSE NULL::character varying
END                                                           AS second_hybrid_parent_name,
       CASE
	       WHEN (secondhybridparent.id IS NOT NULL)
		       THEN ((tree.host_name || '/'::text) || secondhybridparent.uri)
	       ELSE NULL::text
END                                                           AS second_hybrid_parent_name_id,
       ((SELECT COALESCE((SELECT shard_config.value
                          FROM shard_config
                          WHERE ((shard_config.name)::text = 'nomenclatural code'::text)),
                         'ICN'::character varying) AS coalesce))::text AS nomenclatural_code,
       syn_name.created_at                                               AS created,
       syn_name.updated_at                                               AS modified,
       tree.name                                                         AS dataset_name,
       tree.host_name || '/tree/' || tree.current_tree_version_id        AS dataset_id,
       'http://creativecommons.org/licenses/by/3.0/'::text               AS license,
       (tree.host_name || '/' || syn_inst.uri)                           AS cc_attribution_iRI,
       /* knitting */
       tree.current_tree_version_id                                      AS tree_version_id,
       te.id                                                             AS tree_element_id,
       syn_inst.id                                              AS instance_id,
       syn_name.id                                                  AS name_id,
       syn_it.nomenclatural       as homotypic,
       syn_it.taxonomic           as heterotypic,
       syn_it.misapplied          as misapplied,
       syn_it.relationship        as relationship,
       syn_it.synonym             as synonym, false as excluded_name, false as accepted,
       tve.taxon_id               as accepted_id,
       syn_rank.rdf_id            as rank_rdf_id,
       name_space.value           as name_space,
       d.value                    as tree_description,
       l.value                    as tree_label
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
	     LEFT JOIN shard_config d ON d.name  = 'tree description'
	     LEFT JOIN shard_config l ON  l.name = 'tree label text'
	     LEFT JOIN shard_config p ON  p.name = 'services path name element'
UNION
SELECT (tree.host_name || tve.taxon_link)                                AS taxon_id,
       acc_nt.name                                                       AS name_type,
       (tree.host_name || tve.taxon_link)                                AS accepted_name_usage_id,
       acc_name.full_name                                                AS accepted_name_usage,
       CASE
	       WHEN acc_ns.rdf_id !~ 'default' THEN acc_ns.name
	       END                                                           AS nomenclatural_status,
       acc_ns.nom_illeg,
       acc_ns.nom_inval,
       CASE
	       WHEN te.excluded THEN 'excluded'::text
	       ELSE 'accepted'::text
	       END                                                           AS taxonomic_status,
       false                                                             AS pro_parte,
       acc_name.full_name                                                AS scientific_name,
       (tree.host_name || '/') || acc_name.uri                     AS scientific_name_id,
       acc_name.simple_name                                              AS canonical_name,
       CASE
	       WHEN ng.rdf_id = 'zoological' THEN (select abbrev from author where id = acc_name.author_id)
	       WHEN acc_nt.autonym THEN NULL::text
	       ELSE regexp_replace(
			       substring((acc_name.full_name_html)::text, '<authors>(.*)</authors>'::text),
			       '<[^>]*>'::text, ''::text, 'g'::text)
	       END                                                           AS scientific_name_authorship,
       nullif((tree.host_name || pve.taxon_link), tree.host_name)        AS parent_name_usage_id,
       te.rank                                                           AS taxon_rank,
       acc_rank.sort_order                                               AS taxon_rank_sort_order,
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
       te.instance_link                                                  AS taxon_concept_id,
       acc_ref.citation                                                  AS name_according_to,
       ((((tree.host_name || '/reference/') || p.value ) || '/') ||
        acc_ref.id)                                                      AS name_according_to_id,
       ((te.profile -> (tree.config ->> 'comment_key'::text)) ->>
        'value'::text)                                                   AS taxon_remarks,
       ((te.profile -> (tree.config ->> 'distribution_key'::text)) ->>
        'value'::text)                                                   AS taxon_distribution,
       regexp_replace(tve.name_path, '/'::text, '|'::text, 'g'::text)    AS higher_classification,
       CASE
	       WHEN (firsthybridparent.id IS NOT NULL) THEN firsthybridparent.full_name
	       ELSE NULL::character varying
	       END                                                           AS first_hybrid_parent_name,
       CASE
	       WHEN (firsthybridparent.id IS NOT NULL)
		       THEN ((tree.host_name || '/'::text) || firsthybridparent.uri)
	       ELSE NULL::text
	       END                                                           AS first_hybrid_parent_name_id,
       CASE
	       WHEN (secondhybridparent.id IS NOT NULL) THEN secondhybridparent.full_name
	       ELSE NULL::character varying
	       END                                                           AS second_hybrid_parent_name,
       CASE
	       WHEN (secondhybridparent.id IS NOT NULL)
		       THEN ((tree.host_name || '/'::text) || secondhybridparent.uri)
	       ELSE NULL::text
	       END                                                           AS second_hybrid_parent_name_id,
       ((SELECT COALESCE((SELECT shard_config.value
                          FROM shard_config
                          WHERE ((shard_config.name)::text = 'nomenclatural code'::text)),
                         'ICN'::character varying) AS coalesce))::text AS nomenclatural_code,
       acc_name.created_at                                               AS created,
       acc_name.updated_at                                               AS modified,
       tree.name                                                         AS dataset_name,
       tree.host_name || '/tree/' || tree.current_tree_version_id        AS dataset_id,
       'http://creativecommons.org/licenses/by/3.0/'::text               AS license,
       (tree.host_name || tve.taxon_link)                                AS cc_attribution_iri,
       tree.current_tree_version_id                                      AS tree_version_id,
       te.id                                                             AS tree_element_id,
       te.instance_id                                              AS instance_id,
       te.name_id                                                  AS name_id,
       null, null, null, false, false,
       false as excluded_name, true as accepted,
       tve.taxon_id               as accepted_id,
       acc_rank.rdf_id            as rank_rdf_id,
       name_space.value           as name_space,
       d.value                    as tree_description,
       l.value                    as tree_label
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
	     LEFT JOIN shard_config d ON d.name  = 'tree description'
	     LEFT JOIN shard_config l ON  l.name = 'tree label text'
	     LEFT JOIN shard_config p ON  p.name = 'services path name element'
 ORDER BY 26
;

create unique index taxon_mv_id_i on taxon_mv (taxon_id, accepted_name_usage_id);
create index taxon_mv_name_id_i on taxon_mv(scientific_name_id);
create index taxon_mv_name_i on taxon_mv(scientific_name);
create index taxon_mv_txid_i on taxon_mv (accepted_id);
create index taxon_mv_anuid_i on taxon_mv (accepted_name_usage_id,relationship,synonym);
create index taxon_mv_version_i on taxon_mv (tree_version_id);

/*
 * for general use ( to list synonyms )
*/
drop view if exists accepted_names_v;
-- create view accepted_names_v as
-- select * from taxon_mv
-- where accepted
-- ;

drop view if exists cited_names_v;
-- create view cited_names_v as
-- select * from taxon_mv
-- where relationship
-- ;

/*
 * for general use ( to list synonyms )
*/
drop view if exists homotypic_synonyms_v cascade;
-- create view homotypic_synonyms_v as
-- select * from cited_names_v where homotypic;
-- ;
drop view if exists orthogrphic_v cascade;
-- create view orthographic_v as
-- select * from cited_names_v where homotypic and taxonomic_status ~* '(misspelling|orthographic)';
-- ;
drop view if exists heterotypic_synonyms_v cascade;
-- create view heterotypic_synonyms_v as
-- select * from cited_names_v where heterotypic;
-- ;
drop view if exists misapplied_names_v cascade;
-- create view misapplied_names_v as
-- select * from cited_names_v where misapplied;
-- ;

comment on materialized view taxon_mv is 'A snake_case listing of the accepted classification for a shard as Darwin_Core taxon records (almost): All taxa and their synonyms.';

comment on column taxon_mv.taxon_id is 'The record identifier (URI): The node ID from the accepted classification for the taxon concept; the Taxon_Name_Usage (relationship instance) for a synonym. For higher taxa it uniquely identifiers the subtended branch.';

comment on column taxon_mv.name_type is 'A categorisation of the name, e.g. scientific, hybrid, cultivar';

comment on column taxon_mv.accepted_name_usage_id is 'For a synonym, the taxon_id in this listing of the accepted concept. Self, for a taxon_record';

comment on column taxon_mv.accepted_name_usage is 'For a synonym, the accepted taxon name in this classification.';

comment on column taxon_mv.nomenclatural_status is 'The nomencultural status of this name. http://rs.gbif.org/vocabulary/gbif/nomenclatural_status.xml';

comment on column taxon_mv.taxonomic_status is 'Is this record accepted, excluded or a synonym of an accepted name.';

comment on column taxon_mv.pro_parte is 'A flag on a synonym for a partial taxonomic relationship with the accepted taxon';

comment on column taxon_mv.scientific_name is 'The full scientific name including authority.';

comment on column taxon_mv.scientific_name_id is 'The identifier (URI) for the scientific name in this shard.';

comment on column taxon_mv.canonical_name is 'The name without authorship.';

comment on column taxon_mv.scientific_name_authorship is 'Authorship of the name.';

comment on column taxon_mv.parent_name_usage_id is 'The identifier ( a URI) in this listing for the parent taxon in the classification.';

comment on column taxon_mv.taxon_rank is 'The taxonomic rank of the scientific_name.';

comment on column taxon_mv.taxon_rank_sort_order is 'A sort order that can be applied to the rank.';

comment on column taxon_mv.kingdom is 'The canonical name of the kingdom in this branch of the classification.';

comment on column taxon_mv.class is 'The canonical name of the class in this branch of the classification.';

comment on column taxon_mv.subclass is 'The canonical name of the subclass in this branch of the classification.';

comment on column taxon_mv.family is 'The canonical name of the family in this branch of the classification.';

comment on column taxon_mv.created is 'Date the record for this concept was created. Format ISO:86 01';

comment on column taxon_mv.modified is 'Date the record for this concept was modified. Format ISO:86 01';

comment on column taxon_mv.dataset_name is 'the Name for this branch of the classification  (tree). e.g. APC, Aus_moss';

comment on column taxon_mv.dataset_id is 'the IRI for this branch of the classification  (tree)';

comment on column taxon_mv.taxon_concept_id is 'The URI for the congruent published concept cited by this record.';

comment on column taxon_mv.name_according_to is 'The reference citation for the congruent concept.';

comment on column taxon_mv.name_according_to_id is 'The identifier (URI) for the reference citation for the congriuent concept.';

comment on column taxon_mv.taxon_remarks is 'Comments made specifically about this taxon in this classification.';

comment on column taxon_mv.taxon_distribution is 'The State or Territory distribution of the taxon.';

comment on column taxon_mv.higher_classification is 'The taxon hierarchy, down to (and including) this taxon, as a list of names separated by a |.';

comment on column taxon_mv.first_hybrid_parent_name is 'The scientific_name for the first hybrid parent. For hybrids.';

comment on column taxon_mv.first_hybrid_parent_name_id is 'The identifier (URI) the scientific_name for the first hybrid parent.';

comment on column taxon_mv.second_hybrid_parent_name is 'The scientific_name for the second hybrid parent. For hybrids.';

comment on column taxon_mv.second_hybrid_parent_name_id is 'The identifier (URI) the scientific_name for the second hybrid parent.';

comment on column taxon_mv.nomenclatural_code is 'The nomenclatural code governing this classification.';

comment on column taxon_mv.nom_inval is 'The scientific_name is invalid';

comment on column taxon_mv.nom_illeg is 'The scientific_name is illegitimate (ICN)';

comment on column taxon_mv.license is 'The license by which this data is being made available.';

comment on column taxon_mv.cc_attribution_iri is 'The attribution to be used when citing this concept.';

