import pytest
from httpx import AsyncClient
from baseball_agent import app

@pytest.mark.asyncio
async def test_list_models():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/list_models")
    assert response.status_code == 200
    assert "models" in response.json()