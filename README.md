# Hackathon
VMworld's Hackathon

These are the scripts I wrote at the Hackathon at VMworld.

They are unpolished and may not work in your environment, since I slapped them together in just a few hours.

Overview:
At a high level, our plan was to automate a near zero downtime application upgrade by cloning application VMs and move them behind another secondary NSX Edge Device and simply flip the routes to the new VMs after their application had been upgraded.

We had planned on using a Slack bot to initiate the VM clone, application upgrade, and traffic flip, but we only got the three independent parts working, as we didn't have time to build a Slack server for the Slack bot with the connection issues we all experienced.

The setup included three NSX ESGs:

Parent ESG served as the P/V Edge

Secondary "Blue" edge connected to the parent

Secondary "Green" edge connected to the parent

Four logical switches:

Blue-Transit

Green-Transit

Blue

Green

Application servers were placed onto the Blue logical switch and their native IP routed down from the parent edge.

The clone script clones the VMs and places them behind the Green edge and uses both a SNAT & DNAT on the Green Edge for communication through the parent edge, where another static route exists for the NAT IPs.

At this time, the application is upgraded on the clones while the production VMs are still running.

The failover script determines which side is production (blue or green), replaces the old routes by building new routes to send production traffic to the new VMs after their application has been upgraded, then powers off & deletes the old production VMs.
