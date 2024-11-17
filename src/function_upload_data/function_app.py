import azure.functions as func
import logging
from azure.eventhub import EventHubProducerClient, EventData
from azure.storage.blob import BlobServiceClient, BlobSasPermissions, generate_blob_sas
import os
import base64
import json
from datetime import datetime, timedelta, timezone
import pandas as pd
import time
import io

# inference
#import aiohttp
import asyncio
import json
import os
import logging


app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

EVENTHUB_CONNECTION_STR = os.getenv("EVENTHUB_CONNECTION_STR")
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME_INGEST")
BATCH_SIZE = 1000
PRODUCER = EventHubProducerClient.from_connection_string(EVENTHUB_CONNECTION_STR, eventhub_name=EVENTHUB_NAME)
STORAGE_CONNECTION_STR = os.getenv("AzureWebJobsStorage")
STORAGE_CONTAINER_CSV = os.getenv("STORAGE_CONTAINER_CSV")


# accept a file and store it in either eventhub or storage
@app.function_name(name="upload_data")
@app.route(route="upload_data", methods=["POST"])
@app.event_hub_output(arg_name="outevent", 
                      event_hub_name=EVENTHUB_NAME, 
                      connection="EVENTHUB_CONNECTION_STR")

def upload_data(req: func.HttpRequest, outevent: func.Out[str]) -> func.HttpResponse:
    try:
        # Extract input data from the request
        file_data = req.files.get('file_data')
        file_name = req.form.get('file_name')
        file_description = req.form.get('file_description')
        logging.info(f"Received file: {file_name}.")

        if not file_data or not file_name:
            return func.HttpResponse("Missing file_data or file_name in the request.\n", status_code=400)

        # Read binary data from the file_data object
        binary_filedata = file_data.read()
        csv_data = io.BytesIO(binary_filedata)
        csv_df = pd.read_csv(csv_data, nrows=2)
        #logging.info("csv_df: ", csv_df.info())
        header = [h.lower() for h in csv_df.columns.tolist()]
        messages = []

        file_url = _upload_to_blob(binary_filedata, file_name)

        message = {
            "file_name": file_name,
            "table_name": file_name.replace(".", "_").lower(),
            "timestamp": datetime.now().isoformat(),
            "header": header,
            "file_description": file_description,
            "file_url": file_url
        }
        message_str = json.dumps(message)
        outevent.set(message_str)

        return func.HttpResponse(f"File {file_name} processed and added to the queue.\n", status_code=200)

    except Exception as e:
        logging.error(f"Error processing request: {e}")
        return func.HttpResponse("Error processing request.\n", status_code=500)
    

# TODO make this async
def _upload_to_blob(file_data, file_name):
    blob_service_client = BlobServiceClient.from_connection_string(STORAGE_CONNECTION_STR)
    container_client = blob_service_client.get_container_client(STORAGE_CONTAINER_CSV)
    try:
        blob_client = container_client.get_blob_client(file_name)
        blob_client.upload_blob(file_data, overwrite=True)
        sas_token = generate_blob_sas(
            account_name=blob_service_client.account_name,
            container_name=STORAGE_CONTAINER_CSV,
            blob_name=file_name,
            account_key=blob_service_client.credential.account_key,
            permission=BlobSasPermissions(read=True),
            expiry=datetime.now(timezone.utc) + timedelta(hours=12)  # SAS token valid for 1 hour
        )
        return blob_client.url + "?" + sas_token
    except Exception as e:
        logging.error(f"Error uploading file {file_name} to Azure Blob Storage: {e}")
        raise
