-- CFPB Consumer Complaint Database — analysis queries
-- Fintechs (Chime, Block, PayPal, Coinbase) vs. an incumbent bank (Wells Fargo)
-- Run against cfpb.db, table `complaints`, created by 01_clean_cfpb.py


-- Q1. Volume by company
-- The orientation query. Wells Fargo will dominate on raw count because it is
-- far larger — which is exactly why every later query works in shares, not counts.

SELECT
    company,
    segment,
    COUNT(*) AS complaints,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM complaints), 1) AS pct_of_total
FROM complaints
GROUP BY company, segment
ORDER BY complaints DESC;


-- Q2. Top issues overall

SELECT
    issue,
    COUNT(*) AS complaints
FROM complaints
GROUP BY issue
ORDER BY complaints DESC
LIMIT 15;


-- Q3. What each company is complained about — the composition question
-- Two firms can have identical volume and completely different problems.
-- The percent-within-company column is the one that matters.

SELECT
    company,
    issue,
    COUNT(*) AS complaints,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY company),
        1
    ) AS pct_within_company
FROM complaints
GROUP BY company, issue
ORDER BY company, complaints DESC;


-- Q4. Each company's single largest issue
-- Same idea as Q3, ranked and filtered to the top three per company.

WITH ranked AS (
    SELECT
        company,
        issue,
        COUNT(*) AS complaints,
        ROW_NUMBER() OVER (
            PARTITION BY company
            ORDER BY COUNT(*) DESC
        ) AS rank_in_company
    FROM complaints
    GROUP BY company, issue
)
SELECT company, issue, complaints
FROM ranked
WHERE rank_in_company <= 3
ORDER BY company, rank_in_company;


-- Q5. Monthly trend by segment
-- Feeds the dashboard's line chart.

SELECT
    year_month,
    segment,
    COUNT(*) AS complaints
FROM complaints
GROUP BY year_month, segment
ORDER BY year_month, segment;


-- Q6. Month-over-month growth per company
-- LAG pulls the previous month's count onto the current row so the two can be
-- compared without a self-join. NULLIF guards the first month, where the
-- previous value is NULL and division would fail.

WITH monthly AS (
    SELECT
        company,
        year_month,
        COUNT(*) AS complaints
    FROM complaints
    GROUP BY company, year_month
)
SELECT
    company,
    year_month,
    complaints,
    LAG(complaints) OVER (
        PARTITION BY company
        ORDER BY year_month
    ) AS prior_month,
    ROUND(
        100.0 * (complaints - LAG(complaints) OVER (PARTITION BY company ORDER BY year_month))
        / NULLIF(LAG(complaints) OVER (PARTITION BY company ORDER BY year_month), 0),
        1
    ) AS mom_growth_pct
FROM monthly
ORDER BY company, year_month;


-- Q7. Resolution quality — how each company answers
-- Relief rate is the sharpest single comparison in the project: of everything a
-- company was asked about, how often did the consumer actually get something?

SELECT
    company,
    segment,
    COUNT(*) AS complaints,
    ROUND(100.0 * SUM(CASE WHEN company_response LIKE 'Closed with monetary relief%' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_monetary_relief,
    ROUND(100.0 * SUM(CASE WHEN company_response LIKE 'Closed with explanation%' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_explanation_only,
    ROUND(100.0 * SUM(CASE WHEN timely_response = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_timely
FROM complaints
GROUP BY company, segment
ORDER BY pct_monetary_relief DESC;


-- Q8. Fraud and unauthorised-transaction share
-- The hypothesis worth testing: fintechs skew toward fraud and account access,
-- incumbents toward fees and servicing. This isolates the fraud-shaped issues.

SELECT
    company,
    segment,
    COUNT(*) AS complaints,
    SUM(CASE
            WHEN issue LIKE '%fraud%'
              OR issue LIKE '%scam%'
              OR issue LIKE '%unauthorized%'
            THEN 1 ELSE 0
        END) AS fraud_related,
    ROUND(
        100.0 * SUM(CASE
                        WHEN issue LIKE '%fraud%'
                          OR issue LIKE '%scam%'
                          OR issue LIKE '%unauthorized%'
                        THEN 1 ELSE 0
                    END) / COUNT(*),
        1
    ) AS pct_fraud_related
FROM complaints
GROUP BY company, segment
ORDER BY pct_fraud_related DESC;


-- Q9. Geographic concentration (top 10 states)
-- Feeds the dashboard map. Raw counts track population, so read the share column.

SELECT
    state,
    COUNT(*) AS complaints,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM complaints), 1) AS pct_of_total
FROM complaints
WHERE state IS NOT NULL AND state != 'Not specified'
GROUP BY state
ORDER BY complaints DESC
LIMIT 10;


-- Q10. Channel mix
-- How complaints arrive. Web-native firms tend to skew heavily to one channel.

SELECT
    company,
    submitted_via,
    COUNT(*) AS complaints,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY company), 1) AS pct_within_company
FROM complaints
GROUP BY company, submitted_via
ORDER BY company, complaints DESC;
