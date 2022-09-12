#Materialized views supporting data exports

name_mv.sql

* A snake_case listing of a shard''s scientific_names with status according to the current default tree version,using Darwin_Core semantics.
* Has dependent view, dwc_name_v.

taxon_mv.sql

* A snake_case listing of the accepted classification for a shard as Darwin_Core taxon records (almost): All taxa and their synonyms
* Has dependent view, dwc_taxon_v.
