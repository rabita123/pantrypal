-- PantryPal funnel queries. Run in the Supabase SQL editor (service role).
-- Every query counts DISTINCT installs, so one eager user never skews results.
-- Change the interval in `since` to look at a different window.

-- 1) The main funnel: where do people fall off? ------------------------------
with since as (select now() - interval '30 days' as t),
steps as (
  select install_id,
    bool_or(name = 'app_open')                                    as opened,
    bool_or(name = 'onboarding_step' and props->>'step' = 'fill')  as saw_fill,
    bool_or(name = 'first_food_added')                            as added_food,
    bool_or(name = 'onboarding_completed')                        as finished_onboarding,
    bool_or(name = 'paywall_shown')                               as saw_paywall,
    bool_or(name = 'paywall_plan_selected')                       as chose_plan,
    bool_or(name = 'paywall_cta_tapped')                          as tapped_buy,
    bool_or(name = 'purchase_succeeded')                          as purchased
  from app_events, since where created_at >= since.t
  group by install_id
)
select step, installs,
       round(100.0 * installs / nullif(first_value(installs) over (order by ord), 0), 1) as pct_of_opened,
       round(100.0 * installs / nullif(lag(installs) over (order by ord), 0), 1)          as pct_of_previous_step
from (
  select 1 ord, '1 opened the app'          step, count(*) filter (where opened)               installs from steps union all
  select 2,     '2 reached "fill kitchen"',       count(*) filter (where saw_fill)            from steps union all
  select 3,     '3 added first food',             count(*) filter (where added_food)          from steps union all
  select 4,     '4 finished onboarding',          count(*) filter (where finished_onboarding) from steps union all
  select 5,     '5 saw the paywall',              count(*) filter (where saw_paywall)         from steps union all
  select 6,     '6 picked a plan',                count(*) filter (where chose_plan)          from steps union all
  select 7,     '7 tapped buy',                   count(*) filter (where tapped_buy)          from steps union all
  select 8,     '8 purchased',                    count(*) filter (where purchased)           from steps
) f order by ord;

-- 2) Onboarding: which step loses people? ------------------------------------
select props->>'step' as step, count(distinct install_id) as installs
from app_events where name = 'onboarding_step' and created_at >= now() - interval '30 days'
group by 1 order by installs desc;

-- 3) How do people fill their kitchen, and do they stick with it? ------------
select props->>'method' as method, count(distinct install_id) as installs, sum((props->>'count')::int) as foods
from app_events where name = 'food_added' and created_at >= now() - interval '30 days'
group by 1 order by installs desc;

-- 4) Time to value: minutes from first open to first food added ---------------
select percentile_cont(0.5) within group (order by mins) as median_minutes,
       percentile_cont(0.9) within group (order by mins) as p90_minutes
from (
  select extract(epoch from (min(created_at) filter (where name = 'first_food_added')
                           - min(created_at) filter (where name = 'app_open'))) / 60 as mins
  from app_events group by install_id
) t where mins is not null;

-- 5) Scan quality and speed ----------------------------------------------------
select props->>'kind' as kind,
       count(*) filter (where name = 'scan_started')                          as started,
       count(*) filter (where name = 'scan_completed')                        as completed,
       count(*) filter (where name = 'scan_failed')                           as failed,
       count(*) filter (where name = 'scan_cancelled')                        as cancelled,
       round(avg((props->>'total_ms')::int)       filter (where name = 'scan_completed')) as avg_total_ms,
       round(avg((props->>'first_item_ms')::int)  filter (where name = 'scan_completed')) as avg_first_item_ms,
       round(100.0 * sum((props->>'unsure')::int) filter (where name = 'scan_completed')
             / nullif(sum((props->>'items')::int) filter (where name = 'scan_completed'), 0), 1) as pct_items_unsure
from app_events where name like 'scan\_%' and created_at >= now() - interval '30 days'
group by 1;

-- 6) Of scans that finished, how many results did people actually keep? --------
select props->>'kind' as kind,
       round(100.0 * sum((props->>'added')::int) / nullif(sum((props->>'found')::int), 0), 1) as pct_of_found_kept
from app_events where name = 'scan_confirmed' and created_at >= now() - interval '30 days' group by 1;

-- 7) Paywall: which moment converts, and how long do people look at it? --------
select props->>'reason' as reason,
       count(*) filter (where name = 'paywall_shown')                      as shown,
       count(distinct install_id) filter (where name = 'paywall_shown')    as installs,
       round(avg((props->>'seconds')::int) filter (where name = 'paywall_closed')) as avg_seconds_open,
       count(*) filter (where name = 'paywall_closed' and props->>'premium' = 'true') as converted
from app_events where name in ('paywall_shown', 'paywall_closed') and created_at >= now() - interval '30 days'
group by 1 order by shown desc;

-- 8) Plans: what do people pick and what happens next? --------------------------
select props->>'plan' as plan,
       count(*) filter (where name = 'paywall_plan_selected') as selected,
       count(*) filter (where name = 'paywall_cta_tapped')    as tapped_buy,
       count(*) filter (where name = 'purchase_cancelled')    as cancelled_in_apple_sheet,
       count(*) filter (where name = 'purchase_failed')       as failed,
       count(*) filter (where name = 'purchase_succeeded')    as purchased
from app_events where name like 'paywall\_%' or name like 'purchase\_%'
group by 1 order by tapped_buy desc;

-- 9) Do free limits push people to the paywall? ---------------------------------
select props->>'feature' as limit_hit, count(distinct install_id) as installs
from app_events where name = 'limit_hit' and created_at >= now() - interval '30 days' group by 1;

-- 10) Retention: share of installs still opening the app N days later -----------
select day_index as day, count(distinct install_id) as installs_active,
       round(100.0 * count(distinct install_id) /
             nullif((select count(distinct install_id) from app_events where name = 'app_open'), 0), 1) as pct_of_all_installs
from app_events where name = 'app_open' and day_index in (0, 1, 3, 7, 14, 30)
group by 1 order by 1;

-- 11) Habit loop: do people act on "Use first"? ---------------------------------
select props->>'action' as action, count(*) as taps, count(distinct install_id) as installs
from app_events where name = 'use_first_action' and created_at >= now() - interval '30 days' group by 1;

-- 12) Reminders: permission granted, and do notifications bring people back? -----
select props->>'where' as asked_in, props->>'granted' as granted, count(*) from app_events
where name = 'notification_permission' group by 1, 2 order by 1, 2;
select count(*) as opened_from_notification from app_events where name = 'notification_opened';
