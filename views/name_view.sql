/* name_view.sql */
/* NSL-4186: Recreate NAME_VIEW as a simple view on NAME_MV (= DWC_NAME_V + name_id)*/

drop materialized view if exists name_view;
drop view if exists name_view cascade;
create view name_view
			(
			 name_id, "scientificNameID", "nameType",
			 "scientificName", "scientificNameHTML", "canonicalName", "canonicalNameHTML", "nameElement",
			 "nomenclaturalStatus", "scientificNameAuthorship",
			 autonym, hybrid, cultivar, formula, scientific, "nomInval", "nomIlleg",
			 "namePublishedIn", "namePublishedInID","namePublishedInYear", "nameInstanceType",
			 "nameAccordingToID", "nameAccordingTo", "originalNameUsage", "originalNameUsageID",
			 "originalNameUsageYear",
			 "typeCitation", kingdom, family, "genericName", "specificEpithet", "infraspecificEpithet", "cultivarEpithet",
			 "taxonRank", "taxonRankSortOrder", "taxonRankAbbreviation", "firstHybridParentName", "firstHybridParentNameID",
			 "secondHybridParentName",
			 "secondHybridParentNameID", created, modified, "nomenclaturalCode",  "datasetName",
			 "taxonomicStatus", "statusAccordingTo",
			 license, "ccAttributionIRI"
				)
AS
SELECT
	name_id, scientific_name_id, name_type,
	scientific_name, scientific_name_html, canonical_name, canonical_name_html, name_element,
	CASE
		WHEN nomenclatural_status !~ '(legitimate|default|available)' THEN nomenclatural_status
		END ,
	scientific_name_authorship,
	autonym, hybrid, cultivar, formula,
	scientific, nom_inval, nom_illeg, name_published_in, name_published_in_id,name_published_in_year, name_instance_type,
	name_according_to_id, name_according_to, original_name_usage, original_name_usage_id,
	original_name_usage_year,
	type_citation, kingdom, family, generic_name, specific_epithet, infraspecific_epithet, cultivar_epithet,
	taxon_rank, taxon_rank_sort_order, taxon_rank_abbreviation, first_hybrid_parent_name, first_hybrid_parent_name_id,
	second_hybrid_parent_name,
	second_hybrid_parent_name_id, created, modified, nomenclatural_code,  dataset_name,
	taxonomic_status, status_according_to,
	license, cc_attribution_iri
FROM NAME_MV
;

COMMENT ON VIEW NAME_VIEW is 'Based on NAME_MV, a camelCase listing of a shard''s scientific_names with "status_according_to" the current "accepted_tree", using Darwin_Core semantics where available';
