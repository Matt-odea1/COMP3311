-- COMP3311 24T1 Ass2 ... SQL helper Views/Functions
-- Add any views or functions you need into this file
-- Note: it must load without error into a freshly created Pokemon database

-- Your Views/Functions Below Here
-- Remember This file must load into a clean Pokemon database in one pass without any error
-- NOTICEs are fine, but ERRORs are not
-- Views/Functions must be defined in the correct order (dependencies first)
-- eg if my_supper_clever_function() depends on my_other_function() then my_other_function() must be defined first
-- Your Views/Functions Below Here
-- --------------------------------------------------------------------------------------------------------------------------------------

-- Q1
CREATE OR REPLACE FUNCTION Q1()
RETURNS TABLE (
    RegionName Regions,
    GameName TEXT,
    NumPokemon INTEGER,
    NumLocations INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        G.Region,
        G.Name AS GameName,
        COUNT(DISTINCT P.ID)::INTEGER AS NumPokemon,
        COUNT(DISTINCT L.ID)::INTEGER AS NumLocations
    FROM
        Games G
    LEFT JOIN Pokedex PD ON G.ID = PD.Game
    LEFT JOIN Pokemon P ON PD.National_ID = P.ID
    LEFT JOIN Locations L ON L.appears_in = G.ID
    GROUP BY
        G.Region, G.Name, G.ID
    ORDER BY
        G.Region, G.Name;
END;
$$ LANGUAGE plpgsql;


----------------------------------------------------------------------------------------------------------------
--Q2
CREATE OR REPLACE FUNCTION Q2(PokemonName TEXT)
RETURNS TABLE (
    GameRegion Regions,
    GameName TEXT,
    LocationName TEXT,
    Rarity TEXT,
    MinLevel INTEGER,
    MaxLevel INTEGER,
    Requirements TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        G.Region AS GameRegion,
        G.Name AS GameName,
        L.Name AS LocationName,
        CASE
            WHEN E.Rarity >= 21 THEN 'Common'
            WHEN E.Rarity BETWEEN 6 AND 20 THEN 'Uncommon'
            WHEN E.Rarity BETWEEN 1 AND 5 THEN 'Rare'
            ELSE 'Limited'
        END AS 
            Rarity,
            (E.Levels).Min AS MinLevel,
            (E.Levels).Max AS MaxLevel,
            string_agg(DISTINCT
                CASE
                    WHEN ER.Inverted = True THEN CONCAT('Not ', R.Assertion)
                    ELSE R.Assertion
                END,
                ', ') AS R
    FROM
        Encounters E
    JOIN Pokemon P ON E.Occurs_With = P.ID
    JOIN Locations L ON E.Occurs_At = L.ID
    JOIN Games G ON L.appears_in = G.ID    
    JOIN Encounter_Requirements ER ON ER.Encounter = E.ID
    JOIN Requirements R ON R.ID = ER.Requirement
    WHERE
        P.Name ILIKE PokemonName
    GROUP BY
        E.ID, G.Region, G.Name, L.Name, E.Rarity, (E.Levels).Min, (E.Levels).Max
    ORDER BY
        G.Region, G.Name, L.Name;
END;
$$ LANGUAGE plpgsql;


----------------------------------------------------------------------------------------------------------------
-- Q4
CREATE OR REPLACE FUNCTION Q4(GameName TEXT, PokemonName TEXT, DefendingPokemon TEXT)
RETURNS TABLE (
    MoveID INTEGER,
    MoveName TEXT,
    LearningMethod TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        M.ID AS MoveID,
        M.Name AS MoveName,
        string_agg(R.Assertion, ' OR ' ORDER BY R.ID) AS LearningMethod
    FROM
        Moves M
    JOIN Learnable_Moves LM ON LM.Learns = M.ID
    JOIN Pokemon P ON LM.Learnt_By = P.ID
    JOIN Games G ON LM.Learnt_In = G.ID
    JOIN Requirements R on LM.Learnt_When = R.ID
    WHERE
        P.Name = PokemonName
        AND G.Name = GameName
        AND M.Power != 0
    GROUP BY
        M.ID, M.Name
    ORDER BY
        CalcEffectivePower(PokemonName, M.Name, DefendingPokemon) DESC, M.Name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CalcEffectivePower(AttackingPokemon TEXT, MoveName TEXT, DefendingPokemon TEXT)
RETURNS INTEGER AS $$
DECLARE
    EffectivePower INTEGER;
    MovePower INTEGER;
    StabBonus NUMERIC;
    TypeEffectiveness1Multiplier NUMERIC;
    TypeEffectiveness2Multiplier NUMERIC;
    AttackingType TEXT[];
BEGIN
    -- Get move power
    SELECT COALESCE(M.Power, 0) INTO MovePower
    FROM Moves M
    WHERE M.Name = MoveName;

    -- Get stab bonus
    SELECT
        CASE 
            WHEN M.Of_Type = P1.First_Type OR M.Of_Type = P1.Second_Type THEN 1.5
            ELSE 1
        END
    INTO StabBonus
    FROM Moves M
    JOIN Pokemon P1 ON P1.Name = AttackingPokemon 
        WHERE M.Name = MoveName;

    -- Get type effectiveness 1 multiplier
    SELECT COALESCE(MAX(ETC1.Multiplier), 100)  -- Default to 100 if ETC1.Multiplier is NULL
    INTO TypeEffectiveness1Multiplier
    FROM Moves M
    JOIN Pokemon P2 ON P2.Name = DefendingPokemon
    LEFT JOIN Type_Effectiveness ETC1 ON ETC1.Attacking = M.Of_Type AND ETC1.Defending = P2.First_Type
    WHERE M.Name = MoveName;

    -- Get type effectiveness 2 multiplier
    SELECT COALESCE(MAX(ETC2.Multiplier), 100)  -- Default to 100 if ETC2.Multiplier is NULL
    INTO TypeEffectiveness2Multiplier
    FROM Moves M
    JOIN Pokemon P2 ON P2.Name = DefendingPokemon
    LEFT JOIN Type_Effectiveness ETC2 ON ETC2.Attacking = M.Of_Type AND ETC2.Defending = P2.Second_Type
    WHERE M.Name = MoveName;

    EffectivePower := FLOOR(MovePower * StabBonus * TypeEffectiveness1Multiplier * TypeEffectiveness2Multiplier/100);
    EffectivePower := EffectivePower / 100;
    RETURN EffectivePower;
END;
$$ LANGUAGE plpgsql;



----------------------------------------------------------------------------------------------------------------
-- Q5
CREATE OR REPLACE FUNCTION GetEvolutionChain(PokemonName TEXT, direction TEXT)
RETURNS TABLE(
    EvolutionPokemon TEXT, 
    EvolutionID INTEGER, 
    requirements TEXT[]) 
AS $$
BEGIN
    IF direction = 'backward' THEN
        RETURN QUERY SELECT 
            (SELECT Name FROM Pokemon WHERE ID = E.pre_evolution) AS EvolutionPokemon, 
            E.ID AS EvolutionID, 
            ARRAY(
                SELECT CASE 
                                    WHEN ER.Inverted = FALSE THEN R.Assertion
                                    ELSE 'NOT ' || R.Assertion
                                END
                FROM Evolution_Requirements ER 
                JOIN Requirements R ON ER.Requirement = R.ID
                WHERE ER.Evolution = E.ID
                ORDER BY ER.Inverted, R.ID
            ) AS requirements
        FROM Evolutions E
        WHERE E.post_evolution = (SELECT ID FROM Pokemon WHERE Name = PokemonName);
    ELSE
        RETURN QUERY SELECT 
            (SELECT Name FROM Pokemon WHERE ID = E.post_evolution) AS EvolutionPokemon, 
            E.ID AS EvolutionID, 
            ARRAY(
                SELECT CASE 
                                    WHEN ER.Inverted = FALSE THEN R.Assertion
                                    ELSE 'NOT ' || R.Assertion
                                END
                FROM Evolution_Requirements ER 
                JOIN Requirements R ON ER.Requirement = R.ID
                WHERE ER.Evolution = E.ID
                ORDER BY ER.Inverted, R.ID
            ) AS requirements
        FROM Evolutions E
        WHERE E.pre_evolution = (SELECT ID FROM Pokemon WHERE Name = PokemonName);
    END IF;
END;
$$
LANGUAGE plpgsql;

----------------------------------------------------------------------------------------------------------------