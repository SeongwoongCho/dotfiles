#!/bin/bash

# running target
DOCKER_IMAGE=$1
DOCKER_NAME=$2

# available port range
P1=10000
P2=20000

# target port: we will use port range [TP, TP+N-1]
# if target_port == -1, the target port will be the same as source port
TP=-1

# number of ports to use
N=20

# port availablity
is_ports_available() {
  # Check if all n consecutive ports are available
  for (( i=0; i<$N; i++ )); do
    PORT=$(( $1 + i ))
    nc -z localhost $PORT
    if [ $? -eq 0 ]; then
      # Port is in use, return failure
      return 1
    fi
  done
  # All ports are available
  return 0
}

# Find a consecutive range of N available ports within the range [P1, P2]
available_ports=()
for (( port=$P1; port<=$P2; port++ )); do
  # Check if the next N consecutive ports are available
  if is_ports_available $port; then
    available_ports=()
    for (( i=0; i<$N; i++ )); do
      available_ports+=($(( $port + i )))
    done
    break
  fi
done

# Check if we found N available ports
if [ ${#available_ports[@]} -lt $N ]; then
  echo "Not enough available ports in the range [$P1, $P2]"
  exit 1
fi

# Select the first available range of N consecutive ports
START_HOST_PORT=${available_ports[0]}  # The first available port
END_HOST_PORT=$((START_HOST_PORT + N - 1))  # Last available port

# Define the container port range starting from target port
if [ $TP < 0 ]; then
  START_CONTAINER_PORT=$TP
  END_CONTAINER_PORT=$((TP + N - 1))
else
  START_CONTAINER_PORT=$START_HOST_PORT
  END_CONTAINER_PORT=$END_HOST_PORT
fi

# Construct the docker run -p option with port ranges
HOST_PORT_RANGE="${START_HOST_PORT}-${END_HOST_PORT}"
CONTAINER_PORT_RANGE="${START_CONTAINER_PORT}-${END_CONTAINER_PORT}"

# Run the docker container with dynamic port ranges
echo "Running container with the following port mappings:"
echo "docker run -p $HOST_PORT_RANGE:$CONTAINER_PORT_RANGE ..."
echo "Docker Image: $DOCKER_IMAGE"
echo "Docker Name: $DOCKER_NAME"

docker run \
        -it \
        --gpus all \
        --ipc=host \
        --name=$DOCKER_NAME \
        --privileged \
        -v=/data1:/data1 \
        -w=$HOME \
        -p $HOST_PORT_RANGE:$CONTAINER_PORT_RANGE \
        $DOCKER_IMAGE bash