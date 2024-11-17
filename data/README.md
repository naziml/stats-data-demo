


> This directory holds the data for this app. The current data originates from https://www.kaggle.com/datasets/open-source-sports/baseball-databank/data



# Upload of Data

Ensure you have `asyncio` and `aiohttp` installed from where you are running this from. Install them with:

```bash
pip install asyncio aiohttp
```

## Endpoint Upload

To upload the files listed in `baseball_databank.json` to your provided endpoint run the following command:

```bash
./baseball_databank_upload.py baseball_databank http://localhost:7071/api/upload_data
```



## Debug Mode

To simply produce curl commands you can run yourself use this command:

```bash
baseball_databank_upload.py baseball_databank http://localhost:7071/api/upload_data --debug
```

This produces the following output.

```bash
curl -X POST "http://localhost:7071/api/upload_data" -F "file_data=@baseball_databank/Master.csv" -F "file_name=Master.csv" -F "file_description=Player names, DOB, and biographical information. With the following fields/columns: playerid = player_id, birthyear = birth_year, birthmonth = birth_month, birthday = birth_day, birthcountry = birth_country, birthstate = birth_state, birthcity = birth_city, deathyear = death_year, deathmonth = death_month, deathday = death_day, deathcountry = death_country, deathstate = death_state, deathcity = death_city, namefirst = first_name, namelast = last_name, namegiven = given_name, weight = weight, height = height, bats = bats, throws = throws, debut = debut, finalgame = final_game, retroid = retro_id, bbrefid = bbref_id"
curl -X POST "http://localhost:7071/api/upload_data" -F "file_data=@baseball_databank/Batting.csv" -F "file_name=Batting.csv" -F "file_description=Batting statistics. With the following fields/columns: playerid = player_id, yearid = year_id, stint = stint, teamid = team_id, lgid = league_id, g = games, ab = at_bats, r = runs, h = hits, 2b = doubles, 3b = triples, hr = home_runs, rbi = runs_batted_in, sb = stolen_bases, cs = caught_stealing, bb = walks, so = strikeouts, ibb = intentional_walks, hbp = hit_by_pitch, sh = sacrifice_hits, sf = sacrifice_flies, gidp = grounded_into_double_play"
curl -X POST "http://localhost:7071/api/upload_data" -F "file_data=@baseball_databank/Fielding.csv" -F "file_name=Fielding.csv" -F "file_description=Fielding statistics. With the following fields/columns: playerid = player_id, yearid = year_id, stint = stint, teamid = team_id, lgid = league_id, pos = position, g = games, gs = games_started, innouts = innings_outs, po = putouts, a = assists, e = errors, dp = double_plays, pb = passed_balls, wp = wild_pitches, sb = stolen_bases_allowed, cs = caught_stealing_allowed, zr = zone_rating"
```
