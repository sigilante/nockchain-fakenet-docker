# `nockchain-fakenet-docker`

This repository contains a Docker setup for running a local fakenet of Nockchain nodes using `nockchain-fakenet`. This setup is useful for NockApp application development, testing, and experimentation with Nockchain without needing to connect to the livenet.

**Status:**  🚧 Work in Progress 🚧

![](./img/hero.png)

## Prerequisites

* Docker installed on your machine

## Setup

To get started with the Nockchain fakenet Docker setup, follow these steps:

1. Clone this repository to your local machine:

    ```bash
    git clone https://github.com/sigilante/nockchain-fakenet-docker.git
    cd nockchain-fakenet-docker
    ```

2. Build the Docker image:

    ```bash
    docker build -t nockchain-fakenet .
    ```

3. Run the Docker container:

    ```bash
    docker run -d --name nock-fakenet -p 3000:3000 nockchain-fakenet
    ```

4. Access the fakenet:

    You can access the fakenet API at `http://localhost:3000`.

## References

- [NockApp Development and Testing](https://docs.nockchain.org/nockapp/what-is-nockapp/development-and-testing)
