/* common_nbame_export.sql
   -- extract from prod.apni 24 August 2022
   -- ghw
   */
drop view if exists common_name_export;
create view common_name_export
			(common_name_id, common_name, instance_id, citation, scientific_name_id, scientific_name, "datasetName",
			 license, "ccAttributionIRI")
as
SELECT mapper_host.value::text || cn.uri AS common_name_id,
       cn.full_name AS common_name,
       mapper_host.value::text || i.uri AS instance_id,
       r.citation,
       mapper_host.value::text || n.uri AS scientific_name_id,
       n.full_name AS scientific_name,
       dataset.value AS "datasetName",
       'http://creativecommons.org/licenses/by/3.0/'::text AS license,
       mapper_host.value::text || n.uri AS "ccAttributionIRI"
FROM instance i
	     JOIN instance_type it ON i.instance_type_id = it.id
	     JOIN name cn ON i.name_id = cn.id
	     JOIN reference r ON i.reference_id = r.id
	     JOIN instance cbi ON i.cited_by_id = cbi.id
	     JOIN name n ON cbi.name_id = n.id,
     shard_config mapper_host,
     shard_config dataset
WHERE it.rdf_id::text ~ '(common|vernacular)' AND mapper_host.name::text = 'mapper host'::text AND dataset.name::text = 'name label'::text;

alter table common_name_export
	owner to nsl;

grant select on common_name_export to webapni;

grant delete, insert, select, update on common_name_export to nslapp;