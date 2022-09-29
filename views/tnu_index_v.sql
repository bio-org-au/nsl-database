/* tnu_index_v.sql */
-- A denormalised instance table with TNU links and Name details
/* ghw 2022-10-19 */

drop view if exists tnu_index_v cascade;

create view tnu_index_v (
	family, tnu_label, accepted_name_usage, dct_identifier,  taxonomic_status, accepted_name_usage_id, primary_usage_id,
    original_name_usage_id, name_according_to, tnu_publication_date, name_according_to_id,
    scientific_name_id, scientific_name, canonical_name, scientific_name_authorship, taxon_rank, name_published_in_year,
    nomenclatural_status, is_changed_combination, is_primary_usage, is_relationship, is_homotypic_usage, is_heterotypic_usage,
    dataset_name, instance_id, name_id, reference_id, cited_by_id, cites_id, license
	)
AS
	     SELECT
	         nv.family,
	         nv.scientific_name || ' sensu. ' || auth.name || coalesce(' (' || ref.iso_publication_date || ')','') as tnu_Label,
	         tn.scientific_name as accepted_name_usage,
	         ((mapper_host.value)::text || tnu.uri)    AS dct_identifier,
	         it.rdf_id AS taxonomic_status,
	         ((mapper_host.value)::text || txc.uri) as accepted_name_usage_id,
	         nv.name_according_to_id   as primary_usage_id,
	         nv.original_name_usage_id,
	         ref.citation   AS name_according_to,
	         ref.iso_publication_date as tnu_publication_date,
	         mapper_host.value ||'reference/' || path.value || '/' || ref.id  AS name_according_to_id,
	         nv.scientific_name_id,
	         nv.scientific_name,
	         nv.canonical_name,
	         nv.scientific_name_authorship,
	         nv.rank_rdf_id,
	         nv.name_published_in_year,
	         nv.nomenclatural_status,
	         nv.changed_combination,
	         it.primary_instance as is_primary_usage,
	         it.relationship is_relationship_usage,
	         it.nomenclatural as is_homotypic_usage,
	         it.taxonomic as is_heterotypic_usage,
	         nv.dataset_name,
	         tnu.id  AS instance_Id,
	         nv.name_id,
	         ref.id   AS reference_id,
	         tnu.cited_by_id,
	         tnu.cites_id,
	         nv.license
	     FROM   instance tnu
	            JOIN instance_type it on it.id = tnu.instance_type_id
	            JOIN name_mv nv on tnu.name_id = nv.name_id
	            JOIN reference ref
	                JOIN author auth on ref.author_id = auth.id
	              ON tnu.reference_id = ref.id
	            LEFT JOIN instance txc
	                 JOIN name_mv tn on tn.name_id = txc.name_id
	                 LEFT JOIN taxon_mv xv on xv.name_id = txc.name_id
	               on txc.id = tnu.cited_by_id
	            LEFT JOIN taxon_mv tv
	               on tnu.name_id = tv.name_id

		          LEFT JOIN shard_config mapper_host ON mapper_host.name::text = 'mapper host'::text
		          LEFT JOIN shard_config dataset ON dataset.name::text = 'name label'::text
		          LEFT JOIN shard_config code ON code.name::text = 'nomenclatural code'::text
		          LEFT JOIN shard_config path on path.name = 'services path name element'::text

ORDER BY coalesce(xv.higher_classification,tv.higher_classification),
         coalesce(tn.scientific_name,nv.scientific_name),
         tnu_publication_date, coalesce(txc.uri, tnu.uri), it.relationship,
         nv.name_published_in_year
;


