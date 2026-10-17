-- This catalog is available only through the authenticated pet RPC.
create policy pet_catalog_no_direct_access on foamlab_private.pet_items
 for all to anon,authenticated using(false) with check(false);
