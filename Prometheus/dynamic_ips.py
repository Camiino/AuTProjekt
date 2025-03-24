import os
import json
import socket
from scapy.all import srp,Ether,ARP,conf

hostnames = {}

def arp_scan(interface, ips):
    found = {}
    conf.verb = 0
    ans, uans = srp(Ether(dst="ff:ff:ff:ff:ff:ff")/ARP(pdst=ips),
                    timeout = 2,
                    iface = interface,
                    inter = 0.1)
    for snd,rcv in ans:
        out = rcv.sprintf(r"%ARP.psrc% - %Ether.src%").split("-")
        ip = out[0].strip()
        mac = out[1].strip()
        if mac in hostnames:
            hostname = hostnames[mac]
            found[hostname] = ip

    return found

if __name__ == "__main__":
    found = arp_scan("enp5s0f0", "172.17.21.1/24")
    for hostname in found.keys():
        json_out = []
        singular = {"labels": {
                        "job": hostname
                    },
                   "targets": [f"{found[hostname]}:8080"]}
        json_out.append(singular)
        with open(f"/home/sersandr/monitoring/{hostname}.json", "w") as out:
            json.dump(json_out, out, indent=4)
