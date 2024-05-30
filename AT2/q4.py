"""
COMP3311
24T1
Assignment 2
Pokemon Database

Written by: Matt O'Dea z5413887
Written on: 19/04/24

File Name: Q4

Description: Print the best move a given pokemon can use against a given type in a given game for each level from 1 to 100
"""
import sys
import psycopg2
from helpers import exists, in_game


def notice_handler(msg):
    print("NOTICE:", msg)
### Constants
USAGE = f"Usage: {sys.argv[0]} <Game> <Attacking Pokemon> <Defending Pokemon>"


def main(db):
    ### Command-line args
    if len(sys.argv) != 4:
        print(USAGE)
        return 1
    game_name = sys.argv[1]
    
    attacking_pokemon_name = sys.argv[2]
    defending_pokemon_name = sys.argv[3]
    cursor = db.cursor()

    # error checking
    exists(cursor, attacking_pokemon_name)
    exists(cursor, defending_pokemon_name)
    cursor.execute("SELECT EXISTS (SELECT 1 FROM Games WHERE Name = %s)", (game_name,))
    game_exists = cursor.fetchone()[0]
    if not game_exists:
        print(f"game {game_name} does not exist")
        sys.exit()
    in_game(cursor, game_name, attacking_pokemon_name)
    in_game(cursor, game_name, defending_pokemon_name)
    
# ===============================================================================================================================================

    cursor.callproc('Q4', [game_name, attacking_pokemon_name, defending_pokemon_name])
    result = cursor.fetchall()
    if len(result) == 0:
        print(f"No moves found for \"{attacking_pokemon_name}\" against \"{defending_pokemon_name}\" in \"{game_name}\"")
        sys.exit()
    
    print(f"If \"{attacking_pokemon_name}\" attacks \"{defending_pokemon_name}\" in \"{game_name}\" it's available moves are:")
    for row in result:
        cursor.callproc('CalcEffectivePower', [attacking_pokemon_name, row[1], defending_pokemon_name])
        result2 = cursor.fetchall()
        print("\t" + row[1])
        print("\t\twould have a relative power of " + str(result2[0][0]))
        print("\t\tand can be learnt from " + row[2])

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
