-- name_usage_v.sql
-- NSL-4380:     A new view USAGE_V to deliver a name usage object
-- referenced by: name_v


-- a listing of instances
drop view if exists NAME_USAGE_V;
create view NAME_USAGE_V
    -- columns
	--  (
	--  id, identifier, name_id, instance_type_id, reference_id, bhl_url, usageType,
	--  author_id, parent_id, Name_Usage_Label, full_name, citation, iso_publication_date,
	--  micro_Reference, verbatim_Name_String, type_citation, cited_by_id, cites_id,
	--  standalone, relationship, nomenclatural, taxonomic, misapplied, nsl_shard
	--  )
AS SELECT *
 FROM (SELECT i.id,
              ((host.value)::text || i.uri)                                as identifier,
              i.name_id , -- > taxonName
              i.instance_type_id, -- > usageType
              i.reference_id ,  -- > accordingTo,
              i.bhl_url,
              -- [todo] as uri host/path/rdf_id
              it.rdf_id                                                    as usage_type ,
              r.author_id,
              i.parent_id /*parent_name_usage*/,

              n.full_name || ' sensu. ' || a.name || ' (' || r.year || ')' as Name_Usage_Label,
              n.full_name, -- maybe not

              r.citation,
              r.iso_publication_date,
              i.page                                                       as micro_Reference,
              i.verbatim_Name_String,

              (SELECT string_agg(regexp_replace(
		                                 (key1.rdf_id || ': ' || note.value)::text,
		                                 '[\r\n]+'::text, ' '::text, 'g'::text),
                                 '; '::text) AS string_agg
                     FROM instance_note note
	                    JOIN instance_note_key key1
	                         ON key1.id = note.instance_note_key_id AND
	                            key1.rdf_id ~* 'type$'
                      WHERE note.instance_id = i.id
              )
                                                                           AS type_citation,

              i.cited_by_id, -- > acceptedNameUsage
              i.cites_id,

              it.standalone,
              it.relationship,
              it.nomenclatural,
              it.taxonomic,
              it.misapplied,

              p.rdf_id                                                     as nsl_shard /*cast as uri*/

	       /*notes: [TaxonomicNameUsageNote]*/
	       /*acceptedNameUsageFor: [TaxonomicNameUsage]*/
	       /*children: [TaxonomicNameUsage]*/
	       /*classification: [TaxonomicNameUsage]*/
	       /*branch: [TreeNode]*/
	       /*distribution: [Distribution]*/
	       /*relationshipUsages: [RelationshipUsage]*/
	       /*heterotypicSynonymUsages: [RelationshipUsage]*/
	       /*homotypicSynonymUsages: [RelationshipUsage]*/
	       /*misapplicationUsages: [RelationshipUsage]*/

       from public.instance i
	            join public.namespace p
	                 on i.namespace_id = p.id
	            join public.instance_type it on i.instance_type_id = it.id
	                                           -- and standalone
	            join public.name n on i.name_id = n.id
	            join public.reference r
	            join public.author a on r.author_id = a.id
	                 on i.reference_id = r.id
	            join public.shard_config host on host.name = 'mapper host'
       ) nu
;