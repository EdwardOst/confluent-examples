Confluent Kafka Examples

Confluent examples using local mode install.


Examples have been run in the following OS environments

* Windows Subystem for Linux (WSL) with Ubuntu 20.04 LTS
* Centos in VirtualBox (tbd)
* AWS Linux 2 (tbd)

Usage:

````bash
# Install Confluent
source install_confluent.sh
install_confluent_main

# Install Camel Kafka Connect Components
source install_camel_kafka_connect.sh
install_camel_kafka_connect_main

# start confluent server in local mode
confluent local start

# Run quickstart scripts to create datagen and Camel Connectors.  ksql example script is included but not run.
quickstart.sh
````
