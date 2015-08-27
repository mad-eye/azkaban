Azkaban
=======

Azkaban coordinates the dementors, and web users to communicate with them.

Azkaban acts as the hub between the dementors, apogee, mongo, and bolide.

## Creating a Docker Image

1. `git submodule update --init --recrusive`

2. `docker build --tag azkaban:dev .`
