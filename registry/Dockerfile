FROM registry:2.0

# Add the custom configuration file we made 
ADD ./config.yml /go/src/github.com/docker/distribution/cmd/registry/config.yml

# Create the data directory
RUN mkdir /data
