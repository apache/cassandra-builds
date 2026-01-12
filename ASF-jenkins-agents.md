# Apache Cassandra [ci-cassandra.apache.org](ci-cassandra.apache.org) Jenkins Resources

This document contains information on
- how to set up servers to be added to the ci-cassandra.apache.org jenkins cluster, and
- the list of servers currently donated and running at ci-cassandra.apache.org


Additional compute resource donations for the Apache Cassandra project are always appreciated.  The project is dependent on these donations.
If you have questions about compute resource donations, ask on the dev mailing list <dev@cassandra.apache.org>.


## Server Requirements

Server Requirements:
 - Installed OS software is the stock online.net Ubuntu 24.04 LTS amd64 image.
 - Static IP address.
 - Root volume is all available space (500GB+), preferably in a RAID-0 configuration.


## Ubuntu 24.04 Server Installation

1. The `agent-install.sh` must be run in preparation for ASF Infra to add it to the Jenkins cluster.

To run the script…

      a. `scp agent-install.sh <server>:~/`

      b. `ssh <server>`

      c. `sudo bash agent-install.sh`

2. hostname and /etc/hosts needs to be updated.  You need to know values for `${public_ip}` and `${n}`.

    hostnamectl set-hostname jenkins-cassandra${n}

    sed -i '/${public_ip}/{d;}' /etc/hosts
    echo "${public_ip} jenkins-cassandra${n}.apache.org jenkins-cassandra${n} >> /etc/hosts

## AWS Server Installation

On AWS you are free to re-use the public AMI `ami-02cd664c0e9899a91 cassandra-jenkins-host-v3`.
You will find this AMI in region `us-west-2`.

It is highly preferable to provision nodes in a such way that its reboot nor shutdown / start will
change node's IP address. Use Elastic IPs for this. The default limit per region is 5. You may 
ask for more in console https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html#using-instance-addressing-limit


----

# Current Agents

- All have label `cassandra` (or `cassandra-arm` for arm64 architecture).
- Agents with 500GB+ data volumes have the label `cassandra-dtest`, enabling them to run the python dtests.
- Agents with 32GB+ RAM have the label `cassandra-dtest-large`, enabling them to run the resource intensive python dtests.

| Agent Name     | Donated By  | Ubuntu version | Specs                         | IP Address     |
| -------------- | -----------:|:---------------:| ----------------------------:|:--------------:|
| [cassandra1](https://ci-cassandra.apache.org/computer/cassandra1)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.51   |
| [cassandra2](https://ci-cassandra.apache.org/computer/cassandra2)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.50   |
| [cassandra3](https://ci-cassandra.apache.org/computer/cassandra3)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.54   |
| [cassandra4](https://ci-cassandra.apache.org/computer/cassandra4)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.62   |
| [cassandra5](https://ci-cassandra.apache.org/computer/cassandra5)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.53   |
| [cassandra6](https://ci-cassandra.apache.org/computer/cassandra6)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.55   |
| [cassandra7](https://ci-cassandra.apache.org/computer/cassandra7)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.60   |
| [cassandra8](https://ci-cassandra.apache.org/computer/cassandra8)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.91.168   |
| [cassandra9](https://ci-cassandra.apache.org/computer/cassandra9)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.61   |
| [cassandra10](https://ci-cassandra.apache.org/computer/cassandra10)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.52   |
| [cassandra11](https://ci-cassandra.apache.org/computer/cassandra11)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.57   |
| [cassandra12](https://ci-cassandra.apache.org/computer/cassandra12)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.56   |
| [cassandra13](https://ci-cassandra.apache.org/computer/cassandra13)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.58   |
| [cassandra14](https://ci-cassandra.apache.org/computer/cassandra14)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.91.162   |
| [cassandra15](https://ci-cassandra.apache.org/computer/cassandra15)       | IBM         |  24.04 | amd64, 32G RAM,  4 core    | 169.54.102.59   |
| [cassandra17](https://ci-cassandra.apache.org/computer/cassandra17)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 44.230.121.32   |
| [cassandra18](https://ci-cassandra.apache.org/computer/cassandra18)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 44.230.213.15   |
| [cassandra19](https://ci-cassandra.apache.org/computer/cassandra19)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 44.231.106.18   |
| [cassandra20](https://ci-cassandra.apache.org/computer/cassandra20)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 44.231.194.19   |
| [cassandra21](https://ci-cassandra.apache.org/computer/cassandra21)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 44.233.81.188   |
| [cassandra22](https://ci-cassandra.apache.org/computer/cassandra22)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 50.112.217.24   |
| [cassandra23](https://ci-cassandra.apache.org/computer/cassandra23)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 50.112.240.23   |
| [cassandra24](https://ci-cassandra.apache.org/computer/cassandra24)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 52.12.57.190    |
| [cassandra25](https://ci-cassandra.apache.org/computer/cassandra25)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 52.27.28.244    |
| [cassandra26](https://ci-cassandra.apache.org/computer/cassandra26)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 54.185.77.39    |
| [cassandra27](https://ci-cassandra.apache.org/computer/cassandra27)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 54.188.214.16   |
| [cassandra28](https://ci-cassandra.apache.org/computer/cassandra28)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 54.190.165.16   |
| [cassandra29](https://ci-cassandra.apache.org/computer/cassandra29)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 54.212.144.24   |
| [cassandra30](https://ci-cassandra.apache.org/computer/cassandra30)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 54.214.96.70    |
| [cassandra31](https://ci-cassandra.apache.org/computer/cassandra31)       | Amazon      |  24.04 | amd64, 32G RAM, m5.2xlarge | 54.71.239.65    |
| [cassandra32](https://ci-cassandra.apache.org/computer/cassandra32)       | iland       |  24.04 | amd64,  32G RAM, 16 core   | 64.18.213.245   |
| [cassandra33](https://ci-cassandra.apache.org/computer/cassandra33)       | iland       |  24.04 | amd64,  32G RAM, 16 core   | 64.18.213.246   |
| [cassandra34](https://ci-cassandra.apache.org/computer/cassandra34)       | iland       |  24.04 | amd64,  32G RAM, 16 core   | 64.18.213.247   |
| [cassandra35](https://ci-cassandra.apache.org/computer/cassandra35)       | iland       |  24.04 | amd64,  32G RAM, 16 core   | 64.18.213.248   |
| [cassandra36](https://ci-cassandra.apache.org/computer/cassandra36)       | iland       |  24.04 | amd64,  32G RAM, 16 core   | 64.18.213.249   |
| [cassandra51](https://ci-cassandra.apache.org/computer/cassandra51)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 37.27.237.42    |
| [cassandra52](https://ci-cassandra.apache.org/computer/cassandra52)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 65.21.169.90    |
| [cassandra53](https://ci-cassandra.apache.org/computer/cassandra53)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 65.21.169.89    |
| [cassandra54](https://ci-cassandra.apache.org/computer/cassandra54)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 65.21.169.88    |
| [cassandra55](https://ci-cassandra.apache.org/computer/cassandra55)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 65.21.169.87    |
| [cassandra56](https://ci-cassandra.apache.org/computer/cassandra56)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 95.216.13.181   |
| [cassandra57](https://ci-cassandra.apache.org/computer/cassandra57)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 65.21.174.184   |
| [cassandra58](https://ci-cassandra.apache.org/computer/cassandra58)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 95.217.141.42   |
| [cassandra59](https://ci-cassandra.apache.org/computer/cassandra59)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 37.27.231.136   |
| [cassandra60](https://ci-cassandra.apache.org/computer/cassandra60)       | NetApp      |  22.04 | amd64, 256G RAM, 48 core   | 37.27.142.164   |
| [cassandra-arm1](https://ci-cassandra.apache.org/computer/cassandra-arm1) | Huawei      |  24.04 | arm64,  32G RAM, 16 core   | 114.119.184.236 |
| [cassandra-arm2](https://ci-cassandra.apache.org/computer/cassandra-arm2) | Huawei      |  24.04 | arm64,  32G RAM, 16 core   | 94.74.91.186    |
| [cassandra-arm3](https://ci-cassandra.apache.org/computer/cassandra-arm3) | Huawei      |  24.04 | arm64,  32G RAM, 16 core   | 159.138.106.144 |
| [cassandra-arm4](https://ci-cassandra.apache.org/computer/cassandra-arm4) | Huawei      |  24.04 | arm64,  32G RAM, 16 core   | 110.238.106.76  |
| [cassandra-arm5](https://ci-cassandra.apache.org/computer/cassandra-arm5) | Huawei      |  24.04 | arm64,  32G RAM, 16 core   | 94.74.95.38     |
| [cassandra-arm6](https://ci-cassandra.apache.org/computer/cassandra-arm6) | Huawei      |  24.04 | arm64,  32G RAM, 16 core   | 119.8.163.173   |


----

Contacts for system donators, when console hands may be needed by INFRA:

  *IBM*: Mick Semb Wever mck@apache.org
               alternative group list: ds-nosql-ci-cassandra@ibm.com

  *NetApp*: Stefan Miklosovic smiklosovic@apache.org
               alternative group list: admin@instaclustr.com

  *Amazon*: Himanshu Jindal cassandra-hardware@amazon.com

  *iland*: Julien Anguenot julien@anguenot.org

  *Huawei*:  Weijun Lu wjunlu217@gmail.com

----

