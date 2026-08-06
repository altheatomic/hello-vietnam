-- Keep the declared return shape of content_freshness_table_config in sync
-- with the three-column lookup table used to select a content table.
create or replace function public.content_freshness_table_config(
    p_content_type text
)
returns table (table_name text, id_column text)
language plpgsql
immutable
as $$
begin
    return query
    select config.table_name, config.id_column
    from (
        values
            ('place', 'place', 'id_place'),
            ('activity', 'activity', 'id'),
            ('culture', 'culture', 'id'),
            ('local_product', 'local_products', 'id'),
            ('food', 'food', 'id_food')
    ) as config(content_type, table_name, id_column)
    where config.content_type = p_content_type;
end;
$$;
