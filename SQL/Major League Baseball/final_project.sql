-- PART I: SCHOOL ANALYSIS
use maven_advanced_sql;

-- 1. View the schools and school details tables
SELECT * FROM schools;
SELECT * FROM school_details;

-- 2. In each decade, how many schools were there that produced players?
SELECT round(yearID, -1) AS decade, COUNT(DISTINCT schoolID) AS num_schools
FROM schools
GROUP BY decade
ORDER BY decade ASC;

-- 3. What are the names of the top 5 schools that produced the most players?
SELECT sd.name_full, COUNT(DISTINCT s.playerID) AS num_players
FROM schools s LEFT JOIN school_details sd
ON s.schoolID = sd.schoolID
GROUP BY sd.name_full
ORDER BY num_players DESC
LIMIT 5;

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?
WITH decade_players AS (SELECT round(s.yearID, -1) AS decade, sd.name_full, COUNT(DISTINCT s.playerID) AS num_players
						FROM schools s LEFT JOIN school_details sd
						ON s.schoolID = sd.schoolID
						GROUP BY decade, sd.name_full),

     school_rank AS (SELECT decade, name_full, num_players,
							ROW_NUMBER() OVER(PARTITION BY decade ORDER BY num_players DESC) AS row_num
					 FROM decade_players)

SELECT decade, name_full, num_players
FROM school_rank
WHERE row_num <= 3
ORDER BY decade DESC, row_num;

-- PART II: SALARY ANALYSIS
-- 1. View the salaries table
SELECT * FROM salaries;

-- 2. Return the top 20% of teams in terms of average annual spending
WITH ts AS (SELECT teamID, yearID, SUM(salary) AS total_spend
			FROM salaries
			GROUP BY teamID, yearID
			ORDER BY teamID, yearID),

	 sp AS (SELECT teamID, AVG(total_spend) AS avg_spend,
				   NTILE(5) OVER(ORDER BY AVG(total_spend) DESC) as spend_pct
			FROM ts
			GROUP BY teamID)

SELECT teamID, avg_spend
FROM sp
WHERE spend_pct = 1;

-- 3. For each team, show the cumulative sum of spending over the years
WITH ys AS (SELECT teamID, yearID, SUM(salary) AS yearly_spend
			FROM salaries
			GROUP BY teamID, yearID
			ORDER BY teamID, yearID)
            
SELECT teamID, yearID, yearly_spend,
       SUM(yearly_spend) OVER(PARTITION BY teamID ORDER BY yearID) AS cumulative_spend
FROM ys;

-- 4. Return the first year that each team's cumulative spending surpassed 1 billion
WITH ys AS (SELECT teamID, yearID, SUM(salary) AS yearly_spend
			FROM salaries
			GROUP BY teamID, yearID
			ORDER BY teamID, yearID),
            
     cs AS (SELECT teamID, yearID, yearly_spend,
			SUM(yearly_spend) OVER(PARTITION BY teamID ORDER BY yearID) AS cumulative_spend
			FROM ys),

ranked_billion AS (SELECT teamID, yearID, yearly_spend, cumulative_spend,
						  ROW_NUMBER() OVER(PARTITION BY teamID ORDER BY yearID) AS row_n
				   FROM cs
				   WHERE cumulative_spend > 1000000000)

SELECT teamID, yearID, round(cumulative_spend/1000000000, 2) AS cumulative_spend_billions
FROM ranked_billion
where row_n = 1;

-- PART III: PLAYER CAREER ANALYSIS
-- 1. View the players table and find the number of players in the table
SELECT count(DISTINCT playerID) AS total_players
FROM players;

-- 2. For each player, calculate their age at their first game, their last game, and their career length (all in years). Sort from longest career to shortest career.
WITH bd AS (SELECT playerID, nameGiven, CAST(CONCAT(birthYear,'-',birthMonth,'-', birthDay) AS DATE) AS birthDate, debut, finalGame
			FROM players)

SELECT playerID, nameGiven, TIMESTAMPDIFF(YEAR, birthDate, debut) AS starting_age,
	   TIMESTAMPDIFF(YEAR, birthDate, finalGame) AS ending_age,
       TIMESTAMPDIFF(YEAR, debut, finalGame) AS career_length
FROM bd
ORDER BY career_length DESC;

-- 3. What team did each player play on for their starting and ending years?
SELECT p.nameGiven, s.yearID AS start_year, s.teamID AS start_team, 
	   e.yearID AS end_year, e.teamID AS end_team
FROM players p INNER JOIN salaries s
						  ON p.playerID = s.playerID
						  AND YEAR(p.debut) = s.yearID
			   INNER JOIN salaries e
						  ON p.playerID = e.playerID
						  AND YEAR(p.finalGame) = e.yearID;

-- 4. How many players started and ended on the same team and also played for over a decade?
WITH se AS (SELECT p.nameGiven, s.yearID AS start_year, s.teamID AS start_team, 
				   e.yearID AS end_year, e.teamID AS end_team
			FROM players p INNER JOIN salaries s
									  ON p.playerID = s.playerID
									  AND YEAR(p.debut) = s.yearID
						   INNER JOIN salaries e
									  ON p.playerID = e.playerID
									  AND YEAR(p.finalGame) = e.yearID)

SELECT COUNT(DISTINCT nameGiven) AS num_players
FROM se
WHERE start_team = end_team AND end_year - start_year > 10;

-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table
SELECT *
FROM players;

-- 2. Which players have the same birthday?
WITH bn AS (SELECT CAST(CONCAT(birthYear,'-',birthMonth,'-', birthDay) AS DATE) AS birthDate, nameGiven 
			FROM players)

SELECT birthDate, GROUP_CONCAT(nameGiven SEPARATOR ', ') AS players, COUNT(nameGiven) AS num_players
FROM bn
WHERE birthDate IS NOT NULL
GROUP BY birthDate
HAVING num_players > 1
ORDER BY birthDate;

-- 3. Create a summary table that shows for each team, what percent of players bat right, left and both
SELECT s.teamID, COUNT(s.playerID) as num_players,
	   ROUND(SUM(CASE WHEN p.bats = 'R' THEN 1 ELSE 0 END) / COUNT(s.playerID)*100, 1) AS bats_right,
       ROUND(SUM(CASE WHEN p.bats = 'L' THEN 1 ELSE 0 END) / COUNT(s.playerID)*100, 1) AS bats_left,
       ROUND(SUM(CASE WHEN p.bats = 'B' THEN 1 ELSE 0 END) / COUNT(s.playerID)*100, 1) AS bats_both
FROM players p INNER JOIN salaries s
ON p.playerID = s.playerID
GROUP BY s.teamID; 

-- 4. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?
WITH hw AS (SELECT ROUND(YEAR(debut),-1) AS decade, AVG(height) AS avg_height, AVG(weight) AS avg_weight
			FROM players
			GROUP BY decade)
            
SELECT decade, 
		avg_height - LAG(avg_height) OVER(ORDER BY decade) AS height_diff,
        avg_weight - LAG(avg_weight) OVER(ORDER BY decade) AS weight_diff
FROM hw
WHERE decade IS NOT NULL;

