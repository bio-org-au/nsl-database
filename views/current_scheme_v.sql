/* current_scheme_v */
/* create the BDR-B views for skos:ConceptScheme [SHARD] */

--concept_schema

-- [DEPENDS on public.taxon_mv]
-- [TODO] taxonomicStatus vocabulary


/* pre...views needed for prefix selections
   -- they should be in public.shard_config !
   */


drop view if exists bdr_prefix_v cascade;
create view bdr_prefix_v
as
select d.value as tree_description,
       l.value as tree_label,
       t.value as tree_context,
       n.value as name_context
from  public.shard_config c
	 join
      jsonb_each_text('{
       "APNI": "apc",
       "AFD": "afd",
       "Algae": "aal",
       "Lichen": "all",
       "AusMoss": "abl",
       "Fungi": "afl"
      }') t on t.key = c.value
	 join
      jsonb_each_text('{
       "APNI": "apni",
       "AFD": "afdi",
       "Algae": "aani",
       "Lichen": "alni",
       "AusMoss": "abni",
       "Fungi": "afni"
       }' ) n on n.key = c.value
      left join public.shard_config x
         left join public.shard_config d on d.name = x.value||' description'
      on  x.name =  'classification tree key'
	  left join public.shard_config l on l.name = 'tree label text'
  where c.name = 'name space'
;

drop view if exists bdr_labels;
drop view if exists bdr_labels_v;
create view bdr_labels_v as
select
	x.value   as "_id" ,
	jsonb_build_object('@id',x.key ) as "rdfs__subPropertyOf",
	tv.id as tree_version_id

from
	public.tree t
		join public.tree_version tv on tv.id = t.current_tree_version_id
		join
	json_each('{"skosxl:altLabel":"boa:hasVernacularLabel",
      "skosxl:altLabel":"boa:hasHeterotypicLabel",
      "skosxl:altLabel":"boa:hasHomotypicLabel",
      "skosxl:hiddenLabel":"boa:hasMisappliedLabel",
      "skosxl:hiddenLabel":"boa:hasOrthographicLabel",
      "skosxl:hiddenLabel":"boa:hasExcludedLabel",
      "skosxl:altLabel":"boa:hasSynonymicLabel",
      "skosxl:prefLabel":"boa:acceptedLabel",
      "skosxl:prefLabel":"boa:unplacedLabel",
      "skos:altLabel":"boa:canonicalLabel"
    }'
		) x on true
   where t.accepted_tree
;

drop view if exists bdr_context_v;
create view bdr_context_v
as
select
	'http://www.w3.org/1999/02/22-rdf-syntax-ns#' as "rdf",
	'http://prefix.cc/' as "prefix",
	'http://www.w3.org/2011/http#' as "http",
	'http://purl.org/dc/elements/1.1/' as "dc",
	'http://purl.org/dc/terms/' as "dct",
	'http://vocab.getty.edu/ontology#' as "gvp",
	'http://www.w3.org/2004/02/skos/core#' as "skos",
	'http://www.w3.org/2008/05/skos-xl#' as "skosxl",
	'http://www.w3.org/2001/XMLSchema#' as "xsd",
	'http://rs.tdwg.org/ontology/voc/TaxonName#' as "tn",
	'http://www.w3.org/2000/01/rdf-schema#' as "rdfs",
	'http://rs.tdwg.org/dwc/terms/' as "dwc",
	'http://www.w3.org/ns/prov#' as "prov",
	'https://schema.org/' as "sdo",
	'https://purl.org/pav/' as "pav",
	'http://purl.org/dc/terms/'  as "dcterms",
	'http://www.w3.org/2002/07/owl#' as owl,
    --
	'https://linked.data.gov.au/def/nslvoc/' as "boa",
    --
	'https://id.biodiversity.org.au/tree/' as "aunsl",
	'https://id.biodiversity.org.au/tree/apc/' as "apc",
	'https://id.biodiversity.org.au/tree/afd/' as "afd",
	'https://id.biodiversity.org.au/tree/abl/' as "abl",
	'https://id.biodiversity.org.au/tree/aal/' as "aal",
	'https://id.biodiversity.org.au/tree/afl/' as "afl",
	'https://id.biodiversity.org.au/tree/all/' as "all",
     --
	'https://id.biodiversity.org.au/name/apni/' as "apni",
	'https://id.biodiversity.org.au/name/afd/' as "afdi",
	'https://id.biodiversity.org.au/name/lichen/' as "alni",
	'https://id.biodiversity.org.au/name/ausmoss/' as "abni",
	'https://id.biodiversity.org.au/name/algae/' as "aani",
	'https://id.biodiversity.org.au/name/fungi/' as "afni",
    --
	tv.id as tree_version_id
from  public.tree t
	      join public.tree_version tv on tv.id = t.current_tree_version_id
where accepted_tree
;

drop view if exists bdr_sdo_v;
create view bdr_sdo_v
as
select
	'https://linked.data.gov.au/org/nsl' as  "_id",
	'sdo:Organization' as "_type",
	'National Species List' as "sdo__name" ,
	jsonb_build_object('@id', 'https://linked.data.gov.au/org/abrs' ) as "sdo__parentOrganization",
	jsonb_build_object('@type', 'xsd:anyURI', '@value','https://biodiversity.org.au/nsl') as "sdo__url",
	tv.id as tree_version_id
from  public.tree t
	      join public.tree_version tv on tv.id = t.current_tree_version_id
      where t.accepted_tree
;

drop view if exists bdr_graph_v;
create view bdr_graph_v
as
select
	tv.id as tree_version_id
from  public.tree t
	      join public.tree_version tv on tv.id = t.current_tree_version_id
      where accepted_tree
;

drop view if exists bdr_tree_schema_v;
create view bdr_tree_schema_v as
select
		'aunsl:' || c.tree_context as "_id",
		'skos:ConceptScheme' as "_type",
		jsonb_build_object('@language','en', '@value', c.tree_label ) as "skos__prefLabel",
		jsonb_build_object('@language','en', '@value', c.tree_description ) as "skos__definition",
        json_build_object( '@id', c.tree_context||':' || t.current_tree_version_id) as "pav__hasCurrentVersion",
		( select v::jsonb from
		      (
		        select jsonb_agg(
		                       jsonb_build_object( '_id', c.tree_context||':'|| p.id )
		                     ) v
					from (
					      select id from
					        public.tree_version tv
					      where tree_id = t.id
					      and published
					      order by published_at desc
		                  limit 5
					     ) p
			    ) x
		) as "pav__hasVersion",
	   tv.id as tree_version_id  /*silent*/
from public.tree t
	     join public.tree_version tv
	          on t.current_tree_version_id = tv.id
	     left join bdr_prefix_v c on true
where accepted_tree
;

-- select * from bdr_tree_schema_v;

drop view if exists bdr_schema_v;
create view bdr_schema_v as
select
   c.tree_context||':'|| t.current_tree_version_id as "_id",
    'skos:ConceptScheme' as "_type",
   jsonb_build_object('@type','xsd:date', '@value', tv.created_at) as "dct__created",
    json_build_object('@id', 'https://linked.data.gov.au/org/nsl') as "dct__creator",
   jsonb_build_object('@type','xsd:date', '@value', published_at) as "dct__modified",
   json_build_object('@id', 'https://www.linked.data.gov.au/org/nsl') as "dct__publisher",
   jsonb_build_object('@language','en', '@value', c.tree_description ) as "skos__definition",
   jsonb_build_object('@id', c.name_context||':'||te.name_id ) as "skos__hasTopConcept",
   jsonb_build_object('@language','en', '@value', c.tree_label ) as "skos__prefLabel",
   jsonb_build_object('@id', 'aunsl:' || c.tree_context ) as "dcterms__isVersionOf",
   jsonb_build_object('@id', c.tree_context||':'|| t.current_tree_version_id ) as "owl__versionIRI",
   CASE WHEN tv.previous_version_id is not null
        THEN jsonb_build_object('@id', c.tree_context||':' || tv.previous_version_id )
        END as "pav__previousVersion",
      te.id  as top_concept_id, /* silent*/
      tv.id as tree_version_id  /*silent*/
from  public.tree t
      join public.tree_version tv
          join public.tree_version_element tve
                join public.tree_element te on
                    te.id = tve.tree_element_id
              on tve.tree_version_id = tv.id
              and tve.parent_id is null
       on t.current_tree_version_id = tv.id
      left join bdr_prefix_v c on true
      where accepted_tree
;

drop view if exists bdr_top_concept_v;
create view bdr_top_concept_v
as
    select
		c.name_context||':'||tx.name_id as "_id",
		jsonb_build_array('skos:Concept','tn:TaxonName') as "_type",
		tx.scientific_name_id as  "dct__identifier",
		tx.taxon_id as  "dwc__taxonID",
        tx.scientific_name   as  "dwc__scientificName",
		tx.scientific_name_authorship   as "dwc__scientificNameAuthorship",
		tx.nomenclatural_status as  "dwc__nomenclaturalStatus",
		tx.taxon_rank  as "dwc__taxonRank",
        tx.taxonomic_status as  "dwc__taxonomicStatus",
		jsonb_build_object('@language','en', '@value', 'The top taxon name object accepted in this revision of the NSL taxonomy' ) as "skos__definition",
		jsonb_build_object('@id',c.tree_context||':'||tx.tree_version_id ) as  "skos__inScheme",
		tx.scientific_name   as  "skos__prefLabel",
		tx.canonical_name  as "boa__canonicalLabel",
		jsonb_build_object('@id',c.tree_context||':'|| tx.tree_version_id ) as  "skos__topConceptOf",
		( select boa__cites::jsonb from (select jsonb_agg(
				                                        json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
		                                        accepted_name_usage_id
		                                 from  public.taxon_mv sx
		                                 where  sx.relationship and sx.synonym and
			                                 sx.homotypic and sx.taxonomic_status !~* '(misspelling|orthographic)'
		                                 group by  accepted_name_usage_id
		                                ) cited
		  where accepted_name_usage_id = tx.taxon_id
		) as "boa__hasHomotypicLabel",
		( select boa__cites::jsonb from (select jsonb_agg(
				                                        json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
		                                        accepted_name_usage_id
		                                 from  public.taxon_mv sx
		                                 where  sx.relationship and sx.synonym and
			                                 sx.heterotypic
		                                 group by  accepted_name_usage_id
		                                ) cited
		  where accepted_name_usage_id = tx.taxon_id
		) as "boa__hasHeterotypicLabel",
		( select boa__cites::jsonb from (select jsonb_agg(
				                                        json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
		                                        accepted_name_usage_id
		                                 from  public.taxon_mv sx
		                                 where  sx.relationship and sx.synonym and
			                                 sx.homotypic and sx.taxonomic_status ~* '(misspelling|orthographic)'
		                                 group by  accepted_name_usage_id
		                                ) cited
		  where accepted_name_usage_id = tx.taxon_id
		) as "boa__hasOrthographicLabel",
		( select boa__cites::jsonb from (select jsonb_agg(
				                                        json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
		                                        accepted_name_usage_id
		                                 from  public.taxon_mv sx
		                                 where  sx.relationship and sx.misapplied
		                                 group by  accepted_name_usage_id
		                                ) cited
		  where accepted_name_usage_id = tx.taxon_id
		) as "boa__hasMisappliedLabel",
		( select boa__cites::jsonb from (select jsonb_agg(
				                                        json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
		                                        accepted_name_usage_id
		                                 from  public.taxon_mv sx
		                                 where  sx.relationship and sx.synonym and
			                                 not sx.heterotypic and not sx.homotypic and not sx.misapplied
		                                 group by  accepted_name_usage_id
		                                ) cited
		  where accepted_name_usage_id = tx.taxon_id
		) as "boa__hasSynonymicLabel",
		tx.tree_version_id as tree_version_id,
        tx.name_id, tx.taxon_id, tx.higher_classification
from public.taxon_mv tx
	  left join bdr_prefix_v c on true
 where tx.parent_name_usage_id is null and tx.accepted
;

drop view if exists bdr_concept_v;
create view bdr_concept_v
as
select
			c.name_context||':'||tx.name_id as "_id",
			jsonb_build_array('skos:Concept','tn:TaxonName') as "_type",
			tx.scientific_name_id as  "dct__identifier",
			tx.taxon_id as  "dwc__taxonID",
			tx.scientific_name   as  "dwc__scientificName",
			tx.scientific_name_authorship   as "dwc__scientificNameAuthorship",
			tx.nomenclatural_status as  "dwc__nomenclaturalStatus",
			tx.scientific_name   as "skos__prefLabel",
			tx.canonical_name  as "boa__canonicalLabel",
			tx.taxon_rank  as "dwc__taxonRank",
			jsonb_build_object('@id',c.name_context||':'||px.name_id  ) as  "skos__broader",
			jsonb_build_object('@id',c.tree_context||':'|| tx.tree_version_id ) as  "skos__inScheme",
			tx.taxonomic_status as  "dwc__taxonomicStatus",
			jsonb_build_object('@language','en', '@value', 'A taxon name object accepted in this revision of the NSL taxonomy.' ) as "skos__definition",
			( select boa__cites::jsonb from (select jsonb_agg(
					json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
			                                        accepted_name_usage_id
			                                 from  public.taxon_mv sx
			                                 where  sx.relationship and sx.synonym and
			                                        sx.homotypic and sx.taxonomic_status !~* '(misspelling|orthographic)'
			                                 group by  accepted_name_usage_id
			                                ) cited
			  where accepted_name_usage_id = tx.taxon_id
			) as "boa__hasHomotypicLabel",
			( select boa__cites::jsonb from (select jsonb_agg(
					json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
			                                        accepted_name_usage_id
			                                 from  public.taxon_mv sx
			                                 where  sx.relationship and sx.synonym and
				                                 sx.heterotypic
			                                 group by  accepted_name_usage_id
			                                ) cited
			  where accepted_name_usage_id = tx.taxon_id
			) as "boa__hasHeterotypicLabel",
			( select boa__cites::jsonb from (select jsonb_agg(
					json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
			                                        accepted_name_usage_id
			                                 from  public.taxon_mv sx
			                                 where  sx.relationship and sx.synonym and
				                                 sx.homotypic and sx.taxonomic_status ~* '(misspelling|orthographic)'
			                                 group by  accepted_name_usage_id
			                                ) cited
			  where accepted_name_usage_id = tx.taxon_id
			) as "boa__hasOrthographicLabel",
	        ( select boa__cites::jsonb from (select jsonb_agg(
					json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
			                                        accepted_name_usage_id
			                                 from  public.taxon_mv sx
			                                 where  sx.relationship and sx.misapplied
			                                 group by  accepted_name_usage_id
			                                ) cited
			  where accepted_name_usage_id = tx.taxon_id
			) as "boa__hasMisappliedLabel",
			( select boa__cites::jsonb from (select jsonb_agg(
					json_build_object( '@id', c.name_context||':'||sx.name_id )) as boa__cites,
			                                        accepted_name_usage_id
			                                 from  public.taxon_mv sx
			                                 where  sx.relationship and sx.synonym and
				                                 not sx.heterotypic and not sx.homotypic and not sx.misapplied
			                                 group by  accepted_name_usage_id
			                                ) cited
			  where accepted_name_usage_id = tx.taxon_id
			) as "boa__hasSynonymicLabel",
			tx.tree_version_id as tree_version_id,
			tx.name_id, tx.taxon_id, tx.higher_classification
from  public.taxon_mv tx
	      join public.taxon_mv px on px.taxon_id = tx.parent_name_usage_id
	      left join bdr_prefix_v c on true
where tx.accepted and tx.parent_name_usage_id is not null
order by higher_classification
;


/*
 -- if bdr_top_concept is restricted to one branch then constrain bdr_concept with ...
 -- join bdr_top_concept tc on tx.higher_classification ~ tc.higher_classification
 */

drop view if exists bdr_alt_labels;
drop view if exists bdr_alt_labels_v;
create view bdr_alt_labels_v
as
select     distinct on (tx.name_id)
			c.name_context||':'||tx.name_id as "_id",
			jsonb_build_array('skos:Concept', 'skosxl:Label') as "_type",
			tx.scientific_name   as "skos__prefLabel",
			tx.scientific_name_id as  "dct__identifier",
			tx.scientific_name   as  "dwc__scientificName",
			tx.scientific_name_authorship   as "dwc__scientificNameAuthorship",
			tx.nomenclatural_status as  "dwc__nomenclaturalStatus",
			tx.canonical_name  as "boa__canonicalLabel",
			tx.taxon_rank  as "dwc__taxonRank",
			tx.taxonomic_status as  "dwc__taxonomicStatus",
			jsonb_build_object('@language','en', '@value', 'A related name object (synonym, misapplication, etc.) cited in this revision of the NSL taxonomy.' ) as "skos__definition",
			tx.tree_version_id as tree_version_id,
			tx.name_id, tx.accepted_name_usage_id
from  public.taxon_mv tx
	   left join bdr_prefix_v c on true
where  tx.relationship and tx.synonym
;

/* removed from bdr_labels json_each to reduce noise, replace in graph with skosxl:label */
-- "skosxl:Label":"boa:isVernacularLabel",
-- "skosxl:Label":"boa:isHeterotypicLabel",
-- "skosxl:Label":"boa:isMisappliedLabel",
-- "skosxl:Label":"boa:isOrthographicLabel",
-- "skosxl:Label":"boa:isHomotypicLabel"

-- bdr_unplaced_names

drop view if exists bdr_unplaced_v;
create view bdr_unplaced_v
as
select
			c.name_context||':'||mx.name_id as "_id",
			jsonb_build_array('skos:Concept','tn:TaxonName') as "_type",
			mx.taxonomic_status as  "dwc__taxonomicStatus",
			mx.scientific_name   as  "skos__prefLabel",
			mx.scientific_name_id as  "dct__identifier",
			mx.scientific_name   as  "dwc__scientificName",
			mx.scientific_name_authorship   as "dwc__scientificNameAuthorship",
			mx.nomenclatural_status as  "dwc__nomenclaturalStatus",
			mx.canonical_name  as "boa__canonicalLabel",
			mx.taxon_rank  as "dwc__taxonRank",
			jsonb_build_object('@id',c.tree_context||':'|| t.current_tree_version_id ) as  "skos__inScheme",
			jsonb_build_object('@language','en', '@value', 'A published name object unplaced within the NSL taxonomy. Not in this SKOS scheme.' ) as "skos__definition",
			mx.name_id, t.current_tree_version_id as tree_version_id
from public.name_mv mx
          left join public.tree t on accepted_tree
          left join bdr_prefix_v c on true
where not exists (select 1 from public.taxon_mv tx where tx.name_id = mx.name_id)
;

/*
 * bdr_*_labels views are nolonger used.
 * now the basis for in-line queries
 * in bdr*_concept views
 *
drop view if exists bdr_homotypic_labels;
create view bdr_homotypic_labels as
select
	jsonb_strip_nulls(jsonb_build_object('@id', lower(name_space)||':'||name_id )) as "boa__hasHomotypicSynonym",
	accepted_name_usage_id
from homotypic_synonyms_v where taxonomic_status !~* '(misspelling|orthographic)'
;

drop view if exists bdr_orthographic_labels;
create view bdr_orthographic_labels as
select
	jsonb_build_object('@id', lower(name_space)||':'||name_id ) as "boa__hasOrthographicVariant",
	accepted_name_usage_id
from homotypic_synonyms_v where taxonomic_status ~* '(misspelling|orthographic)'
;

drop view if exists bdr_heterotypic_labels;
create view bdr_heterotypic_labels as
select
	jsonb_build_object('@id', lower(name_space)||':'||name_id ) as "boa__hasHeterotypicSynonym",
	accepted_name_usage_id
from heterotypic_synonyms_v;

drop view if exists bdr_misapplied_labels;
create view bdr_misapplied_labels as
select
	jsonb_build_object('@id', lower(name_space)||':'||name_id ) as "boa__hasMisappliedName",
	accepted_name_usage_id
from misapplied_names_v;

 */

 --* end bdr_*_labels */
