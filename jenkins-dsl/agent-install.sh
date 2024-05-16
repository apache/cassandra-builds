#!/bin/bash
#
# This script sets up an Ubuntu 22.04 server to be a ASF Jenkins agent.
#  After this setup is complete, an INFRA jira ticket must be opened for ASF Infra to complete the process.
#
# Script Requirements:
#  * Ubuntu 22.04
#  * run as root
#  * internet access
#
# To run the script…
#  1. ssh into server and allow sudo without password. For example: `%sudo   ALL=(ALL:ALL) NOPASSWD:ALL` in /etc/sudoers
#  2. scp agent-install.sh <server>:~/
#  3. ssh <server>
#  4. sudo bash agent-install.sh
#

command -v lsb_release >/dev/null 2>&1 || { echo >&2 "Expecting an Ubuntu server with lsb_release installed"; exit 1; }
if ! lsb_release -d | grep -q "Ubuntu 22.04" ; then
    echo "Ubuntu 22.04 expected. Found $(lsb_release -d | cut -d' ' -f2)"
    exit 1
fi
if [ "$EUID" -ne 0 ] ; then
    echo "Please run as root"
    exit 1
fi
if ! ping -c 1 -q apt.puppetlabs.com >&/dev/null ; then
    echo "Cannot access apt.puppetlabs.com"
    exit 1
fi

# Remove the default installation of bind9
apt-get -y autoremove --purge bind9
rm -r /var/cache/bind

apt-get -y install net-tools software-properties-common

# Ensure `hostname` is configured to the server's public ip
hostname `dig +short myip.opendns.com @resolver1.opendns.com`

# Two users need to be added, each with a different public key authorized.
# The jenkins user is for the CloudBees master, and the asf999 user is for ASF Infra maintenance.

# Add jenkins user
groupadd -g 910 jenkins
useradd -m -u 910 -g 910 -s /bin/bash jenkins
mkdir /home/jenkins/.ssh

# Authorize ssh pub key for jenkins user

sh -c "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAtxkcKDiPh1OaVzaVdc80daKq2sRy8aAgt8u2uEcLClzMrnv/g19db7XVggfT4+HPCqcbFbO3mtVnUnWWtuSEpDjqriWnEcSj2G1P53zsdKEu9qCGLmEFMgwcq8b5plv78PRdAQn09WCBI1QrNMypjxgCKhNNn45WqV4AD8Jp7/8=' > /home/jenkins/.ssh/authorized_keys"

chown -R jenkins:jenkins /home/jenkins/.ssh
chmod 700 /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/authorized_keys

# Add asf999 user
useradd -m -s /bin/bash asf999
mkdir /home/asf999/.ssh
usermod -a -G sudo asf999

# Authorize ssh pub key for asf999 user:
#  more info, see https://github.com/apache/infrastructure-p6/blob/production/data/common/asf999.yaml

sh -c "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDKU0OarYDnMtEyneHtOAA/mpeJbXLCVA2yy8wl2fGQ/kzdRhBDCCjusV0D83cwKckJEGVInbYruLwq7Rk4e1k0hwHoVR28ps4B0IrsFlkQrfkS0plGq5VlbUU1lu9hdR+2o992NzK3BGJa6Bde493FaEnJf+s4dQM9kkb9keYXLdh9lC99xlxYg7P5gSlv+0tCAo3LisKM1vVfjLaXIv94KwRNjcrLH0rjrQt0UnkGTjoP+WonILz9CsFfJDncofFp4gyyioYDTqgyGbVauGAdfctrqc+c1x4sz+Hk2ocFjGZEGzHZ8E/ZRXpaa9QNeyc4vKAm9CSWyonLNr3+KyJfQP82w5IZIF8rMBjl3/m0zPUgXSitc6ebrLUFhrESyoFF0RfeqEYUzjf52uRVlPVSiSATmvccdHel/G6lUZrQScYUPOZT++C7TZNPzRNy/MzeLjF0jcrDYjCXEj1r9TkQtByoHKc0Cikokcmn15SPX9nBWScN0kQ9DCnQ1DRx0C2L/KJwiV8i/ziel8RFqg8n71v1H8Ve40F/m+03dZAUGzlE1wu+lXu/ZXjBgIu8vOmz3LK+k4UskiMiiktYq1N9RG+4l30JR/OlLIRhlKiernmWUFyGC4npbquaTKUsB6G6RKOC1WnLpuM5U1jIKVeOejoptJilaHvO0RiZxNP/ZQ== humbedooh-puppet-20130726' > /home/asf999/.ssh/authorized_keys"
sh -c "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC71HP9YspO1SDZ/5qNJNGE3MW27XiYc5gx2kaCJ2ZT3unZVRU60p3/fbMG5XwOzvmbN3Gzp2l2/8jKmngnQO0oHY9E2ZcVh14TblbgSErVPMM5zZBg40PvDRk61eECnGkXYfVKU5RzcDq5yYr4FFFFRh3pWjjBDBWtSczAXYavWPHOpNpQ1onudiCev/KHADXZS8J/HwhHmkVmxSWX+9upQlPlokXulZpMFqx6FPbBLk45Miq5xSYS3mN8dW3OupDHiKavKoLuzqom+7ndLhFUMX468htnhfUvTs9ajh7xBTfhziPJh+PkjeQLWNLdMQe0L8Ptd4IAxqSkegTCNit/LZbK/Jo6z7sBSdk2N+f8UIlK2do/9KlN30sFbVAK3nsIekxR+xQldEOMaCr83IM/b0G/mefxFrCdSm3z9SW84WKVt+DNADVKUMTm9ngOp2cjxPeXQuL5vTABaeSrzeMTAWagWTRQQVT/6XMNNJRbpHj+Fp8rd4sIRnqv86hYL1aoE1THuxqT451ZRYHJoCiZ3PQPMEhAzR5F6Voji6RkyJL8S662Ai/FesEeNyc2hcErfnfFCsKWckUOg8YOIR+DSfuJ6LtZZB/+SAE/QzKzIvMWuLCiGFR2oSiY7MqeJCm5CeF06YGddnQhGoqM6ZC6/hFkWAJ0Uzc5DRlxyFovaQ== gav_mac' >> /home/asf999/.ssh/authorized_keys"
sh -c "echo 'ssh-dss AAAAB3NzaC1kc3MAAACAVaMrsS2AKvOFn4RZjBWxrwF3NxJ6jvy3ZJhbd+LH/JigL1J6o26Z5AV8HsfhOuVqj6kPaIAJ3bwaMjHrzl4nkFDS3QXDD3psrZbMtqIaugwzNOY7WDsHF0sfr6A/PoktNkoXF/BPqByx9DJ7UKq2+MP9LTj9r7Nzb5nS5L+dwDUAAAAVAI6xcksdw9IsgHW8LUeWSS+pGeXzAAAAgDhIVTB7UgFhX8Qjm/IdKVvR6hjYJ04HQnTqsnDzM2ju/Di4ATpogsUunnI7ZsBgOPF/moAzBlK+r+4621ggAW1xfRysvJYtqS0IYmyLPWryIb2xK4i6bagYhjtD2YAJbFuYmZHfyCUf82MVgqPeRRn9BWzCVzvA+7+K1rj5RlvUAAAAgBWbDECq37AFDQuMHRJiTAYJQLVBtfx3Fr/XbgkcX7DMPLXooDIAJWpqtyyfxYRHC4KRKmzDWE97Cw/03DpthAgpB+svxJghh895oAtoaCxhVzUrV0HUKQlNvg9a8s83w/iiHmoURB8kPZGyW1WJPS4ezsj/62WK1LXjmJK81pvf' >> /home/asf999/.ssh/authorized_keys"
sh -c "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAn5MYIbWTJB6ni69vgMUJXqexctL5KTG9yAP6nfas2Akdu6GAO0fL1cCGq/TV/0LKWM/XeSkdZMo1LxqsmJZpp9BvcDYEmUhR31N+eQE1SPf8qrtFJFAN1GbmMxYwiYbAO+4zjJu+YLV0zUeSMZX56pCpbd4kaDLgY8rXzUbo934e2s5AdKHUKh65gzMwP9gzyeq02/jEfET2VSN7Xz0mqxbF47+81beQZuxySfO1M68mFLQavSt6J/E90M9ljy/oylGTTUnmZlmcxk4smuN2V8YzZsJHkGB9bh0bK5xHqci9QRmSA4nxprNL6bqpnUHtYtNQsvPrTlyEFD28qePQEQ== cml' >> /home/asf999/.ssh/authorized_keys"
sh -c "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAtqqDXzCNpuQvr3yJa1XbhHDTW/hRwGMZCbninWxwWsd/E7QkuCdstBT2iGihbizbZlnh0mchjtvhouIADkbCyizvtRdujl0Vi1pg5i6YOKKkFc5/s2BRoqsrj0FLu7d2/oHddOz2DO1B8nfGfVyC9mxcqKVpOaGqfdcalLrAH60e7MmH9FkrEVMHQIgGaq1J9W0FFczcxrsCEu5FxXaFTGEos1BmnnsrdtCmQhSJ2n41cngZxrj+yy/HJSj++aDJ2HCwyvRnOX6PX7iNtLyRDX947+A4VbCRQtAC7IbccKHvTGTHSzBXs6PUNUEleZi5VHA6Xm4ubVNiNLwmGYlthw== ke4qqq@nalleyt61.keymark.dom' >> /home/asf999/.ssh/authorized_keys"
sh -c "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJivoCwPuWBhdeg/e/OcmfRkDLX3DTJPdiRJd3XbHP4QP+yjDeBqq57O956UEk1qoG/JGQx3vOXk96oSTFKpOJcZopZ2Dg1lJAWWccKompkrUGP0R8lb8Ki9VWf1TujNagDuDzxt9jruwW5jEeG1iOhgu0J0Qufd1up6Q5yvBE5dohpZ2OOhZennIudWOXqRduUVuNR6J5umfRVSPbg1bJXjjvwC5aeNGCJdH/NEp71+n7YjSfavoHbG8y3B3OvwJq3xQMqW5LZz0oxfpriIbBITzG8LO09TNnPLXc+CqGuMyqFHcv7KhhtQiA6oTom/9/Ylsg1HVmGxS/ARMW53czld8iVMFFdGGAs4Y3tV9glokG8JTaekYLTQoTJH41ZtF8gDXpabxrsfUQUDuETlpMJ+21U1xnwahMaMQzNL5+Kq2/KOc+qmLzrk4KY3Om3svKSs/v5nd3KHE5sDaL0A69l6wqIFzKiPTUSHew8wG1+BouRWJQ2NDow0F/QUpUKlXRC2zwQgn4Ha939EiQX1l2zDeGcBY+ohDHbgRZWhsXR8g7MSKKPQfQ16DBOkEzhQ6ztmTs2u/43olUEwjKjyVQXhbA5uI26eZyFYv5QBM7xwXpmbX8BTNqHhl02kIJGn2uSPYD9IpeAkRkt7INf60UUKOuIP2F3BTvFnhDnrdMIQ== christ@ECTO1' >> /home/asf999/.ssh/authorized_keys"
sh -c "echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDr8lZ/ACqhAQjZIsZJy/WswWW4hmlwEG7kr3t4+NCMj/8CI4AaLTTZJpOVW5u52gvJnEsMnp2ZLqZhaeWSa/m6SnNlzKqqe16DXP7ngq56qD8KjTnxnb5HNrqYiJJhLXpmd/fm89yOq8k4Tv4bOQzL0bgCA6xBxWFuZ8TPaUCNcXxidLqe2W8gQx4AffhFjrPdQPKnhVQ8pcC5dlpi17cBKHCTSdVM0wT7pLGMULTVbD25yHPtCI/jp47AGKE9IMYYxDlFVnePtWU19lRqjn4gjsv3dVYUhCibXyrz6RAxCZwXhK+5Et4uPcdttMO56wyxXC3lijTETvQX2rIkc4WX warwalrux@warwalrux-XPS-15-9570' >> /home/asf999/.ssh/authorized_keys"

chown -R asf999:asf999 /home/asf999/.ssh
chmod 700 /home/asf999/.ssh
chmod 600 /home/asf999/.ssh/authorized_keys

# Install Puppet 6 (not Puppet 5 that Jammy would normally install) and configured the puppet.conf file ready for use
wget https://apt.puppetlabs.com/puppet-release-jammy.deb
dpkg -i puppet-release-jammy.deb
rm puppet-release-jammy.deb
apt-get update
apt-get install -y puppet-agent

sh -c 'cat >> /etc/puppetlabs/puppet/puppet.conf << EOF
[main]
use_srv_records = true
srv_domain = apache.org

environment = production
EOF'

echo 'Domains=apache.org' >> /etc/systemd/resolved.conf
apt upgrade -y
apt dist-upgrade -y
echo "Please reboot this machine after the upgrade."
