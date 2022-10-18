#Views for NSL exports

Darwin Core views:

 * dwc_name_view.sql and dwc_taxon_view.sql  

 * views based on name_mv and taxon_mv (../materialized-views), respectively, and must be replaced if these materialized views are rebuilt.

GraphQL views:

 * current_scheme_v.sql

 * BDR-B graphQL views to produce base JSON for the JSON-LD transformation.

taxon_vew and name view are added as simple views on name_mv and taxon_mv.

 * Initially:
 * name_view = dwc_name_v + name_mv.name_id
 * taxon_view = dwc_name_view