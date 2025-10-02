# Xdebug Setup for bu-wp-docker

## Enable Xdebug in the container
Set the `XDEBUG` environment variable to `true` in your `.env` file:

```env
XDEBUG=true
```

This will cause the existing build to install and configure xdebug when the container is initialized.

## Attach VSCode to the container
Use the VSCode "Remote - Containers" extension to attach to the running container.

- Go to the Containers view
- Right-click the bu-wordpress container
- Choose "Attach Visual Studio Code"

## Install Xdebug VSCode Extension

Install the "PHP Debug" extension in VSCode in the container, https://marketplace.visualstudio.com/items?itemName=xdebug.php-debug

## Setup launch.json configuration for VSCode

Create a `.vscode` directory in your project root (if it doesn't exist) and add a `launch.json` file with the following content:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Xdebug listen",
            "type": "php",
            "request": "launch",
            "port": 9003,
            "pathMappings": {
                "/var/www/html/": "${workspaceRoot}/"
            }
        }
    ]
}
```
