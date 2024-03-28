with
    -- ------  Import CTEs
    customers as (select * from {{ ref("stg_customers") }}),

    orders as (select * from {{ ref("stg_orders") }}),

    payments as (select * from {{ ref("stg_payments") }}),

    -- ------  intermediate CTEs
    order_amounts as (
        select
            orderid as order_id,
            max(created) as payment_finalized_date,
            sum(amount) / 100.0 as total_amount_paid
        from payments
        where status <> 'fail'
        group by 1
    ),

    paid_orders as (
        select
            orders.order_id,
            orders.customer_id,
            orders.order_placed_at,
            orders.order_status,
            order_amounts.total_amount_paid,
            order_amounts.payment_finalized_date,
            customers.customer_first_name,
            customers.customer_last_name
        from orders
        left join order_amounts on orders.order_id = order_amounts.order_id
        left join customers on orders.customer_id = customers.customer_id
    ),

    customer_orders as (
        select
            customers.customer_id,
            min(orders.order_placed_at) as first_order_date,
            max(orders.order_placed_at) as most_recent_order_date,
            count(orders.order_id) as number_of_orders
        from customers
        left join orders on orders.customer_id = customers.customer_id
        group by 1
    ),

    customer_lifetime_values as (

        select p.order_id, sum(t2.total_amount_paid) as customer_lifetime_value
        from paid_orders p
        left join
            paid_orders t2
            on p.customer_id = t2.customer_id
            and p.order_id >= t2.order_id
        group by 1
        order by p.order_id
    ),
    -- ------ final CTE
    final as (

        select
            paid_orders.*,
            row_number() over (order by paid_orders.order_id) as transaction_seq,
            row_number() over (
                partition by customer_id order by paid_orders.order_id
            ) as customer_sales_seq,
            case
                when customer_orders.first_order_date = paid_orders.order_placed_at
                then 'new'
                else 'return'
            end as nvsr,
            customer_lifetime_values.customer_lifetime_value,
            customer_orders.first_order_date as fdos
        from paid_orders
        left join customer_orders using (customer_id)
        left outer join
            customer_lifetime_values
            on customer_lifetime_values.order_id = paid_orders.order_id
        order by order_id
    )

select *
from final
