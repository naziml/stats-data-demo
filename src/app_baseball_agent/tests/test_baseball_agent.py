import pytest
import logging
from app_baseball_agent import list_models

logging.basicConfig(level=logging.INFO)

@pytest.fixture
def setup():
    # Setup code if needed
    pass

def test_list_models(setup):
    try:
        result = await list_models()  # Ensure the function is awaited
        assert isinstance(result, list)  # Check if the result is a list
    except Exception as e:
        logging.error(f"Error occurred: {e}")
        assert False, "list_models raised an exception"