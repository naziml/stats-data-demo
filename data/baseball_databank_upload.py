#!/usr/bin/env python

import json
import os
import sys
import asyncio
import aiohttp

def check_file_exists(file_path):
    if not os.path.isfile(file_path):
        print(f"Error: File not found - {file_path}")
        sys.exit(1)

async def upload_file(session, url, file_path, file_name, file_description, debug):
    if debug:
        curl_command = (
            f'curl -X POST "{url}" '
            f'-F "file_data=@{file_path}" '
            f'-F "file_name={file_name}" '
            f'-F "file_description={file_description}"'
        )
        print(curl_command)
    else:
        with open(file_path, 'rb') as file_data:
            form_data = aiohttp.FormData()
            form_data.add_field('file_data', file_data, filename=file_name)
            form_data.add_field('file_name', file_name)
            form_data.add_field('file_description', file_description)
            
            async with session.post(url, data=form_data) as response:
                if response.status == 200:
                    print(f"Successfully uploaded {file_name}")
                else:
                    print(f"Failed to upload {file_name}: {response.status}")

async def main(directory, endpoint, debug):
    with open('baseball_databank.json', 'r') as f:
        data_blocks = json.load(f)
    
    async with aiohttp.ClientSession() as session:
        tasks = []
        for block in data_blocks:
            file_name = block['file_name']
            file_path = os.path.join(directory, file_name)
            check_file_exists(file_path)  # Check if the file exists
            file_description = block['file_description']
            tasks.append(upload_file(session, endpoint, file_path, file_name, file_description, debug))
        
        await asyncio.gather(*tasks)

if __name__ == "__main__":
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print("Usage: python script.py <directory> <endpoint> [--debug]")
        sys.exit(1)
    
    directory = sys.argv[1]
    endpoint = sys.argv[2]
    debug = '--debug' in sys.argv
    
    asyncio.run(main(directory, endpoint, debug))