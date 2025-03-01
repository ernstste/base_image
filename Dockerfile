# This file builds a Docker base image for its use in other projects

# Copyright (C) 2020-2021 Gergely Padányi-Gulyás (github user fegyi001),
#                         David Frantz
#                         Fabian Lehmann

FROM ubuntu:20.04 as builder

# disable interactive frontends
ENV DEBIAN_FRONTEND=noninteractive 

# Refresh package list & upgrade existing packages 
RUN apt-get -y update && apt-get -y upgrade && \
#
# Add PPA for Python 3.x and R 4.0
apt -y install software-properties-common dirmngr && \
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -sc)-cran40/" && \
add-apt-repository -y ppa:deadsnakes/ppa && \
#
# Install libraries
apt-get -y install \
  wget \
  unzip \
  curl \
  git \
  build-essential \
  libgdal-dev \
  gdal-bin \
  #python-gdal \ 
  libarmadillo-dev \
  libfltk1.3-dev \
  libgsl0-dev \
  lockfile-progs \
  rename \
  parallel \
  apt-utils \
  cmake \
  libgtk2.0-dev \
  pkg-config \
  libavcodec-dev \
  libavformat-dev \
  libswscale-dev \
  python3.8 \
  python3-pip \
  pandoc \
  r-base \
  aria2 && \
# Set python aliases for Python 3.x
echo 'alias python=python3' >> ~/.bashrc \
  && echo 'alias pip=pip3' >> ~/.bashrc \
  && . ~/.bashrc && \
#
# NumPy is needed for OpenCV, gsutil for level1-csd, landsatlinks for level1-landsat (requires gdal/requests/tqdm)
pip3 install --no-cache-dir --upgrade pip && \
pip3 install --no-cache-dir  \
    numpy==1.18.1  \
    gsutil \
    scipy==1.6.0 \
    gdal==$(gdal-config --version | awk -F'[.]' '{print $1"."$2}') \
    git+https://github.com/ernstste/landsatlinks.git && \
#
# Install R packages
Rscript -e 'install.packages("rmarkdown", repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("plotly",    repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("stringi",   repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("knitr",     repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("dplyr",     repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("raster",    repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("sp",        repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("rgdal",     repos="https://cloud.r-project.org")' && \
#
# Clear installation data
apt-get clean && rm -r /var/cache/

# Install folder
ENV INSTALL_DIR /opt/install/src

# Build OpenCV from source
RUN mkdir -p $INSTALL_DIR/opencv && cd $INSTALL_DIR/opencv && \
wget https://github.com/opencv/opencv/archive/4.1.0.zip \
  && unzip 4.1.0.zip && \
mkdir -p $INSTALL_DIR/opencv/opencv-4.1.0/build && \
cd $INSTALL_DIR/opencv/opencv-4.1.0/build && \
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. \
  && make -j7 \
  && make install \
  && make clean && \
#
# Build SPLITS from source
mkdir -p $INSTALL_DIR/splits && \
cd $INSTALL_DIR/splits && \
wget http://sebastian-mader.net/wp-content/uploads/2017/11/splits-1.9.tar.gz && \
tar -xzf splits-1.9.tar.gz && \
cd $INSTALL_DIR/splits/splits-1.9 && \
./configure CPPFLAGS="-I /usr/include/gdal" CXXFLAGS=-fpermissive \
  && make \
  && make install \
  && make clean && \
#
# Cleanup after successfull builds
rm -rf $INSTALL_DIR
#RUN apt-get purge -y --auto-remove apt-utils cmake git build-essential software-properties-common


# Create a dedicated 'docker' group and user
RUN groupadd docker && \
  useradd -m docker -g docker -p docker && \
  chmod 0777 /home/docker && \
  chgrp docker /usr/local/bin && \
  mkdir -p /home/docker/bin && chown docker /home/docker/bin
# Use this user by default
USER docker

ENV HOME /home/docker
ENV PATH "$PATH:/home/docker/bin"

WORKDIR /home/docker
