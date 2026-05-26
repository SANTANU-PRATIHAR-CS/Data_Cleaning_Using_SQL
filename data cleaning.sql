-- SQL Project - Data Cleaning





SELECT * 
FROM world_layoffs.layoffs;

CREATE TABLE world_layoffs.layoffs_stagging
LIKE world_layoffs.layoffs;
SELECT * 
FROM world_layoffs.layoffs_stagging;


INSERT  world_layoffs.layoffs_stagging
SELECT *
FROM world_layoffs.layoffs;


SELECT *
FROM world_layoffs.layoffs_staging
;

SELECT company, industry, total_laid_off,`date`,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`) AS row_num
	FROM 
		world_layoffs.layoffs_stagging;
        
SELECT *
FROM (
    SELECT company, industry, total_laid_off,`date`,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`) AS row_num
	FROM 
		world_layoffs.layoffs_stagging
	) duplicates
WHERE  row_num > 1;

-- let's just look at oda to confirm
SELECT *
FROM world_layoffs.layoffs_stagging
WHERE company = 'Oda'
;
-- it looks like these are all legitimate entries and shouldn't be deleted. We need to really look at every single row to be accurate

-- these are our real duplicates 

SELECT *
FROM (
    SELECT company,location,industry,total_laid_off,percentage_laid_off,`date`,stage,country,funds_raised_millions,
    ROW_NUMBER() OVER(PARTITION BY company,location,industry,total_laid_off,percentage_laid_off,`date`,stage,country,funds_raised_millions)
    AS row_num
    FROM world_layoffs.layoffs_stagging
  ) duplicates
WHERE 
	row_num > 1;
    
-- these are the ones we want to delete where the row number is > 1 or 2or greater essentially

WITH DELETE_CTE AS
(
SELECT *
FROM (
    SELECT company,location,industry,total_laid_off,percentage_laid_off,`date`,stage,country,funds_raised_millions,
    ROW_NUMBER() OVER(PARTITION BY company,location,industry,total_laid_off,percentage_laid_off,`date`,stage,country,funds_raised_millions)
    AS row_num
    FROM world_layoffs.layoffs_stagging
  ) duplicates
WHERE 
	row_num > 1
    
)

DELETE FROM DELETE_CTE; 
-- invaild


WITH DELETE_CTE AS (
	SELECT company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions, 
    ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
	FROM world_layoffs.layoffs_stagging
)
DELETE FROM world_layoffs.layoffs_stagging
WHERE (company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions, row_num) IN (
	SELECT company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions, row_num
	FROM DELETE_CTE
) AND row_num > 1;

-- one solution, which I think is a good one. Is to create a new column and add those row numbers in. Then delete where row numbers are over 2, then delete that column
-- so let's do it!!

ALTER TABLE world_layoffs.layoffs_stagging ADD row_num INT;
CREATE TABLE `world_layoffs`.`layoffs_stagging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
INSERT INTO `world_layoffs`.`layoffs_stagging2`
(`company`,
`location`,
`industry`,
`total_laid_off`,
`percentage_laid_off`,
`date`,
`stage`,
`country`,
`funds_raised_millions`,
`row_num`)
SELECT `company`,
`location`,
`industry`,
`total_laid_off`,
`percentage_laid_off`,
`date`,
`stage`,
`country`,
`funds_raised_millions`,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		world_layoffs.layoffs_stagging;
-- now that we have this we can delete rows were row_num is greater than 2

DELETE FROM world_layoffs.layoffs_stagging2
WHERE row_num >= 2;
 
 
SELECT *
FROM (
    SELECT company,location,industry,total_laid_off,percentage_laid_off,`date`,stage,country,funds_raised_millions,
    ROW_NUMBER() OVER(PARTITION BY company,location,industry,total_laid_off,percentage_laid_off,`date`,stage,country,funds_raised_millions)
    AS row_num
    FROM world_layoffs.layoffs_stagging2
  ) duplicates
WHERE 
	row_num > 1;


-- standardize data
SELECT * 
FROM world_layoffs.layoffs_stagging2;

SELECT DISTINCT company
FROM world_layoffs.layoffs_stagging2;

UPDATE world_layoffs.layoffs_stagging2
SET company = TRIM(company);
SELECT DISTINCT company
FROM world_layoffs.layoffs_stagging2;


-- if we look at industry it looks like we have some null and empty rows, let's take a look at these
SELECT DISTINCT industry
FROM world_layoffs.layoffs_stagging2
ORDER BY industry;   

SELECT *
FROM world_layoffs.layoffs_stagging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- let's take a look at these
SELECT *
FROM world_layoffs.layoffs_stagging2
WHERE company LIKE 'Bally%';

-- nothing wrong here
SELECT *
FROM world_layoffs.layoffs_stagging2
WHERE company LIKE 'airbnb%';


-- it looks like airbnb is a travel, but this one just isn't populated.
-- I'm sure it's the same for the others. What we can do is
-- write a query that if there is another row with the same company name, it will update it to the non-null industry values
-- makes it easy so if there were thousands we wouldn't have to manually check them all


UPDATE world_layoffs.layoffs_stagging2
SET industry = NULL
WHERE industry = '';
-- now if we check those are all null

SELECT *
FROM world_layoffs.layoffs_stagging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- now we need to populate those nulls if possible
UPDATE world_layoffs.layoffs_stagging2 t1
JOIN world_layoffs.layoffs_stagging2 t2
ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- and if we check it looks like Bally's was the only one without a populated row to populate this null values
SELECT *
FROM world_layoffs.layoffs_stagging2
WHERE industry IS NULL 
OR industry = ''
ORDER BY industry;

-- I also noticed the Crypto has multiple different variations. We need to standardize that - let's say all to Crypto
SELECT DISTINCT industry
FROM world_layoffs.layoffs_stagging2
ORDER BY industry;



UPDATE world_layoffs.layoffs_stagging2
SET industry = 'Crypto'
WHERE industry IN ('Crypto Currency', 'CryptoCurrency');


-- now that's taken care of:
SELECT DISTINCT industry
FROM world_layoffs.layoffs_stagging2
ORDER BY industry;


SELECT DISTINCT country
FROM world_layoffs.layoffs_stagging2;

UPDATE world_layoffs.layoffs_stagging2
SET country = TRIM(TRAILING '.' FROM country);

SELECT DISTINCT country
FROM world_layoffs.layoffs_stagging2
ORDER BY country;


-- Let's also fix the date columns:
SELECT *
FROM world_layoffs.layoffs_stagging2;
-- we can use str to date to update this field
UPDATE world_layoffs.layoffs_stagging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');
-- now we can convert the data type properly
ALTER TABLE world_layoffs.layoffs_stagging2
MODIFY COLUMN `date` DATE;
SELECT *
FROM world_layoffs.layoffs_stagging2;


-- 3. Look at Null Values
-- the null values in total_laid_off, percentage_laid_off, and funds_raised_millions all look normal. I don't think I want to change that
-- I like having them null because it makes it easier for calculations during the EDA phase
-- so there isn't anything I want to change with the null values

-- 4. remove any columns and rows we need to
SELECT *
FROM world_layoffs.layoffs_stagging2
WHERE total_laid_off IS NULL;
SELECT *
FROM world_layoffs.layoffs_stagging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;
-- Delete Useless data we can't really use
DELETE FROM world_layoffs.layoffs_stagging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;
SELECT * 
FROM world_layoffs.layoffs_stagging2;
ALTER TABLE world_layoffs.layoffs_stagging2
DROP COLUMN row_num;
SELECT * 
FROM world_layoffs.layoffs_stagging2;
