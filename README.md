# LaTeX Dev Container

A LaTeX development container for use with VSCode Remote Containers. Inspired
from: https://github.com/qdm12/latexdevcontainer

Modified to account for different UID/GID on host machine, as well as a custom base image.

Images are available on Docker Hub: https://hub.docker.com/r/dlrobson/latex-dev-container

# Create a Dev Image

Run:
```bash
docker build --progress=plain \
    -t docker.io/dlrobson/latex-dev-container:latest .
```
