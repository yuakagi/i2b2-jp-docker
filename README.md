# i2b2-UT-demo

### Attributions

This project is derived from the open-source repository: i2b2/i2b2-docker (https://github.com/i2b2/i2b2-docker)
The original code is licensed under the Apache License 2.0.
This repository includes modifications and extensions for research and deployment purposes.

## Clone repo

git clone https://github.com/yuakagi/i2b2-UT-demo

## Steps for Setting Up i2b2 Postgres (Ubuntu)

1. Navigate to the i2b2-docker directory.
2. Execute the following command to start the i2b2:

```
cd pg
docker-compose up -d i2b2-webclient
```

3. Wait for WildFly to start.
4. Open a web browser and navigate to the following URL:

```
http://<your host IP etc>/webclient
```

5. Log in to the i2b2 web application using the default credentials:
      - Username: demo
      - Password: demouser

** Access to PostgreSQL DB **
You can access to the DB by IP, port, username and password

1. Expose the DB port in docker-compose.yml file.
2. Access to the DB using your IP and port
3. Authenticate with your username and password. The default user is 'i2b2' and password is 'demouser'.

# Other notes (from the original repo)
username is demo
password is i2b2cdiDemo@2020

# How to use Admin Site?
1. Log in as an 'admin' user.
   By default, the user ID is i2b2 and password is demouser.
   Change the ID and passward in .env file for security.
2. Click 'Analysis Tools', and select 'ADMIN' from the Category dropdown.
3. Now, the Admin site is availabe as a plugin.
