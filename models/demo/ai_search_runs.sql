{{ config(
    materialized='table',
    tags=['nested_columns_demo']
) }}

-- Synthetic AI search visibility data: one row per prompt run.
-- Citations and fan-out queries stay on the run as repeated fields (no exploded models),
-- to demo Lightdash's nested and repeated column support.
-- Pseudo-randomness is deterministic: every attribute is a FARM_FINGERPRINT of the run number plus a salt.

with lookups as (

    select
        ['GPT', 'Claude', 'Gemini', 'Perplexity', 'Copilot'] as models,
        [
            'Trail running shoes', 'Waterproof jackets', 'Hiking boots', 'Backpacking tents',
            'Sleeping bags', 'Daypacks', 'Base layers', 'Climbing harnesses'
        ] as topics,
        ['Northpeak', 'Trailhaus', 'Kestrel Outdoor', 'Ridgeline', 'Fernwood', 'Solstice Gear'] as brands,
        -- baseline % of runs in which each brand is mentioned (same order as brands)
        [68, 55, 44, 36, 27, 15] as brand_mention_pct,
        [
            struct('United Kingdom' as country, 'London' as city),
            struct('United Kingdom' as country, 'Manchester' as city),
            struct('United States' as country, 'New York' as city),
            struct('United States' as country, 'San Francisco' as city),
            struct('United States' as country, 'Chicago' as city),
            struct('Germany' as country, 'Berlin' as city),
            struct('France' as country, 'Paris' as city),
            struct('Spain' as country, 'Madrid' as city),
            struct('Netherlands' as country, 'Amsterdam' as city),
            struct('Australia' as country, 'Sydney' as city)
        ] as locations,
        -- weighted pool: domains that appear more often here get cited more often
        [
            struct('wikipedia.org' as domain, 'Reference' as source_type),
            struct('wikipedia.org' as domain, 'Reference' as source_type),
            struct('reddit.com' as domain, 'Community' as source_type),
            struct('reddit.com' as domain, 'Community' as source_type),
            struct('reddit.com' as domain, 'Community' as source_type),
            struct('youtube.com' as domain, 'Video' as source_type),
            struct('youtube.com' as domain, 'Video' as source_type),
            struct('outdoorgearlab.com' as domain, 'Review site' as source_type),
            struct('outdoorgearlab.com' as domain, 'Review site' as source_type),
            struct('trustpilot.com' as domain, 'Review site' as source_type),
            struct('nytimes.com' as domain, 'News' as source_type),
            struct('theguardian.com' as domain, 'News' as source_type),
            struct('rei.com' as domain, 'Retailer' as source_type),
            struct('amazon.com' as domain, 'Retailer' as source_type),
            struct('northpeak.example' as domain, 'Brand owned' as source_type),
            struct('trailhaus.example' as domain, 'Brand owned' as source_type),
            struct('kestreloutdoor.example' as domain, 'Brand owned' as source_type),
            struct('quora.com' as domain, 'Community' as source_type),
            struct('linkedin.com' as domain, 'Social' as source_type),
            struct('instagram.com' as domain, 'Social' as source_type)
        ] as domain_pool

),

seeded as (

    select
        n,
        abs(mod(farm_fingerprint(concat('model-', cast(n as string))), 1000003)) as h_model,
        abs(mod(farm_fingerprint(concat('topic-', cast(n as string))), 1000003)) as h_topic,
        abs(mod(farm_fingerprint(concat('brand-', cast(n as string))), 1000003)) as h_brand,
        abs(mod(farm_fingerprint(concat('mention-', cast(n as string))), 1000003)) as h_mention,
        abs(mod(farm_fingerprint(concat('location-', cast(n as string))), 1000003)) as h_location,
        abs(mod(farm_fingerprint(concat('time-', cast(n as string))), 1000003)) as h_time,
        abs(mod(farm_fingerprint(concat('citations-', cast(n as string))), 1000003)) as h_citations,
        abs(mod(farm_fingerprint(concat('fanout-', cast(n as string))), 1000003)) as h_fanout
    from unnest(generate_array(1, 3000)) as n

),

runs as (

    select
        seeded.*,
        lookups.domain_pool,
        lookups.models[offset(mod(h_model, 5))] as model_name,
        lookups.topics[offset(mod(h_topic, 8))] as prompt_topic,
        lookups.brands[offset(mod(h_brand, 6))] as brand,
        lookups.brands[offset(mod(h_brand + 1 + mod(h_fanout, 5), 6))] as competitor_brand,
        lookups.brand_mention_pct[offset(mod(h_brand, 6))] as mention_pct,
        lookups.locations[offset(mod(h_location, 10))] as location
    from seeded
    cross join lookups

),

shaped as (

    select
        runs.*,
        -- each model has its own citation habits: how many sources it cites...
        case model_name
            when 'Perplexity' then 2 + mod(h_citations, 5)
            when 'Copilot' then mod(h_citations, 7)
            when 'Gemini' then mod(h_citations, 6)
            when 'GPT' then mod(h_citations, 5)
            else mod(h_citations, 4)
        end as citation_count,
        -- ...which source it leans on (offset into domain_pool)...
        case model_name
            when 'Perplexity' then 2   -- reddit.com
            when 'Copilot' then 18     -- linkedin.com
            when 'Gemini' then 5       -- youtube.com
            when 'GPT' then 0          -- wikipedia.org
            else 7                     -- outdoorgearlab.com
        end as favourite_domain_offset,
        -- ...and how many searches it fans out to
        case model_name
            when 'Gemini' then 1 + mod(h_fanout, 4)
            when 'GPT' then mod(h_fanout, 5)
            when 'Perplexity' then mod(h_fanout, 4)
            when 'Copilot' then mod(h_fanout, 3)
            else mod(h_fanout, 2)
        end as fanout_count
    from runs

)

select
    concat('run_', format('%05d', n)) as run_id,
    timestamp_sub(
        timestamp_trunc(current_timestamp(), hour),
        interval mod(h_time, 90 * 24) hour
    ) as run_at,
    model_name,
    prompt_topic,
    brand,
    mod(h_mention, 100) < mention_pct + if(model_name in ('Perplexity', 'Gemini'), 8, 0) as brand_mentioned,
    location,
    array(
        select as struct
            domain_pool[offset(pool_offset)].domain as domain,
            domain_pool[offset(pool_offset)].source_type as source_type,
            position
        from (
            select
                position,
                if(
                    mod(abs(mod(farm_fingerprint(concat('fav-', cast(n as string), '-', cast(position as string))), 1000003)), 10) < 3,
                    favourite_domain_offset,
                    mod(abs(mod(farm_fingerprint(concat('dom-', cast(n as string), '-', cast(position as string))), 1000003)), 20)
                ) as pool_offset
            from unnest(generate_array(1, citation_count)) as position
        )
        order by position
    ) as citations,
    array(
        select
            case mod(h_fanout + query_number, 6)
                when 0 then concat('best ', lower(prompt_topic), ' 2026')
                when 1 then concat(brand, ' ', lower(prompt_topic), ' reviews')
                when 2 then concat(brand, ' vs ', competitor_brand)
                when 3 then concat(lower(prompt_topic), ' reddit')
                when 4 then concat(brand, ' ', lower(prompt_topic), ' price')
                else concat('top rated ', lower(prompt_topic))
            end
        from unnest(generate_array(1, fanout_count)) as query_number
        order by query_number
    ) as fanout_queries
from shaped
