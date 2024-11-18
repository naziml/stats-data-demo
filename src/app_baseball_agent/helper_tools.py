from llama_index.tools.azure_code_interpreter import AzureCodeInterpreterToolSpec
from llama_index.core.tools import ToolMetadata
from pydantic import BaseModel


# these get used in baseball_agent.py putting here for cleaner code
class InferenceRequest(BaseModel):
    query: str

class InferenceResponse(BaseModel):
    response: str
    metadata: dict


class CodeInferenceRequest(BaseModel):
    code: str

class CodeInferenceResponse(BaseModel):
    response: dict


class ModelRequest(BaseModel):
    omodel_name: str


# provide a custom implementation of the AzureCodeInterpreterToolSpec for image retrieval
class CustomAzureCodeInterpreterToolSpec(AzureCodeInterpreterToolSpec):
    def __init__(self, pool_management_endpoint, metadata: ToolMetadata, local_save_path="images"):
        super().__init__(pool_management_endpoint, local_save_path)
        self.metadata = metadata


    def code_interpreter(self, python_code: str) -> dict:
        """
        Use this to fetch an image, write python code to fetch the image from https://www.baseball-reference.com/players/a/{PLAYERID}.shtml. 
        Where PLAYERID is the playerid from the database. Download all the images which have /images/headshots/ as part of their directory location and save them.
        Use whatever libraries you believe are most appropriate to accomplish this task. Return the image names you were able to retrieve. Save the images in the /mnt/data/images directory.
        """
        code_run = super().code_interpreter(python_code)
        code_run['files'] = self.list_files()
        return code_run


# direct use tool
class AzureACASessionsSecureExecutor(AzureCodeInterpreterToolSpec):
    def __init__(self, pool_management_endpoint, metadata: ToolMetadata, local_save_path="images"):
        super().__init__(pool_management_endpoint, local_save_path)
        self.metadata = metadata


    def code_interpreter(self, python_code: str) -> dict:
        code_run = super().code_interpreter(python_code)
        code_run['files'] = self.list_files()
        return code_run

    # INFO: this uses the default prompt which is likely better
    """ 
    def code_interpreter(self, python_code: str) -> dict:
        "
        Run arbitrary Python code and return the result along with the agent reasoning loop.
        "
        result = super().code_interpreter(python_code)
        return result
    """



baseball_tool_metadata_str = """
## The Tool

This tool provides access to the data described below. All data is in a SQL database and needs to be retrieved using SQL statements. Sometimes this might mean joining several tables to get the best and most user friendly result.


## The Data

The design follows these general principles. Each player is assigned a
unique ID (playerid). All of the information relating to that player
is tagged with his playerid. The playerids are linked to names and
birthdates in the master table. There are several tables that contain the 
data. Here are the main tables:

    master_csv - Player names, DOB, and biographical information
    batting_csv - Batting statistics
    pitching_csv - Pitching statistics
    fielding_csv - Fielding statistics

Other tables covering everything from teams, franchises, post-season appearances to awards won by players are also available.
"""


# ignore for now
"""
## Table Overview

### Main Tables

The database is comprised of the following main tables:

    master_csv - Player names, DOB, and biographical information
    batting_csv - Batting statistics
    pitching_csv - Pitching statistics
    fielding_csv - Fielding statistics


### Supplement Tables

It is supplemented by these tables:
    allstarfull_csv - All-Star appearances
    halloffame_csv - Hall of Fame voting data
    managers_csv - Managerial statistics
    teams_csv - Yearly stats and standings
    battingpost_csv - Post-season batting statistics
    pitchingpost_csv - Post-season pitching statistics
    teamfranchises_csv - Franchise information
    fieldingof_csv - Outfield position data
    fieldingpost_csv - Post-season fielding data
    managershalf_csv - Split season data for managers
    teamshalf_csv - Split season data for teams
    salaries_csv - Player salary data
    seriespost_csv - Post-season series information
    awardsmanagers_csv - Awards won by managers
    awardsplayers_csv - Awards won by players
    awardssharemanagers_csv - Award voting for manager awards
    awardsshareplayers_csv - Award voting for player awards
    appearances_csv - Details on the positions a player appeared at
    schools_csv - List of colleges that players attended
    collegeplaying_csv - List of players and the colleges they attended


## Main Table Details


file_name: Master.csv
file_data_url: https://raw.githubusercontent.com/Azure-Samples/stats-data-demo/refs/heads/main/data/baseball_databank/Master.csv
table: master_csv
file_description: Player names, DOB, and biographical information. With the following fields/columns\n
  playerid = player_id
  birthyear = birth_year
  birthmonth = birth_month
  birthday = birth_day
  birthcountry = birth_country
  birthstate = birth_state
  birthcity = birth_city
  deathyear = death_year
  deathmonth = death_month
  deathday = death_day
  deathcountry = death_country
  deathstate = death_state
  deathcity = death_city
  namefirst = first_name
  namelast = last_name
  namegiven = given_name
  weight = weight
  height = height
  bats = bats
  throws = throws
  debut = debut
  finalgame = final_game
  retroid = retro_id
  bbrefid = bbref_id


file_name: Batting.csv
file_data_url: https://raw.githubusercontent.com/Azure-Samples/stats-data-demo/refs/heads/main/data/baseball_databank/Batting.csv
table: batting_csv
file_description: Batting statistics. With the following fields/columns\n
  playerid = player_id
  yearid = year_id
  stint = stint
  teamid = team_id
  lgid = league_id
  g = games
  ab = at_bats
  r = runs
  h = hits
  2b = doubles
  3b = triples
  hr = home_runs
  rbi = runs_batted_in
  sb = stolen_bases
  cs = caught_stealing
  bb = walks
  so = strikeouts
  ibb = intentional_walks
  hbp = hit_by_pitch
  sh = sacrifice_hits
  sf = sacrifice_flies
  gidp = grounded_into_double_play


file_name: Fielding.csv
file_data_url: https://raw.githubusercontent.com/Azure-Samples/stats-data-demo/refs/heads/main/data/baseball_databank/Fielding.csv
table: fielding_csv
file_description: Fielding statistics. With the following fields/columns\n
  playerid = player_id
  yearid = year_id
  stint = stint
  teamid = team_id
  lgid = league_id
  pos = position
  g = games
  gs = games_started
  innouts = innings_outs
  po = putouts
  a = assists
  e = errors
  dp = double_plays
  pb = passed_balls
  wp = wild_pitches
  sb = stolen_bases_allowed
  cs = caught_stealing_allowed
  zr = zone_rating
"""