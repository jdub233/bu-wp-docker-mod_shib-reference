# BU WordPress Docker with Shibboleth

This is a reference repository for BU WordPress Docker with a complete Apache mod_shib setup. It can be used as a local development environment or as a base for production deployments.  We are anticipating that we will not use this, but use a shibboleth-sp proxy layer in front of a WordPress container without mod_shib installed, as mod_shib and Apache can be a maintenance burden.  So don't expect to use this long term. But is fully functional for now, and can be used for local development.

> ⚠️ **REFERENCE REPOSITORY ONLY**  
> This repository is a reference for BU WordPress Docker with mod_shib.  
> **Do not expect to use this long term.**  
>  
> This is a replica of the main code trunk in `whennemuth/bu-wp-docker`, specifically for retaining the mod_shib setup.  
> Keeping this reference enables us to drop mod_shib complexity from the main repo, while still having a working example for local development and future use if needed.

## How to Build and Run the WordPress Container for local development

This guide will help you set up and run the project from a fresh clone of the repository. Follow these steps to get started:

### Setup prerequisites
- Get a personal access token (PAT) from GitHub with appropriate permissions to access the repositories: here is a guide on [creating a PAT](https://dev.to/warnerbell/how-to-generate-a-github-personal-access-token-pat-1bg5)
- Set up an entry in /etc/hosts for the local container (replace "username" with your username)
    - Example for macOS or Linux /etc/hosts entry:
        ```
        127.0.0.1   username.local
        ```
        You can have multiple entries for different environments (pretty much any hostname should work). With the S3 integration, the location of the media library in the bucket will reflect the hostname you use.

    - macOS commands to edit /etc/hosts and flush the DNS cache:
        ```bash
        sudo nano /etc/hosts
        dscacheutil -flushcache
        ```
- Get a .env file with the right environment variables, with S3 access key and shibboleth keys; there is an example .env file in `.env.example`, or you can ask a team member for a copy of a working .env file.

### Build or pull the image

To build the image locally, run:

```bash
npm run build
```
or click the build button in the NPM Scripts tab in VSCode. The npm build script is just a wrapper around a simple docker build command, check the package.json file for details.

( Check out this article on the NPM Scripts tab in VSCode:
https://www.luisllamas.es/en/how-to-use-vscode-with-npm/ )

Alternatively, you can set the DOCKER_REGISTRY environment variable in the .env file to point to a private AWS ECR repo, and then pull an existing image from there.

### Run the containers

```bash
npm run start
```
or click the start button in the NPM Scripts tab in VSCode (or run `docker-compose up -d` directly).

Your WordPress site will be available at https://username.local (or whatever hostname you set in the .env file and /etc/hosts).

The https is set up with a self-signed certificate for local development, you will need to override the browser warning.

At this point you can check the logs on the WordPress container and see how the entrypoint script initializes the configuration details in the container.

### Setup admin and content

- Get a shell on the wordpress container:
    ```bash
    npm run shell
    ```
   (or `docker compose exec wordpress bash` directly)

- You can create a new user for yourself just by going the wp-admin page of your local site, you will be prompted to login with BU shibboleth, and then a user will be created for you automatically. You can also create a user manually like so (replace "username" and "username@bu.edu" with your login details):
    ```bash
    wp user create username username@bu.edu --role=administrator
    ```
- You can then make yourself a super admin like so (replace "username" with your username):
    ```bash
    wp super-admin add username@bu.edu
    ```
    Once you have created the user, you can log in to the WordPress admin at https://username.local/wp-admin

- Optional: Clone the admissions site to your local instance (replace "username.local" with your local hostname):
    ```bash
    wp site-manager snapshot-pull --source=http://www.bu.edu/admissions --destination=http://username.local/admissions
    ```

That's it you are done!

### Next steps

#### Attach vscode to the container

- Go to the Containers view
- Right-click the bu-wordpress container
- Choose "Attach Visual Studio Code"

#### Enable Xdebug in the container

Xdebug can be enabled by setting the environment variable `XDEBUG=true` in the .env file, see [the Xdebug guide](docs/xdebug.md) for more details.

#### Stop the containers

```bash
npm run stop
```
or click the stop button in the NPM Scripts tab in VSCode.

#### Destroy the database and start fresh

```bash
docker volume rm bu-wp-docker-mod_shib-reference_db_data
```

### Note for Windows users

On Windows, changing EXPORT to SET seems to work for setting environment variables in the command prompt.


