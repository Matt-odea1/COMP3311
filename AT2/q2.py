"""
COMP3311
24T1
Assignment 2
Pokemon Database

Written by: Matthew O'Dea z5413887
Written on: 15/04/24

File Name: Q2

Description: List all locations where a specific pokemon can be found
"""


import sys
import psycopg2
from helpers import exists

### Constants
USAGE = f"Usage: {sys.argv[0]} <pokemon_name>"


def main(db):
    if len(sys.argv) != 2:
        print(USAGE)
        return 1

    pokemon_name = sys.argv[1]
    cursor = db.cursor()
    exists(cursor,pokemon_name)
    
    cursor.execute("""
        SELECT EXISTS (
            SELECT 1 
            FROM Encounters 
            WHERE Encounters.Occurs_With = (SELECT ID FROM Pokemon WHERE Name = %s)
        )
    """, (pokemon_name,))  # Pass the Pokemon name as an argument
    has_encounters = cursor.fetchone()[0]

    if not has_encounters:
        print(f"Pokemon \"{pokemon_name}\" is not encounterable in any game")
        sys.exit()

# ===============================================================================================================================================

    headers = ["Region", "Game", "Location", "Rarity", 
           "MinLevel", "MaxLevel", 
           "Requirements"]

    cursor.callproc('Q2', [pokemon_name])
    result = cursor.fetchall()

    # Calculate column widths excluding the first column ("Region")
    column_widths = [len(header) for header in headers[1:]]

    for row in result:
        for i, item in enumerate(row[1:]):  # Start from the second item to skip "Region"
            column_widths[i] = max(column_widths[i], len(str(item)))

    # Print headers excluding the first column ("Region")
    print(" ".join(f"{header:<{width}}" for header, width in zip(headers[1:], column_widths)))

    # Print encounters excluding the first column ("Region")
    for encounter in result:
        print(" ".join(f"{str(item):<{width}}" for item, width in zip(encounter[1:], column_widths)))

# ===============================================================================================================================================


if __name__ == '__main__':
    exit_code = 0
    db = None
    try:
        db = psycopg2.connect(dbname="pkmon")
        exit_code = main(db)
    except psycopg2.Error as err:
        print("DB error: ", err)
        exit_code = 1
    except Exception as err:
        print("Internal Error: ", err)
        raise err
    finally:
        if db is not None:
            db.close()
    sys.exit(exit_code)
