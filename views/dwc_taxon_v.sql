/* dwc_taxon_v.sql */
/* NSL-4184  Build DWC_TAXON_V on TAXON_MV using snake case and DWC attribute names */
/* Darwin Core view to export shard taxonomy from the current default tree */

drop view if exists dwc_taxon_view;
drop view if exists dwc_taxon_v cascade;
create view dwc_taxon_v
			("taxonID", "nameType", "acceptedNameUsageID", "acceptedNameUsage", "nomenclaturalStatus",
			    "nomIlleg", "nomInval",
			 "taxonomicStatus", "proParte", "scientificName", "scientificNameID", "canonicalName",
			 "scientificNameAuthorship", "parentNameUsageID", "taxonRank", "taxonRankSortOrder", kingdom,
			 class, subclass, family,  "taxonConceptID", "nameAccordingTo",
			 "nameAccordingToID", "taxonRemarks", "taxonDistribution", "higherClassification",
			 "firstHybridParentName", "firstHybridParentNameID", "secondHybridParentName",
			 "secondHybridParentNameID", "nomenclaturalCode", created, modified, "datasetName", "dataSetID", license, "ccAttributionIRI")
AS
SELECT
	taxon_id, name_type, accepted_name_usage_id, accepted_name_usage,
	CASE
		WHEN nomenclatural_status !~ '(legitimate|default|available)' THEN nomenclatural_status
	 END ,
	nom_illeg, nom_inval,
	taxonomic_status, pro_parte, scientific_name, scientific_name_id, canonical_name,
	scientific_name_authorship, parent_name_usage_id, taxon_rank, taxon_rank_sort_order, kingdom,
	class, subclass, family,  taxon_concept_id, name_according_to,
	name_according_to_id, taxon_remarks, taxon_distribution, higher_classification,
	first_hybrid_parent_name, first_hybrid_parent_name_id, second_hybrid_parent_name,
	second_hybrid_parent_name_id, nomenclatural_code, created, modified, dataset_name, dataset_id, license, cc_attribution_iri
FROM TAXON_MV
;

comment on view dwc_taxon_v is 'Based on TAXON_MV, a camelCase DarwinCore view of the shard''s taxonomy using the current default tree version';


 --  dwc_taxon_v replaces the materialized view taxon_view
 /*
 drop materialized view if exists taxon_view cascade;
 drop view if exists taxon_view;
 create view taxon_view as select * from dwc_taxon_v;

  */