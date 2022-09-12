-- Translate the granular booleans from dist_granular_booleans_v into
-- meaningful general booleans like "mainland_unqualified_native".

-- Note: mainland might be better expressed as continental because it includes
-- tasmania.
--
-- Depends on dist_granular_booleans_v.
--
--


drop view if exists dist_native_taxa_v;

create view dist_native_taxa_v 
as
select *, 
       (act_unqualified_native or nsw_unqualified_native or 
        nt_unqualified_native or qld_unqualified_native or
        sa_unqualified_native or tas_unqualified_native or
        vic_unqualified_native or wa_unqualified_native)              mainland_unqualified_native,
        (ar_unqualified_native or cai_unqualified_native or 
        chi_unqualified_native or coi_unqualified_native or
        csi_unqualified_native or hi_unqualified_native or
        lhi_unqualified_native or mdi_unqualified_native or
        mi_unqualified_native or ni_unqualified_native )              island_unqualified_native,
       (act_naturalised or nsw_naturalised or 
        nt_naturalised or qld_naturalised or
        sa_naturalised or tas_naturalised or
        vic_naturalised or wa_naturalised)                            mainland_naturalised,
       (act_doubtfully_naturalised or nsw_doubtfully_naturalised or 
        nt_doubtfully_naturalised or qld_doubtfully_naturalised or
        sa_doubtfully_naturalised or tas_doubtfully_naturalised or
        vic_doubtfully_naturalised or wa_doubtfully_naturalised)      mainland_doubtfully_naturalised,
        (ar_naturalised or cai_naturalised or 
        chi_naturalised or coi_naturalised or
        csi_naturalised or hi_naturalised or
        lhi_naturalised or mdi_naturalised or
        mi_naturalised or ni_naturalised )                         island_naturalised,
        (ar_doubtfully_naturalised or cai_doubtfully_naturalised or 
        chi_doubtfully_naturalised or coi_doubtfully_naturalised or
        csi_doubtfully_naturalised or hi_doubtfully_naturalised or
        lhi_doubtfully_naturalised or mdi_doubtfully_naturalised or
        mi_doubtfully_naturalised or ni_doubtfully_naturalised )      island_doubtfully_naturalised,
       (act_native_and_naturalised or nsw_native_and_naturalised or 
        nt_native_and_naturalised or qld_native_and_naturalised or
        sa_native_and_naturalised or tas_native_and_naturalised or
        vic_native_and_naturalised or wa_native_and_naturalised)              mainland_native_and_naturalised,
        (ar_native_and_naturalised or cai_native_and_naturalised or 
        chi_native_and_naturalised or coi_native_and_naturalised or
        csi_native_and_naturalised or hi_native_and_naturalised or
        lhi_native_and_naturalised or mdi_native_and_naturalised or
        mi_native_and_naturalised or ni_native_and_naturalised )              island_native_and_naturalised,
        (ar_native_and_doubtfully_naturalised or cai_native_and_doubtfully_naturalised or 
        chi_native_and_doubtfully_naturalised or coi_native_and_doubtfully_naturalised or
        csi_native_and_doubtfully_naturalised or hi_native_and_doubtfully_naturalised or
        lhi_native_and_doubtfully_naturalised or mdi_native_and_doubtfully_naturalised or
        mi_native_and_doubtfully_naturalised or ni_native_and_doubtfully_naturalised )       island_native_and_doubtfully_naturalised,
       (act_native_and_doubtfully_naturalised or nsw_native_and_doubtfully_naturalised or 
        nt_native_and_doubtfully_naturalised or qld_native_and_doubtfully_naturalised or
        sa_native_and_doubtfully_naturalised or tas_native_and_doubtfully_naturalised or
        vic_native_and_doubtfully_naturalised or wa_native_and_doubtfully_naturalised)              mainland_native_and_doubtfully_naturalised,
       (act_native_and_naturalised_and_uncertain_origin or nsw_native_and_naturalised_and_uncertain_origin or 
        nt_native_and_naturalised_and_uncertain_origin or qld_native_and_naturalised_and_uncertain_origin or
        sa_native_and_naturalised_and_uncertain_origin or tas_native_and_naturalised_and_uncertain_origin or
        vic_native_and_naturalised_and_uncertain_origin or wa_native_and_naturalised_and_uncertain_origin)              mainland_native_and_naturalised_and_uncertain_origin,
        (ar_native_and_naturalised_and_uncertain_origin or cai_native_and_naturalised_and_uncertain_origin or 
        chi_native_and_naturalised_and_uncertain_origin or coi_native_and_naturalised_and_uncertain_origin or
        csi_native_and_naturalised_and_uncertain_origin or hi_native_and_naturalised_and_uncertain_origin or
        lhi_native_and_naturalised_and_uncertain_origin or mdi_native_and_naturalised_and_uncertain_origin or
        mi_native_and_naturalised_and_uncertain_origin or ni_native_and_naturalised_and_uncertain_origin )              island_native_and_naturalised_and_uncertain_origin,
       (act_native_and_doubtfully_naturalised_and_uncertain_origin or nsw_native_and_doubtfully_naturalised_and_uncertain_origin or 
        nt_native_and_doubtfully_naturalised_and_uncertain_origin or qld_native_and_doubtfully_naturalised_and_uncertain_origin or
        sa_native_and_doubtfully_naturalised_and_uncertain_origin or tas_native_and_doubtfully_naturalised_and_uncertain_origin or
        vic_native_and_doubtfully_naturalised_and_uncertain_origin or wa_native_and_doubtfully_naturalised_and_uncertain_origin)              mainland_native_and_doubtfully_naturalised_and_uncertain_origin,
        (ar_native_and_doubtfully_naturalised_and_uncertain_origin or cai_native_and_doubtfully_naturalised_and_uncertain_origin or 
        chi_native_and_doubtfully_naturalised_and_uncertain_origin or coi_native_and_doubtfully_naturalised_and_uncertain_origin or
        csi_native_and_doubtfully_naturalised_and_uncertain_origin or hi_native_and_doubtfully_naturalised_and_uncertain_origin or
        lhi_native_and_doubtfully_naturalised_and_uncertain_origin or mdi_native_and_doubtfully_naturalised_and_uncertain_origin or
        mi_native_and_doubtfully_naturalised_and_uncertain_origin or ni_native_and_doubtfully_naturalised_and_uncertain_origin )              island_native_and_doubtfully_naturalised_and_uncertain_origin,
       (act_uncertain_origin or nsw_uncertain_origin or 
        nt_uncertain_origin or qld_uncertain_origin or
        sa_uncertain_origin or tas_uncertain_origin or
        vic_uncertain_origin or wa_uncertain_origin)              mainland_uncertain_origin,
        (ar_uncertain_origin or cai_uncertain_origin or 
        chi_uncertain_origin or coi_uncertain_origin or
        csi_uncertain_origin or hi_uncertain_origin or
        lhi_uncertain_origin or mdi_uncertain_origin or
        mi_uncertain_origin or ni_uncertain_origin )              island_uncertain_origin,
       (act_formerly_naturalised or nsw_formerly_naturalised or 
        nt_formerly_naturalised or qld_formerly_naturalised or
        sa_formerly_naturalised or tas_formerly_naturalised or
        vic_formerly_naturalised or wa_formerly_naturalised)      mainland_formerly_naturalised,
        (ar_formerly_naturalised or cai_formerly_naturalised or 
        chi_formerly_naturalised or coi_formerly_naturalised or
        csi_formerly_naturalised or hi_formerly_naturalised or
        lhi_formerly_naturalised or mdi_formerly_naturalised or
        mi_formerly_naturalised or ni_formerly_naturalised )      island_formerly_naturalised,
       (act_native_and_formerly_naturalised or nsw_native_and_formerly_naturalised or 
        nt_native_and_formerly_naturalised or qld_native_and_formerly_naturalised or
        sa_native_and_formerly_naturalised or tas_native_and_formerly_naturalised or
        vic_native_and_formerly_naturalised or wa_native_and_formerly_naturalised)              mainland_native_and_formerly_naturalised,
        (ar_native_and_formerly_naturalised or cai_native_and_formerly_naturalised or 
        chi_native_and_formerly_naturalised or coi_native_and_formerly_naturalised or
        csi_native_and_formerly_naturalised or hi_native_and_formerly_naturalised or
        lhi_native_and_formerly_naturalised or mdi_native_and_formerly_naturalised or
        mi_native_and_formerly_naturalised or ni_native_and_formerly_naturalised )              island_native_and_formerly_naturalised,
       (act_presumed_extinct or nsw_presumed_extinct or 
        nt_presumed_extinct or qld_presumed_extinct or
        sa_presumed_extinct or tas_presumed_extinct or
        vic_presumed_extinct or wa_presumed_extinct)              mainland_presumed_extinct,
        (ar_presumed_extinct or cai_presumed_extinct or 
        chi_presumed_extinct or coi_presumed_extinct or
        csi_presumed_extinct or hi_presumed_extinct or
        lhi_presumed_extinct or mdi_presumed_extinct or
        mi_presumed_extinct or ni_presumed_extinct )              island_presumed_extinct
  from dist_granular_booleans_v
 where taxonomic_status = 'accepted'
 ;


