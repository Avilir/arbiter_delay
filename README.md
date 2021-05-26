# Stretch Cluster Latency

This playbook it intend to setup latency between OCP nodes depend on the zone they are in.

The Latency whith is the zone remain untuched

the latency can be modify by changing the variable in the groups_vars : inj_delay
or by adding the cli argument -e "inj_delay=<delay>"

the delay is in ms and it is for one way so for example, if you want 10ms delay round-trip you need to run :

ansible-laybook playbook.yml -e "inj_delay=5"
 
