Confluent Kafka Examples

Confluent examples using local mode install.


Examples have been run in the following OS environments

* Windows Subystem for Linux (WSL) with Ubuntu 20.04 LTS
* Centos in VirtualBox (tbd)
* AWS Linux 2 (tbd)

Install Confluent and Camel Connect components.  This only needs to be run once.


````bash
# Install Confluent
source install_confluent.sh
install_confluent_main

# Install Camel Kafka Connect Components
source install_camel_kafka_connect.sh
install_camel_kafka_connect_main
````

Start a Confluent local instance.  Usually a clean confluent local instance should be created each time.

````bash
# destroy any previous instance
confluent local destroy

# start confluent server in local mode
confluent local start
````

Setup the kafka connectors and topics.

````bash
# Run quickstart scripts to create datagen and Camel Connectors.  ksql example script is included but not run.
source quickstart.sh
quickstart_main
````


In Control Center, navigate to your Connect -> your connect cluster (connect-default) and observe the four connectors created.
There are are two datagen sources and two file sinks. Drill into each source or sink and then view the Settings.
They should match the json file configurations above.

Navigate to the top level Topics in Control Center. Observe the users and pageviews topics.
There are separate tabs for Messages as well as topic level Schemas. 
Click on the Schemas tab and observe that it is empty since we did not assign a schema to this topic.

Drill into the topics and view the Messagess tab.
Note that message content has both key and value portions, and that the value portion is further divided into schema
and payload. The messages have been inspected and an anonymous schema inferred for that specific message.
