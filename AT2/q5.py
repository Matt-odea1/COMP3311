#! /usr/bin/env python3


"""
COMP3311
24T1
Assignment 2
Pokemon Database

Written by: Matt O'Dea z5413887
Written on: 22/04/24

File Name: Q5

Description: Print a formatted (recursorsive) evolution chain for a given pokemon
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

# ===============================================================================================================================================

    # Print the evolution chain
    cursor = db.cursor()
    exists(cursor,pokemon_name)
    print_evolutions_back(cursor, pokemon_name)
    print_evolutions_forward(cursor, pokemon_name)


# Printing forward evolutions
def print_evolutions_back(cursor, pokemon_name):
    cursor.callproc("GetEvolutionChain", (pokemon_name, 'backward')) 
    evolutions = cursor.fetchall()
    merged_data = merge_duplicate_evolutions(evolutions)

    if not evolutions:
        print(f"\'{pokemon_name}\' doesn't have any pre-evolutions.\n")
    else:
        for evolution in merged_data:
            print(f"\'{pokemon_name}\' can evolve from \'{evolution[0]}\' when the following requirements are satisfied:")
            formatting_multiple_requirements(evolution)
            print()
            print_evolutions_back(cursor, evolution[0]) # call recursively until there are none left

# Printing backward evolutions. Could have integrated this with the above function but it's not a lot of code and the string formatting would be messy otherwise
def print_evolutions_forward(cursor, pokemon_name):
    cursor.callproc("GetEvolutionChain", (pokemon_name, 'forward')) 
    evolutions = cursor.fetchall()
    merged_data = merge_duplicate_evolutions(evolutions)

    if not evolutions:
        print(f"\'{pokemon_name}\' doesn't have any post-evolutions.\n")
    else:
        for evolution in merged_data:
            print(f"\'{pokemon_name}\' can evolve into \'{evolution[0]}\' when the following requirements are satisfied:")
            formatting_multiple_requirements(evolution)
            print()
            print_evolutions_forward(cursor, evolution[0])


# Dealing with the OR case - 2 rows in SQL query for the same pokemon, based on diff OR evolution requirements
def merge_duplicate_evolutions(evolutions):
    merged_evolutions = []
    seen_pokemons = {}

    for pokemon_name, _, requirements in evolutions:
        if pokemon_name not in seen_pokemons:
            # Not a dup, add to seen dictionary with requirements
            seen_pokemons[pokemon_name] = [(requirement, False) for requirement in requirements]

        else: # dups
            for requirement in requirements:
                # Look for existing requirement with the same text
                existing_requirements = seen_pokemons[pokemon_name]
                existing_requirement_texts = [req[0] for req in existing_requirements]
                if requirement not in existing_requirement_texts:
                    # New requirement, need to add to existing entry
                    seen_pokemons[pokemon_name].append((requirement, True)) # true flag means its a new req
                else:
                    existing_index = existing_requirement_texts.index(requirement)
                    seen_pokemons[pokemon_name][existing_index] = (requirement, False)


    # Create final list with merged data and remove second occurrences
    for pokemon_name, data in seen_pokemons.items():
        # Only add the first occurrence
        if pokemon_name not in [entry[0] for entry in merged_evolutions]:
            merged_evolutions.append((pokemon_name, None, data))

    return merged_evolutions


# Formatting. A bit messy but works. No hard coding
def formatting_multiple_requirements(evolution):
    count = 0
    for i in range(len(evolution[2])):
        if (evolution[2][i][1]):
            count+=1

    if count != 0:
        beforeReqs = len(evolution[2]) - count
        afterReqs = count

        if beforeReqs == 1:
            print("\t\t" + evolution[2][0][0])
            print("\tOR")
        elif beforeReqs >= 1:
            for i in range(beforeReqs - 1):
                print("\t\t\t" + evolution[2][i][0])
                print("\t\tAND")
            print("\t\t\t" + evolution[2][beforeReqs - 1][0])
            print("\tOR")

        if afterReqs == 1:
            print("\t\t" + evolution[2][count][0])
        elif afterReqs >= 1:
                for i in range(beforeReqs, len(evolution[2]) - 1):
                    print("\t\t\t" + evolution[2][i][0])
                    print("\t\tAND")
                print("\t\t\t" + evolution[2][-1][0])

    else:
        if len(evolution[2]) == 1:
            print("\t" + evolution[2][0][0])
        else:
            for i in range(len(evolution[2]) - 1):
                print("\t\t" + evolution[2][i][0])
                print("\tAND")
            print("\t\t" + evolution[2][-1][0])

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