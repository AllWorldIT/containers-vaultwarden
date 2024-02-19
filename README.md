[![pipeline status](https://gitlab.conarx.tech/containers/vaultwarden/badges/main/pipeline.svg)](https://gitlab.conarx.tech/containers/vaultwarden/-/commits/main)

# Container Information

[Container Source](https://gitlab.conarx.tech/containers/vaultwarden) - [GitHub Mirror](https://github.com/AllWorldIT/containers-vaultwarden)

This is the Conarx Containers Minio image, it provides the Minio S3 server and Minio Client within the same Docker image.



# Mirrors

|  Provider  |  Repository                                 |
|------------|---------------------------------------------|
| DockerHub  | allworldit/vaultwarden                      |
| Conarx     | registry.conarx.tech/containers/vaultwarden |



# Conarx Containers

All our Docker images are part of our Conarx Containers product line. Images are generally based on Alpine Linux and track the
Alpine Linux major and minor version in the format of `vXX.YY`.

Images built from source track both the Alpine Linux major and minor versions in addition to the main software component being
built in the format of `vXX.YY-AA.BB`, where `AA.BB` is the main software component version.

Our images are built using our Flexible Docker Containers framework which includes the below features...

- Flexible container initialization and startup
- Integrated unit testing
- Advanced multi-service health checks
- Native IPv6 support for all containers
- Debugging options



# Community Support

Please use the project [Issue Tracker](https://gitlab.conarx.tech/containers/vaultwarden/-/issues).



# Commercial Support

Commercial support for all our Docker images is available from [Conarx](https://conarx.tech).

We also provide consulting services to create and maintain Docker images to meet your exact needs.



# Environment Variables

Additional environment variables are available from...
* [Conarx Containers Postfix image](https://gitlab.conarx.tech/containers/postfix)
* [Conarx Containers Alpine image](https://gitlab.conarx.tech/containers/alpine)

VaultWarden environment variables are prefeixed with `VAULTWARDEN_` and will be exported to the VaultWarden vaultwarden.env config
file during startup if it doesn't already exist.


## VAULTWARDEN_ADMIN_TOKEN

Can be set using `openssl rand -base64 48`, then paste into `argon2 $(openssl rand -base64 8) -e`. Copy the resulting text.


## VAULTWARDEN_DATABASE_TYPE

VaultWarden database type, either `mariadb`, `mysql`, `postgresql` or `sqlite`.

For the Sqlite database type, the database will be created as `/var/lib/vaultwarden/vaultwarden.sqlite`.

## MYSQL_HOST, MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD

Database credentials if `VAULTWARDEN_DATABASE_TYPE` is set to `mariadb` or `mysql`.

## POSTGRES_HOST, POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD

Database credentials if `VAULTWARDEN_DATABASE_TYPE` is set to `postgresql`.



## VAULTWARDEN_OPTS

Special options to be passed along with `kc start`, these options are appended to the end of this command.


## VAULTWARDEN_*

All other environment variables beginning with `VAULTWARDEN_` will be passed to VaultWarden without the prefix.



# Configuration

Configuration files of note can be found below...

| Path                                                         | Description                                               |
|--------------------------------------------------------------|-----------------------------------------------------------|
| /etc/vaultwarden/vaultwarden.env                             | VaultWarden configuration                                 |

The configuration file is constructed from the ENV passed to the container only if the path doesn't already exist.


# Volumes


## /var/lib/vaultwarden

VaultWarden data directory.



# Exposed Ports

VaultWarden port 8080 is exposed.



# Configuration Exampmle


```yaml
version: '3.9'

services:
...

networks:
  internal:
    driver: bridge
    enable_ipv6: true
```