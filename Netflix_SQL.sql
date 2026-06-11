-- DROP TABLE IF EXISTS netflix;
-- CREATE TABLE netflix
-- (
--     show_id      VARCHAR(6),
--     type         VARCHAR(10),
--     title        VARCHAR(150),
--     director     VARCHAR(208),
--     casts        VARCHAR(1000),
--     country      VARCHAR(150),
--     date_added   VARCHAR(50),
--     release_year INT,
--     rating       VARCHAR(10),
--     duration     VARCHAR(15),
--     listed_in    VARCHAR(100),
--     description  VARCHAR(250)
-- );

SELECT * FROM netflix

SELECT 
	COUNT(*) as total_content
FROM netflix

SELECT 
	DISTINCT type
FROM netflix

--1. Count the Number of Movies vs TV Shows
SELECT
    COUNT(CASE WHEN type='Movie' THEN 1 END) AS total_movies,
    COUNT(CASE WHEN type='TV Show' THEN 1 END) AS total_tvshows
FROM netflix;

--OR

SELECT
	type,
	COUNT(*) as total_content
FROM netflix
GROUP BY 1;

--2 Find the Most Common Rating for Movies and TV Shows

SELECT
	type,
	rating
FROM 
(
	SELECT
		type,
		rating,
		COUNT(*),
		RANK() OVER(PARTITION BY type ORDER BY COUNT(*) DESC) as ranking
	FROM netflix
	GROUP BY 1, 2
) as t1
WHERE
	ranking = 1

--or

WITH RatingCounts AS (
    SELECT 
        type,
        rating,
        COUNT(*) AS rating_count
    FROM netflix
    GROUP BY type, rating
),
RankedRatings AS (
    SELECT 
        type,
        rating,
        rating_count,
        RANK() OVER (PARTITION BY type ORDER BY rating_count DESC) AS rank
    FROM RatingCounts
)
SELECT 
    type,
    rating AS most_frequent_rating
FROM RankedRatings
WHERE rank = 1;

--3 List All Movies Released in a Specific Year (e.g., 2020)

SELECT
    release_year,
    COUNT(*) AS total_titles,
    RANK() OVER(
        ORDER BY COUNT(*) DESC
    ) AS ranking
FROM netflix
GROUP BY release_year;

SELECT
    release_year,
    title,
    RANK() OVER(
        PARTITION BY release_year
        ORDER BY title
    ) AS ranking
FROM netflix;

SELECT
	title,
	type,
	release_year
FROM netflix
WHERE release_year = 2020 AND type = 'Movie'


--4. Find the Top 5 Countries with the Most Content on Netflix

SELECT
	UNNEST(STRING_TO_ARRAY(country, ',')) as new_country,
	COUNT(show_id) as total_content
FROM netflix
GROUP BY country
ORDER BY 2 DESC
LIMIT 5

--5. Identify the Longest Movie
--CHARACTER VISE
SELECT
	title,
	LENGTH(title)
FROM netflix
WHERE type = 'Movie'
ORDER BY 2 DESC LIMIT 1;

--DURATION VISE
SELECT
	title,
	duration
FROM netflix
WHERE type = 'Movie' AND duration<>'[null]'
ORDER BY 2 DESC;

--or
SELECT * FROM netflix
WHERE type = 'Movie' AND duration = (SELECT(MAX(duration)) FROM netflix)

--or
SELECT 
    *
FROM netflix
WHERE type = 'Movie'
ORDER BY SPLIT_PART(duration, ' ', 1)::INT DESC;

--6. Find Content Added in the Last 5 Years
SELECT *
FROM netflix
WHERE
	TO_DATE(date_Added, 'Month DD, Year') >=  CURRENT_DATE - INTERVAL ' 5 years'

--7. Find All Movies/TV Shows by Director 'Rajiv Chilaka'
SELECT 
	title,
	type
FROM netflix
WHERE
	director = 'Rajiv Chilaka'

	--but what if joint directors, then use LIKE INSTEAD OF =, ALSO ILIKE IS FOR CASE SENSITIVE

SELECT 
	title,
	type,
	director
FROM netflix
WHERE
	director ILIKE '%Rajiv Chilaka%'
--OR
SELECT *
FROM (
    SELECT 
        *,
        UNNEST(STRING_TO_ARRAY(director, ',')) AS director_name
    FROM netflix
) AS t
WHERE director_name = 'Rajiv Chilaka';


--8.List All TV Shows with More Than 5 Seasons

SELECT 
    *
FROM netflix
WHERE type = 'TV Show'
AND 
SPLIT_PART(duration, ' ', 1)::INT >5 

--9. Count the Number of Content Items in Each Genre

SELECT
	UNNEST(STRING_TO_ARRAY(listed_in, ',')) as genre,
	COUNT(show_id) as total_content
FROM netflix
GROUP BY 1

--10.Find each year and the average numbers of content release in India on netflix.

SELECT 
	EXTRACT(YEAR FROM TO_DATE(date_added, 'Month DD, YYYY')) as year,	
	COUNT(*) as yearly_content,
	ROUND(COUNT(*)::numeric/(SELECT COUNT(*) FROM netflix WHERE country = 'India')::numeric * 100 , 2) as avg_content
FROM netflix
WHERE country = 'India'
GROUP BY 1

--11. List All Movies that are Documentaries
SELECT * FROM netflix
WHERE 
	listed_in ILIKE '%Documentaries'

--12. Find All Content Without a Director
SELECT * FROM netflix
WHERE director IS NULL

--13. Find How Many Movies Actor 'Salman Khan' Appeared in the Last 10 Years
SELECT
	*
FROM netflix
WHERE type = 'Movie' AND casts ILIKE '%Salman Khan%' AND release_year > EXTRACT(YEAR FROM CURRENT_DATE) - 10

--14 Find the Top 10 Actors Who Have Appeared in the Highest Number of Movies Produced in India
SELECT
UNNEST(STRING_TO_ARRAY(casts, ',')) as actors,
COUNT(*) as total_Counts
FROM netflix
WHERE country ILIKE '%India%'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10

--15 Categorize Content Based on the Presence of 'Kill' and 'Violence' Keywords

WITH new_table
AS
(SELECT 
*,
CASE
WHEN description ILIKE '%kill%' OR  description ILIKE '%violence%' THEN 'Bad_Content'
ELSE 'Good_Content'
END category
FROM netflix
)
SELECT 
	category,
	COUNT(*) as total_content
FROM new_table
GROUP BY 1
