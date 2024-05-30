/*
    COMP3311 24T1 Assignment 1
    IMDB Views, SQL Functions, and PlpgSQL Functions
    Student Name: Matthew O'Dea
    Student ID: z5413887

    A note on code style / convention. I have used the case consistent with variable naming in the IMDB.schema.sql file & function inputs: PascalCase
*/


-- Question 1 --

/**
    Write a SQL View, called Q1, that:
    Retrieves the 10 movies with the highest number of votes.
*/
CREATE OR REPLACE VIEW Q1(Title, Year, Votes) AS
    SELECT Primary_Title, Release_Year, Votes
    FROM Movies
    -- Make sure votes are not NULL, otherwise DESC picks NULL first
    WHERE Votes IS NOT NULL
    ORDER BY Votes DESC
    LIMIT 10;


-- Question 2 --

/**
    Write a SQL View, called Q2(Name, Title), that:
    Retrieves the names of people who have a year of death recorded in the database
    and are well known for their work in movies released between 2017 and 2019.
*/
CREATE OR REPLACE VIEW Q2(Name, Title) AS
    SELECT DISTINCT p.Name, m.Primary_Title AS Title
    FROM People p
    -- using principals to find 'well-known' people
    JOIN Principals pr ON p.ID = pr.Person
    JOIN Movies m ON pr.Movie = m.ID
    WHERE p.Death_Year IS NOT NULL
    AND m.Release_Year BETWEEN 2017 AND 2019;


-- Question 3 --

/**
    Write a SQL View, called Q3(Name, Average), that:
    Retrieves the genres with an average rating not less than 6.5 and with more than 60 released movies.
*/
CREATE OR REPLACE VIEW Q3(Name, Average) AS
    -- test data wants averages to 2 dp.
    SELECT g.Name, ROUND(AVG(m.Score), 2) AS Average
    FROM Genres g
    JOIN Movies_Genres mg ON g.ID = mg.Genre
    JOIN Movies m ON mg.Movie = m.ID
    GROUP BY g.Name
    -- more than 69 released and average above 6.5
    HAVING COUNT(m.ID) > 60 AND AVG(m.Score) >= 6.5
    ORDER BY Average DESC;


-- Question 4 --

/**
    Write a SQL View, called Q4(Region, Average), that:
    Retrieves the regions with an average runtime greater than the average runtime of all movies.
*/
CREATE OR REPLACE VIEW Q4(Region, Average) AS
    SELECT r.Region, ROUND(AVG(m.Runtime)) AS Average
    FROM Releases r
    JOIN Movies m ON r.Movie = m.ID
    GROUP BY r.Region
    -- Runtime for average movie in given region > Avg runtime for all movies
    HAVING AVG(m.Runtime) > (
        SELECT AVG(Runtime)
        FROM Movies
    )
    ORDER BY Average DESC, r.Region;


-- Question 5 --
/**
    Write a SQL Function, called Q5(Pattern TEXT) RETURNS TABLE (Movie TEXT, Length TEXT), that:
    Retrieves the movies whose title matches the given regular expression,
    and displays their runtime in hours and minutes.
*/
CREATE OR REPLACE FUNCTION Q5(Pattern TEXT)
    RETURNS TABLE (Movie TEXT, Length TEXT)
    AS $$
        -- String formatting into Hours & Minutes, as runtime is stored in total minutes
        SELECT Primary_Title AS Movie, CONCAT((Runtime / 60), ' Hours ', (Runtime % 60), ' Minutes') AS Length
        FROM Movies
        -- % % on either side indiciates that it only has to contain the expression within the title
        WHERE Primary_Title LIKE CONCAT('%', Pattern, '%') AND Runtime > 0
        ORDER BY Primary_Title;
    $$ LANGUAGE SQL;


-- Question 6 --
/**
    Write a SQL Function, called Q6(GenreName TEXT) RETURNS TABLE (Year Year, Movies INTEGER), that:
    Retrieves the years with at least 10 movies released in a given genre.
*/
CREATE OR REPLACE FUNCTION Q6(GenreName TEXT)
    RETURNS TABLE (Year Year, Movies INTEGER)
    AS $$
        SELECT m.Release_Year, COUNT(*) AS NumMovies
        FROM Movies m, Movies_Genres mg, Genres g
        WHERE m.ID = mg.Movie
            AND mg.Genre = g.ID
            AND g.Name = GenreName
            -- Don't want to include results with NULL release year
            AND m.Release_Year IS NOT NULL
        GROUP BY m.Release_Year
        HAVING COUNT(*) > 10
        -- Order by most to least movies, if a tie then newest first
        ORDER BY NumMovies DESC, m.Release_Year DESC;
    $$ LANGUAGE SQL;


-- Question 7 --

/**
    Write a SQL Function, called Q7(MovieName TEXT) RETURNS TABLE (Actor TEXT), that:
    Retrieves the actors who have played multiple different roles within the given movie.
*/
CREATE OR REPLACE FUNCTION Q7(MovieName TEXT)
    RETURNS TABLE (Actor TEXT)
    AS $$
        SELECT p.Name AS Actor
        FROM Movies m
        JOIN Roles r ON m.ID = r.Movie
        JOIN People p ON r.Person = p.ID
        WHERE m.Primary_Title = MovieName
        GROUP BY p.Name
        -- Make we only get Actors who have played more than one role. Note this rules out cast, who can't play roles
        HAVING COUNT(r.Played) > 1
        -- Sort alphabetically
        ORDER BY p.Name;
    $$ LANGUAGE SQL;


-- Question 8 --

/**
    Write a SQL Function, called Q8(MovieName TEXT) RETURNS TEXT, that:
    Retrieves the number of releases for a given movie.
    If the movie is not found, then an error message should be returned.
*/
CREATE OR REPLACE FUNCTION Q8(MovieName TEXT)
    RETURNS TEXT
    AS $$
DECLARE
    ReleaseCount INTEGER;
    MovieID INTEGER;
    -- Easiest to have just one result variable that we update based on return condition
    Result TEXT;
BEGIN
    -- Find ID from name
    SELECT ID INTO MovieID
    FROM Movies
    WHERE Primary_Title = MovieName;

    -- If the movie is not found: Movie "<MovieName>" not found
    IF NOT FOUND THEN
        Result := format('Movie "%s" not found', MovieName);

    -- If the movie is found and has >0 releases: Release count: <N>
    ELSE
        -- Get the count of releases for the movie
        SELECT COUNT(*) INTO ReleaseCount
        FROM Releases
        WHERE Movie = MovieID;
        IF ReleaseCount > 0 THEN
            Result := format('Release count: %s', ReleaseCount);

        -- If the movie is found and has 0 release: No releases found for "<MovieName>"
        ELSE
            Result := format('No releases found for "%s"', MovieName);
        END IF;
    END IF;

    RETURN Result;
END;
$$ LANGUAGE plpgsql;


-- Question 9 --

/**
    Write a SQL Function, called Q9(MovieName TEXT) RETURNS SETOF TEXT, that:
    Retrieves the Cast and Crew of a given movie.
*/
CREATE OR REPLACE FUNCTION Q9(MovieName TEXT)
    RETURNS SETOF TEXT
    AS $$
DECLARE
    MovieID INTEGER;
    CastName TEXT;
    CastPlayed TEXT;
    CrewName TEXT;
    CrewJob TEXT;
BEGIN
    -- Get ID using name
    SELECT ID INTO MovieID
    FROM Movies
    WHERE Primary_Title = MovieName;

    -- Get all cast members, joining People and Roles to get names & roles
    FOR CastName, CastPlayed IN (
        SELECT p.Name, r.Played
        FROM People p
        JOIN Roles r ON p.ID = r.Person
        WHERE r.Movie = MovieID
    )
    -- Return all the diff cast members one by one
    LOOP
        RETURN NEXT format('"%s" played "%s" in "%s"', CastName, CastPlayed, MovieName);
    END LOOP;

    -- Get all crew, joining People, Credits and Professions to print everyone who isn't an actor
    FOR CrewName, CrewJob IN (
        SELECT p.Name, pf.Name
        FROM People p
        JOIN Credits c ON p.ID = c.Person
        JOIN Professions pf ON c.Profession = pf.ID
        -- <> same as NOT EQUAL TO
        WHERE c.Movie = MovieID AND pf.Name <> 'Actor'
    )
    -- Return them all. Noting that order doesn't really matter for this question
    LOOP
        RETURN NEXT format('"%s" worked on "%s" as a %s', CrewName, MovieName, CrewJob);
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;



-- Question 10 --

/**
    Write a PLpgSQL Function, called Q10(MovieRegion CHAR(4)) RETURNS TABLE (Year INTEGER, Best_Movie TEXT, Movie_Genre Text,Principals TEXT), that:
    Retrieves the list of must-watch movies for a given region, year by year.
    Your function should return the Release Year, the Primary Title of the movie, the list of Genres of the movie, and the names of the Principals for each movie.
*/
CREATE OR REPLACE FUNCTION Q10(MovieRegion CHAR(4))
    RETURNS TABLE (Year INTEGER, Best_Movie TEXT, Movie_Genre TEXT, Principals TEXT)
AS $$
DECLARE
    MovieYear INTEGER;
BEGIN
    -- Loop through all years with a movie, newest to oldest. Also don't want to get NULL years
    FOR MovieYear IN (SELECT DISTINCT Release_Year FROM Movies WHERE Release_Year IS NOT NULL ORDER BY Release_Year DESC)
    LOOP
        -- Call helper function to find the best movie(s) for the current year. We loop through to go through all the tied scores.
        Year := MovieYear;
        FOR Best_Movie IN SELECT * FROM FindMustWatchMovie(MovieRegion, MovieYear) 
            LOOP

            -- If no best movie found, move to next year
            IF Best_Movie IS NULL THEN
                CONTINUE;
            END IF;

            -- Get all genres that are applicable
            SELECT STRING_AGG(g.Name, ', ' ORDER BY g.Name) INTO Movie_Genre
            FROM Genres g
            JOIN Movies_Genres mg ON g.ID = mg.Genre
            WHERE mg.Movie = (
                SELECT ID 
                FROM Movies 
                WHERE Primary_Title = Best_Movie
                -- make sure that for movies with multiple entries under their primary title, we only get the right region
                AND ID IN (
                    SELECT Movie 
                    FROM Releases 
                    WHERE Region = MovieRegion
                )
            );

            -- Get all principals that are applicable
            SELECT STRING_AGG(p.Name, ', ' ORDER BY p.Name) INTO Principals
            FROM People p
            WHERE p.ID IN (
                SELECT Person
                FROM Principals
                WHERE Movie = (
                    SELECT ID 
                    FROM Movies 
                    WHERE Primary_Title = Best_Movie
                    -- make sure that for movies with multiple entries under their primary title, we only get the right region
                    AND ID IN (
                        SELECT Movie 
                        FROM Releases 
                        WHERE Region = MovieRegion
                    )
                )
            );

            -- Return the result for the current year
            RETURN NEXT;
        END LOOP;
    END LOOP;
    RETURN; -- Indicates the end of the result set
END;
$$ LANGUAGE plpgsql;


/* 
    HELPER FUNCTION: Finds the must watch movie(s) in a given year. Returns their titles
*/
CREATE OR REPLACE FUNCTION FindMustWatchMovie(MovieRegion CHAR(4), MovieYear INTEGER)
    RETURNS TABLE (MovieTitle TEXT)
    AS $$
BEGIN
    -- Check if any movie has a recorded score for the given year
    IF EXISTS (
        SELECT 1
        FROM Movies m
        JOIN Releases r ON m.ID = r.Movie
        -- make sure score is not null (was causing problems)
        WHERE r.Region = MovieRegion AND m.Release_Year = MovieYear AND m.Score IS NOT NULL
    ) THEN
        -- If there are movies with recorded scores, return the highest-rated ones
        RETURN QUERY
        -- DISTINCT is important here!! solves my last error (same movie releases twice in same region)
        SELECT DISTINCT m.Primary_Title
        FROM Movies m
        JOIN Releases r ON m.ID = r.Movie
        WHERE r.Region = MovieRegion AND m.Release_Year = MovieYear
        -- Get max score (can return multiple)
        AND m.Score = (
            SELECT MAX(m.Score)
            FROM Movies m
            JOIN Releases r ON m.ID = r.Movie
            WHERE r.Region = MovieRegion AND m.Release_Year = MovieYear
        )
        ORDER BY m.Primary_Title; -- Order alphabetically in case of ties
    END IF;
END;
$$ LANGUAGE plpgsql;