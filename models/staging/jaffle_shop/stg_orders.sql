select
    orders.id as order_id,
    orders.user_id as customer_id,
    orders.order_date as order_placed_at,
    orders.status as order_status,
    _etl_loaded_at

from {{ source("jaffle_shop", "orders") }}
