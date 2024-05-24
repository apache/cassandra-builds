# Apache Cassandra [ci-cassandra.apache.org](ci-cassandra.apache.org) Jenkins Resources

This document contains information on
- how to set up servers to be added to the ci-cassandra.apache.org jenkins cluster, and
- the list of servers currently donated and running at ci-cassandra.apache.org


Additional compute resource donations for the Apache Cassandra project are appreciated.
If you have questions about compute resource donations, ask on the dev mailing list <dev@cassandra.apache.org>.


## Server Requirements

Server Requirements:
 - Installed OS software is the stock online.net Ubuntu 22.04 LTS amd64 image.
 - Static IP address.
 - Root volume is all available space (500GB+), preferably in a RAID-0 configuration.


## Ubuntu 18.04 Server Installation

1. Sudoers need to sudo without password.

Edit sudoers to allow INFRA to sudo without password, or provide them with the password.
For example, set:  `%sudo   ALL=(ALL:ALL) NOPASSWD:ALL`

  `$ sudo visudo`

2. The `agent-install.sh` must be run in preparation for ASF Infra to add it to the Jenkins cluster.

To run the script…

      a. `scp agent-install.sh <server>:~/`

      b. `ssh <server>`

      c. `sudo bash agent-install.sh`


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

| Agent Name     | Donated By  | Description                                  | IP Address     |
| -------------- | -----------:| --------------------------------------------:|:--------------:|
| [cassandra8](https://ci-cassandra.apache.org/computer/cassandra8)         | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 52.38.142.130   |
| [cassandra9](https://ci-cassandra.apache.org/computer/cassandra9)         | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 34.223.128.131  |
| [cassandra10](https://ci-cassandra.apache.org/computer/cassandra10)       | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 34.209.95.9     |
| [cassandra11](https://ci-cassandra.apache.org/computer/cassandra11)       | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 52.13.31.44     |
| [cassandra12](https://ci-cassandra.apache.org/computer/cassandra12)       | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 52.88.147.81    |
| [cassandra13](https://ci-cassandra.apache.org/computer/cassandra13)       | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 34.213.143.168  |
| [cassandra14](https://ci-cassandra.apache.org/computer/cassandra14)       | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 54.148.1.179    |
| [cassandra15](https://ci-cassandra.apache.org/computer/cassandra15)       | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 54.189.131.27   |
| [cassandra16](https://ci-cassandra.apache.org/computer/cassandra16)       | Instaclustr |  Ubuntu 18.04 LTS amd64, 32G RAM, m4.2xlarge | 54.201.88.175   |
| [cassandra17](https://ci-cassandra.apache.org/computer/cassandra17)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 44.230.121.32   |
| [cassandra18](https://ci-cassandra.apache.org/computer/cassandra18)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 44.230.213.15   |
| [cassandra19](https://ci-cassandra.apache.org/computer/cassandra19)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 44.231.106.18   |
| [cassandra20](https://ci-cassandra.apache.org/computer/cassandra20)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 44.231.194.19   |
| [cassandra21](https://ci-cassandra.apache.org/computer/cassandra21)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 44.233.81.188   |
| [cassandra22](https://ci-cassandra.apache.org/computer/cassandra22)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 50.112.217.24   |
| [cassandra23](https://ci-cassandra.apache.org/computer/cassandra23)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 50.112.240.23   |
| [cassandra24](https://ci-cassandra.apache.org/computer/cassandra24)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 52.12.57.190    |
| [cassandra25](https://ci-cassandra.apache.org/computer/cassandra25)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 52.27.28.244    |
| [cassandra26](https://ci-cassandra.apache.org/computer/cassandra26)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 54.185.77.39    |
| [cassandra27](https://ci-cassandra.apache.org/computer/cassandra27)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 54.188.214.16   |
| [cassandra28](https://ci-cassandra.apache.org/computer/cassandra28)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 54.190.165.16   |
| [cassandra29](https://ci-cassandra.apache.org/computer/cassandra29)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 54.212.144.24   |
| [cassandra30](https://ci-cassandra.apache.org/computer/cassandra30)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 54.214.96.70    |
| [cassandra31](https://ci-cassandra.apache.org/computer/cassandra31)       | Amazon      |  Ubuntu 18.04 LTS amd64, 32G RAM, m5.2xlarge | 54.71.239.65    |
| [cassandra32](https://ci-cassandra.apache.org/computer/cassandra32)       | iland       |  Ubuntu 18.04 LTS amd64, 32G RAM, 16 core    | 64.18.213.245   |
| [cassandra33](https://ci-cassandra.apache.org/computer/cassandra33)       | iland       |  Ubuntu 18.04 LTS amd64, 32G RAM, 16 core    | 64.18.213.246   |
| [cassandra34](https://ci-cassandra.apache.org/computer/cassandra34)       | iland       |  Ubuntu 18.04 LTS amd64, 32G RAM, 16 core    | 64.18.213.247   |
| [cassandra35](https://ci-cassandra.apache.org/computer/cassandra35)       | iland       |  Ubuntu 18.04 LTS amd64, 32G RAM, 16 core    | 64.18.213.248   |
| [cassandra36](https://ci-cassandra.apache.org/computer/cassandra36)       | iland       |  Ubuntu 18.04 LTS amd64, 32G RAM, 16 core    | 64.18.213.249   |
| [cassandra37](https://ci-cassandra.apache.org/computer/cassandra37)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.52.226  |
| [cassandra38](https://ci-cassandra.apache.org/computer/cassandra38)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.52.231  |
| [cassandra39](https://ci-cassandra.apache.org/computer/cassandra39)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.52.232  |
| [cassandra40](https://ci-cassandra.apache.org/computer/cassandra40)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.52.237  |
| [cassandra41](https://ci-cassandra.apache.org/computer/cassandra41)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.52.242  |
| [cassandra42](https://ci-cassandra.apache.org/computer/cassandra42)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.52.245  |
| [cassandra43](https://ci-cassandra.apache.org/computer/cassandra43)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.53.15   |
| [cassandra44](https://ci-cassandra.apache.org/computer/cassandra44)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.53.17   |
| [cassandra45](https://ci-cassandra.apache.org/computer/cassandra45)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.53.59   |
| [cassandra46](https://ci-cassandra.apache.org/computer/cassandra46)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.55.25   |
| [cassandra47](https://ci-cassandra.apache.org/computer/cassandra47)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.55.40   |
| [cassandra48](https://ci-cassandra.apache.org/computer/cassandra48)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.55.49   |
| [cassandra49](https://ci-cassandra.apache.org/computer/cassandra49)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.55.57   |
| [cassandra50](https://ci-cassandra.apache.org/computer/cassandra50)       | DataStax    |  Ubuntu 18.04 LTS amd64, 32G RAM             | 163.172.51.48   |
| [cassandra-arm1](https://ci-cassandra.apache.org/computer/cassandra-arm1) | Huawei      |  Ubuntu 18.04.3 LTS arm64, 32G RAM, 16 core  | 114.119.184.236 |
| [cassandra-arm2](https://ci-cassandra.apache.org/computer/cassandra-arm2) | Huawei      |  Ubuntu 18.04.3 LTS arm64, 32G RAM, 16 core  | 94.74.91.186    |
| [cassandra-arm3](https://ci-cassandra.apache.org/computer/cassandra-arm3) | Huawei      |  Ubuntu 18.04.3 LTS arm64, 32G RAM, 16 core  | 159.138.106.144 |
| [cassandra-arm4](https://ci-cassandra.apache.org/computer/cassandra-arm4) | Huawei      |  Ubuntu 18.04.3 LTS arm64, 32G RAM, 16 core  | 110.238.106.76  |
| [cassandra-arm5](https://ci-cassandra.apache.org/computer/cassandra-arm5) | Huawei      |  Ubuntu 18.04.3 LTS arm64, 32G RAM, 16 core  | 94.74.95.38     |
| [cassandra-arm6](https://ci-cassandra.apache.org/computer/cassandra-arm6) | Huawei      |  Ubuntu 18.04.3 LTS arm64, 32G RAM, 16 core  | 119.8.163.173   |


----

Contacts for system donators, when console hands may be needed by INFRA:

  *Datastax*: Mick Semb Wever <mck@apache.org>

  *Instaclustr*: Stefan Miklosovic <stefan.miklosovic@instaclustr.com>
               alternative group list: admin@instaclustr.com

  *Amazon*: Steve Mayszak cassandra-hardware@amazon.com

  *iland*: Julien Anguenot <julien@anguenot.org>

  *Huawei*:  Liu Sheng  <liusheng2048@gmail.com>

----


For adding additional infrastructure see
 https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=127406622
