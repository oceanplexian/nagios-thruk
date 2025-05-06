# Define image and container names
IMAGE_NAME=nagios-thruk-app
CONTAINER_NAME=nagios-thruk
HOST_PORT=9095
CONTAINER_PORT=80

# Phony targets don't represent files
.PHONY: all build stop rm run up logs clean verify

# Default target runs the 'up' sequence
all: up

# Verify Nagios configuration
verify: build
	@echo "Verifying Nagios configuration..."
	@docker run --rm --entrypoint=/bin/bash $(IMAGE_NAME) -c "mkdir -p /opt/nagios/etc && cp -r /opt/nagios.template/etc/* /opt/nagios/etc/ && nagios4 -v /opt/nagios/etc/nagios.cfg"

# Build the Docker image using the Dockerfile in the current directory
build: Dockerfile
	@echo "Building Docker image '$(IMAGE_NAME)'..."
	@docker build -t $(IMAGE_NAME) .

# Stop the running container, ignore error if it doesn't exist
stop:
	@echo "Stopping existing container '$(CONTAINER_NAME)'..."
	@docker stop $(CONTAINER_NAME) || true

# Remove the stopped container, ignore error if it doesn't exist
# Depends on 'stop' to ensure it's stopped first
rm: stop
	@echo "Removing existing container '$(CONTAINER_NAME)'..."
	@docker rm $(CONTAINER_NAME) || true

# Run the new container
# Depends on 'build'
run: build
	@echo "Running new container '$(CONTAINER_NAME)'..."
	@docker run -d --name $(CONTAINER_NAME) \
		-p $(HOST_PORT):$(CONTAINER_PORT) \
		$(IMAGE_NAME)
	# Optional: Mount local configs or Nagios object definitions
	# -v ./etc/objects:/etc/nagios4/objects \
	# -v ./thruk_local.conf:/etc/thruk/thruk_local.conf \

# Combined target: Remove old container -> Build image -> Run new container
up: rm run
	@echo "------------------------------------------------------------"
	@echo "Nagios+Thruk container '$(CONTAINER_NAME)' is up and running."
	@echo "Access Thruk at http://localhost:$(HOST_PORT)/thruk/"
	@echo "(Nagios runs in the background, check logs if needed)"
	@echo "------------------------------------------------------------"

# Show logs from the running container
logs:
	@echo "Showing logs for container '$(CONTAINER_NAME)'... (Ctrl+C to stop)"
	@docker logs -f $(CONTAINER_NAME)

# Clean up: Stop and remove the container and the image
clean: rm
	@echo "Removing Docker image '$(IMAGE_NAME)'..."
	@docker rmi $(IMAGE_NAME) || true
	@echo "Cleanup complete." 