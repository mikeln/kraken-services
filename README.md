# kraken-services

Services for use on a kraken cluster.

Each directory contains a set of kubernetes resources intended to be deployed onto a kraken-managed kubernetes cluster.

The resources are not always complete, and may require environment-varables-as-templtaes to be substituted in

Some services also contain a build directory for the Docker images referenced in the kubernetes resources.
