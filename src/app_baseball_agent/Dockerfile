# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set environment variables
ENV POETRY_VERSION=1.8.4

# Install Poetry
RUN pip install "poetry==$POETRY_VERSION"

# Set the working directory in the container
WORKDIR /app

# Copy the pyproject.toml and poetry.lock files to the container
COPY pyproject.toml poetry.lock ./

# Install the dependencies
RUN poetry install --no-dev

# Copy the rest of the application code to the container
COPY . .

EXPOSE 8000

# using gunicorn
# CMD ["poetry", "run", "uvicorn", "baseball_agent:app", "--host", "0.0.0.0"]
CMD ["poetry", "run", "gunicorn", "-k", "uvicorn.workers.UvicornWorker", "baseball_agent:app", "--workers", "4", "--bind", "0.0.0.0"]