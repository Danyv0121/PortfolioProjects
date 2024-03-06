/*Create Base dataset to use throughout discovery*/

Create table public.covid_deaths_fullset as (
	
	Select a.*,b.iso_code,b.continent,b.population
	from global_covid_deaths a
	inner join (Select distinct iso_code,location,continent, population from covid_deaths) b on trim(a.location)=trim(b.location)
											)
											
/*Discovery 1: Likelyhood of a death if contracted covid virus by location and date */
	
Select *
from (
Select 
	iso_code,
	location,
	date,
	CAST(extract(year from date) as int) as year,
	total_cases,
	--new_cases,
	total_deaths,
	round((total_deaths::numeric/nullif(total_cases,0))*100,3) as deathPct
	--,c.max_death_pct

from covid_deaths_fullset
Where location='United States'
order by 2,3 DESC)


/*Prior to DS Optimization:	
from global_covid_deaths a
inner join covid_deaths b on trim(a.location)=trim(b.location))*/

	---Add peak Deathpct in dataset
-- INNER JOIN 
--     (
--         SELECT 
--             location,
--             MAX(ROUND((total_deaths::NUMERIC / NULLIF(total_cases, 0)) * 100, 3)) AS max_death_pct
--         FROM 
--             global_covid_deaths
--         WHERE 
--             EXTRACT(YEAR FROM date) = 2020 AND
--             location = 'United States'
--         GROUP BY 1
--     ) c on a.location=c.location	

-- Where a.location = 'United States' )
-- ---use added column to find peak period add insight into the analysis. Note: this question can be found in excel output of base dataset or done programmactically.
-- Where location = 'United States' 
-- 		--and year= 2020 
-- 		--and max_death_pct = deathpct
-- order by 2,3

/**Discovery #2: Looking at total cases vs Population  **/

Select 
	iso_code,
	location,
	date,
	CAST(extract(year from date) as int) as year,
	total_cases,
	population,
	round((total_cases::numeric/nullif(population,0))*100,3) as PctPopulationInfected
	
from covid_deaths_fullset
Where location='United States'
order by 2,3	

-- #3 looking at country with highest infection rate compared to population
Select 
	location,
	population,
	max(total_cases) as HighestInfectionCount,
	max(round((total_cases::numeric/nullif(population,0))*100,3)) as PctPopulationInfected,
	 RANK() OVER (ORDER BY Max(round((total_cases::numeric / NULLIF(population, 0)) * 100, 6)) DESC) AS InfectionRank
	
from covid_deaths_fullset
group by 1,2
order by PctPopulationInfected desc  

-- #4 showing the countries with the highest death count per population

Select 
	location,
	max(total_deaths) as TotaldeathCount
	--max(round((total_cases::numeric/nullif(population,0))*100,3)) as PctPopulationInfected,
	 --RANK() OVER (ORDER BY Max(round((total_cases::numeric / NULLIF(population, 0)) * 100, 6)) DESC) AS InfectionRank
	
from covid_deaths_fullset
where continent is not null
--and location='China'
group by 1
order by TotaldeathCount desc	


---Check another way to map drill down... Test
Select 
	location,
	max(total_deaths) as TotaldeathCount
	
from covid_deaths_fullset
where continent is null
group by 1
order by TotaldeathCount desc


---#5 Showing the continents with the highest death count: Breakdown by continent: 
Select 
	continent,
	max(total_deaths) as TotaldeathCount
	
from covid_deaths_fullset
where continent is not null
--and location='United States'
group by 1
order by TotaldeathCount desc											

---#5 Global View total & By month & year (overtime)

--Select *
--from (
Select 
	--date,
	CAST(extract(week from date) as int) as week,
	CAST(extract(month from date) as int) as MONTH,
	CAST(extract(year from date) as int) as year,
	sum(new_cases) as Total_cases,
	sum(new_deaths) as Total_deaths,
	round((sum(new_deaths)::numeric/nullif(sum(new_cases),0))*100,3) as deathPct
    
-- 	total_cases,
-- 	total_deaths,
-- 	round((total_deaths::numeric/nullif(total_cases,0))*100,3) as deathPct
	--,c.max_death_pct

from covid_deaths_fullset
	Where continent is not null
--Where location='United States'
	group by 1,2,3 
	order by 3,1 desc
--order by 2,3 DESC
)

---Global Vaccination counts
Select 
	location
	CAST(extract(year from date) as varchar)||lpad(CAST(extract(week from date) as varchar),2,'0') as yearWeek,
	lpad(CAST(extract(week from date) as varchar),2,'0') as week,
	--CAST(extract(month from date) as int) as MONTH,
	CAST(extract(year from date) as int) as year,
	sum(daily_vaccinations) total_vaccinations
from vaccination
group by 1,2,3
order by 1

---combine deaths & vaccinations: Total population versus vaccinated
---example rolling count
Select 
	dea.continent, 
	dea.location, 
	dea.date, 
	dea.population,
	vax.new_vaccinations,
	sum(vax.new_vaccinations) over (partition by dea.location order by dea.location, dea.date) rolling_people_vaccvination,
	
from public.covid_deaths_fullset dea
join public.vaccination vax on trim(dea.location)=trim(vax.location) and dea.date = vax.date
Where dea.continent is not null --and dea.location = 'United States'
order by 2,3
		
--USE CTE

With popvsvax as (
Select 
	dea.continent, 
	dea.location, 
	dea.date, 
	dea.population,
	vax.new_vaccinations,
	sum(vax.new_vaccinations) over (partition by dea.location order by dea.location, dea.date) rolling_people_vaccinated
	
from public.covid_deaths_fullset dea
join public.vaccination vax on trim(dea.location)=trim(vax.location) and dea.date = vax.date
Where dea.continent is not null and dea.location = 'United States'
--order by 2,3
)


select *, (rolling_people_vaccinated/population)*100
from popvsvax

---Other example using Temp table temp_vax_stats

drop table if exists temp_vaccination_stats

CREATE TEMP TABLE temp_vaccination_stats AS
SELECT 
	dea.continent, 
	dea.location, 
	dea.date, 
	dea.population,
	vax.new_vaccinations,
	SUM(vax.new_vaccinations) OVER (
		PARTITION BY dea.location 
		ORDER BY dea.location, dea.date
	) AS rolling_people_vaccinated
	
FROM 
	public.covid_deaths_fullset dea
JOIN 
	public.vaccination vax 
	ON TRIM(dea.location) = TRIM(vax.location) AND dea.date = vax.date
WHERE 
	dea.continent IS NOT NULL --AND dea.location = 'United States'
ORDER BY 
	2, 3;

Select * 
from temp_vaccination_stats


---Creating a view to store data for visualization platform
create view temp_vaccination_stats AS
SELECT 
	dea.continent, 
	dea.location, 
	dea.date, 
	dea.population,
	vax.new_vaccinations,
	SUM(vax.new_vaccinations) OVER (
		PARTITION BY dea.location 
		ORDER BY dea.location, dea.date
	) AS rolling_people_vaccinated
	
FROM 
	public.covid_deaths_fullset dea
JOIN 
	public.vaccination vax 
	ON TRIM(dea.location) = TRIM(vax.location) AND dea.date = vax.date
WHERE 
	dea.continent IS NOT NULL 
