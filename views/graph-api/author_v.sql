-- author_v.sql
-- A standard author view
-- supports:  reference_v
--            name_v

drop view if exists AUTHOR_V;
create view AUTHOR_V as
--   columns
--   (
--     id, identifier, standard_form, see_also,
--     author_name, author_full_name, nsl_shard
--     )
SELECT *
FROM (SELECT a.id                                               as id
           , host.value || 'author/' || p.rdf_id || '/' || a.id as identifier
	         --  , orcid ?
           , abbrev                                             as standard_Form
	       -- [todo] should not be ipni_Id, /* move to generic term for URI for IPNI, ZooBank, Index Fungorum,... */
           , ipni_id                                            as see_also  -- a name for this ? other_id
           , a.name                                             as author_name
           , full_name                                          as author_full_Name
           , p.rdf_id                                           as nsl_shard /* will be URI */
      from author a
	           join namespace p
	                on a.namespace_id = p.id
	           join shard_config host on host.name = 'mapper host'
      where duplicate_of_id is null) auth_v
;
