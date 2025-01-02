FROM ubuntu:latest
LABEL org.opencontainers.image.authors="Ugo Pattacini <ugo.pattacini@iit.it>"

# Non-interactive installation mode
ENV DEBIAN_FRONTEND=noninteractive

# Update apt database
RUN apt update

# Increment this variable to force Docker to build the image for the sections below w/o relying on cache
ENV INVALIDATE_DOCKER_CACHE=0

# Install essentials
RUN apt install -y apt-utils software-properties-common apt-transport-https sudo psmisc \
    lsb-release wget git ruby

# Install gems
RUN gem install octokit yaml

# Create user codespace
RUN useradd -l -u 33333 -G sudo -md /home/codespace -s /bin/bash -p codespace codespace && \
    # passwordless sudo for users in the 'sudo' group
    sed -i.bkp -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers

# Clean up unnecessary installation products
RUN rm -Rf /var/lib/apt/lists/*

# Launch bash from /workspaces
WORKDIR /workspaces
CMD ["bash"]
