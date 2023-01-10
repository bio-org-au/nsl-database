-- reference_v.sql
-- A standard reference view
--   depends on reference.citation [todo] ? where is this maintained ?


drop view if exists qview.REFERENCE_V;
create view qview.REFERENCE_V
    -- column names
	--	(
	--	reference_id, reference_type, is_published, identifier, title, author_id, author_name, author_role,
	--	citation, volume, year, edition, pages, publication_date, iso_publication_date, publisher,
	--	published_location, uri, short_title, display_title, reference_notes, doi, isbn, issn,
	--	parent_id, ref_author_role_id, ref_type_id, language, tl2, verbatim_author, nsl_shard
	--	)
as
SELECT * FROM (
                SELECT
                      r.id                                                   as reference_id,
                      -- [todo] voc-uri
                      rt.rdf_id                                              as reference_type,
                      published                                              as is_published,
                      host.value || 'reference/' || ns.rdf_id || '/' || r.id as identifier,
                      title,
                      author_id,
                      a.name                                                 as author_name,
                      -- [todo] voc-uri
                      rar.rdf_id                                             as author_role,
                      citation,
                      volume,
                      year,
                      edition,
                      pages,
                      publication_date                                       as publication_date,
                      iso_publication_date,
                      publisher,
                      published_location                                     as published_location,
                      r.uri,
                      abbrev_title                                           as short_title,
                      display_title                                          as display_title,
                      r.notes                                                as reference_notes,
                      doi,
                      isbn,
                      issn,
                      r.parent_id,
                      ref_author_role_id,
                      ref_type_id,
                      l.iso6391code                                          as language,
                      tl2,
                      verbatim_author                                        as verbatim_author,
                      ns.rdf_id                                              as nsl_shard
               from reference r
	                    join author a on r.author_id = a.id
	                    join ref_type rt on r.ref_type_id = rt.id
	                    join ref_author_role rar on r.ref_author_role_id = rar.id
	                    join namespace ns
	                         on r.namespace_id = ns.id
	                    join language l
	                         on r.language_id = l.id
	                    join shard_config host on host.name = 'mapper host'
               where r.duplicate_of_id is null
  ) ref_v
;