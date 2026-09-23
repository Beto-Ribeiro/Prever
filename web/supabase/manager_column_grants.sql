grant insert(shelter_id,name,age,category,contact,entered_on,active),update(name,age,category,contact,entered_on,active) on public.shelter_residents to authenticated;
grant insert(shelter_id,name,category,quantity,target,unit),update(name,category,quantity,target,unit) on public.shelter_inventory to authenticated;
grant insert(shelter_id,inventory_id,target,priority) on public.shelter_requests to authenticated;
grant insert(shelter_id,request_id,donor,quantity) on public.shelter_donations to authenticated;
