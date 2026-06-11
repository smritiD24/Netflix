# Netflix SQL Data Analysis Project
![LOGO](https://github.com/smritiD24/Netflix/blob/main/Netflix_Logo)
## About This Project

Netflix has one of the most publicly discussed content libraries in the world, so I thought it'd be interesting to go beyond just "how many movies vs shows" and actually dig into content patterns — which countries produce the most, how ratings are distributed, what genres dominate, and whether you can spot anything meaningful in the descriptions themselves.

This project uses a real Kaggle dataset (not synthetic), which made it more interesting to work with — messy multi-value columns like `country`, `director`, and `casts` required string splitting before any meaningful grouping could happen.

I used **PostgreSQL** for all queries.

---

## Dataset

- **Source:** [Netflix Movies and TV Shows — Kaggle](https://www.kaggle.com/datasets/shivamb/netflix-shows?resource=download)
- **Size:** ~8,800 rows, one row per title
- Single flat table (no joins needed — different challenge from Zomato)

---

## What's Inside

```
netflix-sql-analysis/
│
├── README.md                        -- you're reading it
├── logo.png                         -- Netflix logo
├── schema_setup.sql                 -- table creation
├── solutions.sql                    -- all 15 business problem solutions
└── additional_problems.sql          -- 5 extra questions I added
```

---

## Schema

One table, twelve columns. Simpler structure than Zomato but the multi-value fields (comma-separated countries, directors, cast) make string manipulation essential.

```sql
DROP TABLE IF EXISTS netflix;

CREATE TABLE netflix (
    show_id      VARCHAR(5),
    type         VARCHAR(10),
    title        VARCHAR(250),
    director     VARCHAR(550),
    casts        VARCHAR(1050),
    country      VARCHAR(550),
    date_added   VARCHAR(55),
    release_year INT,
    rating       VARCHAR(15),
    duration     VARCHAR(15),
    listed_in    VARCHAR(250),
    description  VARCHAR(550)
);
```

> **Note:** `date_added` is stored as VARCHAR, not DATE. So anywhere I need to filter by date, I convert it first using `TO_DATE(date_added, 'Month DD, YYYY')`. Worth keeping in mind.

---

## Business Problems and Solutions

### Q1. Count of Movies vs TV Shows

Simple baseline — understanding the content split before going deeper.

```sql
SELECT 
    type,
    COUNT(*) AS total_content
FROM netflix
GROUP BY type;
```

> Netflix has significantly more Movies than TV Shows in this dataset. Most content strategy decisions would weight Movies heavier.

---

### Q2. Most Common Rating for Movies and TV Shows

Used `RANK()` partitioned by type so we get the top rating independently for Movies and TV Shows — a plain GROUP BY would mix them together.

```sql
WITH rating_counts AS (
    SELECT 
        type,
        rating,
        COUNT(*) AS rating_count
    FROM netflix
    GROUP BY type, rating
),
ranked_ratings AS (
    SELECT 
        type,
        rating,
        rating_count,
        RANK() OVER(PARTITION BY type ORDER BY rating_count DESC) AS rank
    FROM rating_counts
)
SELECT 
    type,
    rating AS most_common_rating
FROM ranked_ratings
WHERE rank = 1;
```

> TV-MA dominates for both types — most of Netflix's catalog targets mature audiences, not families.

---

### Q3. All Movies Released in a Specific Year

```sql
-- Change 2020 to any year you want to filter
SELECT * 
FROM netflix
WHERE type = 'Movie'
  AND release_year = 2020;
```

---

### Q4. Top 5 Countries with the Most Content

The `country` column often has multiple countries comma-separated (e.g. "United States, India"). `STRING_TO_ARRAY` + `UNNEST` splits them into individual rows before grouping.

```sql
SELECT 
    TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS country,
    COUNT(*) AS total_content
FROM netflix
WHERE country IS NOT NULL
GROUP BY 1
ORDER BY total_content DESC
LIMIT 5;
```

> I added `TRIM()` here — without it, " India" and "India" would count as different countries due to the leading space after the comma.

---

### Q5. Longest Movie on Netflix

`duration` is stored as "90 min" or "2 Seasons" — so I split on space, take the first part, cast to INT, and sort descending.

```sql
SELECT 
    title,
    duration,
    SPLIT_PART(duration, ' ', 1)::INT AS duration_minutes
FROM netflix
WHERE type = 'Movie'
  AND duration IS NOT NULL
ORDER BY duration_minutes DESC
LIMIT 1;
```

---

### Q6. Content Added in the Last 5 Years

Since `date_added` is a VARCHAR, we need `TO_DATE()` to convert before comparing.

```sql
SELECT 
    title,
    type,
    date_added
FROM netflix
WHERE TO_DATE(date_added, 'Month DD, YYYY') >= CURRENT_DATE - INTERVAL '5 years';
```

---

### Q7. All Content by a Specific Director

Director can be multi-valued too (e.g. "Director A, Director B"), so same UNNEST approach as countries.

```sql
-- Change director name as needed
SELECT *
FROM (
    SELECT 
        *,
        TRIM(UNNEST(STRING_TO_ARRAY(director, ','))) AS director_name
    FROM netflix
) AS t
WHERE director_name = 'Rajiv Chilaka';
```

---

### Q8. TV Shows with More Than 5 Seasons

```sql
SELECT 
    title,
    duration
FROM netflix
WHERE type = 'TV Show'
  AND SPLIT_PART(duration, ' ', 1)::INT > 5;
```

---

### Q9. Content Count by Genre

`listed_in` is also comma-separated (e.g. "Dramas, International Movies"). Unnesting gives us a row per genre per title.

```sql
SELECT 
    TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) AS genre,
    COUNT(*) AS total_content
FROM netflix
GROUP BY 1
ORDER BY total_content DESC;
```

---

### Q10. Top 5 Years by Average Indian Content Release

What % of India's total Netflix content was released each year? Shows whether India's presence on Netflix has grown over time.

```sql
SELECT 
    release_year,
    COUNT(show_id) AS total_releases,
    ROUND(
        COUNT(show_id)::numeric /
        (SELECT COUNT(show_id) FROM netflix WHERE country = 'India')::numeric * 100
    , 2) AS pct_of_india_total
FROM netflix
WHERE country = 'India'
GROUP BY release_year
ORDER BY pct_of_india_total DESC
LIMIT 5;
```

> This gives a sense of which years were peak India content years on Netflix — useful context for anyone interested in OTT industry trends.

---

### Q11. All Documentary Movies

```sql
SELECT 
    title,
    listed_in
FROM netflix
WHERE type = 'Movie'
  AND listed_in ILIKE '%Documentaries%';
```

> Used `ILIKE` instead of `LIKE` for case-insensitive matching — safer since the genre casing in the dataset isn't always consistent.

---

### Q12. Content Without a Director

```sql
SELECT 
    title,
    type,
    country
FROM netflix
WHERE director IS NULL;
```

> A meaningful data quality check. A large number of NULL directors likely means the data was scraped and not all entries were complete — worth flagging in a real analysis.

---

### Q13. Salman Khan Movies in the Last 10 Years

```sql
SELECT 
    title,
    release_year,
    casts
FROM netflix
WHERE casts ILIKE '%Salman Khan%'
  AND release_year > EXTRACT(YEAR FROM CURRENT_DATE) - 10;
```

---

### Q14. Top 10 Actors in Indian Content

Same UNNEST pattern — casts column is comma-separated.

```sql
SELECT 
    TRIM(UNNEST(STRING_TO_ARRAY(casts, ','))) AS actor,
    COUNT(*) AS appearances
FROM netflix
WHERE country ILIKE '%India%'
GROUP BY actor
ORDER BY appearances DESC
LIMIT 10;
```

---

### Q15. Content Categorization by Keywords in Description

Flag content as 'Flagged' if the description mentions 'kill' or 'violence', otherwise 'Clean'. A simple NLP-lite approach using ILIKE.

```sql
SELECT 
    category,
    COUNT(*) AS total_content
FROM (
    SELECT 
        CASE 
            WHEN description ILIKE '%kill%' 
              OR description ILIKE '%violence%' THEN 'Flagged'
            ELSE 'Clean'
        END AS category
    FROM netflix
) AS categorized
GROUP BY category;
```

> Renamed 'Bad'/'Good' to 'Flagged'/'Clean' — more neutral and accurate since a movie about war isn't "bad", it just contains those keywords.

---

## Additional Problems (Self-Added)

After finishing the 15, I noticed a few angles that weren't covered. Solutions are in `additional_problems.sql`.

### Q16. Which Month Has the Most Content Added Historically?
Netflix releases content year-round but there are patterns. Find the month where the most titles have been added across all years.

### Q17. Countries That Produce Both Movies and TV Shows
Some countries only produce one type. Find countries that have contributed both Movies and TV Shows to Netflix.

### Q18. Directors with the Most Titles — Movies vs TV Shows Separately
Top directors overall is common. This splits by type to see who dominates each category.

### Q19. Content Released vs Added Gap
For each title, calculate how many years passed between `release_year` and when it was added to Netflix. Large gaps = catalogue content; small gaps = fresh releases.

### Q20. Rating Distribution by Country (Top 5 Countries)
For the top 5 content-producing countries, show how ratings are distributed. Do different countries skew toward different audience ratings?

---

## Key Learnings from This Project

- **UNNEST + STRING_TO_ARRAY** is essential whenever columns store multiple values as comma-separated strings — came up in country, director, casts, and listed_in.
- **TRIM()** matters when splitting — spaces after commas cause invisible duplicates in GROUP BY results.
- **Type casting** is necessary throughout — duration and date_added being stored as VARCHAR forces explicit conversions before any numeric or date operations.
- Single-table projects aren't "easier" — the complexity just shifts from JOINs to string manipulation and casting.
- `ILIKE` over `LIKE` for any user-facing or scraped data where casing is inconsistent.

---

## Tools Used

- PostgreSQL 15
- pgAdmin 4
- Dataset: Real data from Kaggle (public domain)

---

*This project was inspired by ZeroAnalyst (Najir H.) on YouTube. The original 15 problem statements are from his course. All SQL solutions, comments, notes, and additional questions (Q16–Q20) are written by me.*
