FROM python:3.11-slim

WORKDIR /code

COPY ./requirements.txt /code/requirements.txt

RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

COPY ./app /code/app

# Create a directory for the sqlite db to ensure permissions
RUN mkdir -p /code/data

# Environment variable for database so we can override it if needed, but default to local file
ENV SQLALCHEMY_DATABASE_URL="sqlite:////code/data/sql_app.db"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
