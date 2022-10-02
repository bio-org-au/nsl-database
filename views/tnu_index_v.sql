/* tnu_index_v.sql */
-- A denormalised instance table with TNU links and Name details
/* ghw 2022-10-19 */

drop view if exists tnu_index_v cascade;

create  view tnu_index_v (
	family, tnu_label, accepted_name_usage, dct_identifier,  taxonomic_status, accepted_name_usage_id, primary_usage_id,
    original_name_usage_id, name_according_to, tnu_publication_date, name_according_to_id,
    scientific_name_id, scientific_name, canonical_name, scientific_name_authorship, taxon_rank, name_published_in_year,
    nomenclatural_status, is_changed_combination, is_primary_usage, is_relationship, is_homotypic_usage, is_heterotypic_usage,
    dataset_name, instance_id, name_id, reference_id, cited_by_id, cites_id, license, higher_classification
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
	         nv.license,
	         higher_classification
	     FROM   instance tnu
	            JOIN instance_type it on it.id = tnu.instance_type_id
	            JOIN name_mv nv
	                on tnu.name_id = nv.name_id
	            JOIN reference ref
	                JOIN author auth on ref.author_id = auth.id
	              ON tnu.reference_id = ref.id
	            LEFT JOIN instance txc
	                 JOIN name_mv tn on tn.name_id = txc.name_id
	             ON txc.id = tnu.cited_by_id

	            LEFT JOIN ( select distinct on (canonical_name) canonical_name, scientific_name, higher_classification from taxon_mv  ) tv
	                       -- on tn.canonical_name = tv.canonical_name
	                       on coalesce(tn.scientific_name,nv.scientific_name) = tv.scientific_name

		          LEFT JOIN shard_config mapper_host ON mapper_host.name::text = 'mapper host'::text
		          LEFT JOIN shard_config dataset ON dataset.name::text = 'name label'::text
		          LEFT JOIN shard_config code ON code.name::text = 'nomenclatural code'::text
		          LEFT JOIN shard_config path on path.name = 'services path name element'::text

ORDER BY
         higher_classification,
         coalesce(tn.scientific_name,nv.scientific_name),
         tnu_publication_date, coalesce(txc.uri, tnu.uri), it.relationship,
         nv.name_published_in_year

;



drop FUNCTION if exists gettnu( text);
CREATE FUNCTION gettnu(tnu_name text) RETURNS SETOF tnu_index_v AS
$$
	/* Returns tnu_index_v rows for names matching (and related by) POSIX expression 'tnu_name'.  */
select *
from (with a as (select * from tnu_index_v where scientific_name ~ tnu_name or accepted_name_usage ~ tnu_name),
           b as (select *
                 from tnu_index_v u
                 where exists(
		                 select 1 from a where u.dct_identifier = a.accepted_name_usage_id
	                 )
	               and scientific_name !~ tnu_name),
           c as (select *
                 from tnu_index_v v
                 where exists(
		                 select 1 from b where name_id = v.name_id
	                 )
	               and (accepted_name_usage !~ tnu_name or is_primary_usage)),
           d as (select *
                 from tnu_index_v w
                 where exists(
		                       select 1 from c where w.dct_identifier = c.accepted_name_usage_id
	                       ))
      select * from a
      union
      select * from b
      union
      select * from c
      union
      select * from d ) tnu
order by higher_classification,
         coalesce(accepted_name_usage, scientific_name),
         tnu_publication_date, coalesce(accepted_name_usage_id, dct_identifier), is_relationship,
         name_published_in_year;

$$ LANGUAGE SQL;

/*
select * from gettnu('^Acacia')
order by higher_classification,
         coalesce(accepted_name_usage,scientific_name),
         tnu_publication_date, coalesce(accepted_name_usage_id, dct_identifier), is_relationship,
         name_published_in_year
;
 */
