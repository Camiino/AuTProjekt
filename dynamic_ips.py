import nmap
import os
import json
import socket
from apscheduler.schedulers.blocking import BlockingScheduler

hostnames = {"eiba-dl", "eiba-dl2"}
scheduler = BlockingScheduler()


@scheduler.scheduled_job("interval", seconds=10)
def get_devices():
    devices = {}
    for device in os.popen('arp -a'):
        listing = device.split(" ")
        hostname = listing[0].split(".")[0]
        ip = listing[1].strip("()")
        if hostname in hostnames:
            devices[hostname] = f"{ip}:9100"
    print(devices)
    
    json_out = []

    overview = {"labels": {
                    "job": "overview"
                },
                "targets": [devices[hostname] for hostname in devices.keys()]}
    json_out.append(overview)

    with open("/home/sersandr/monitoring/overview.json", "w") as out:
        json.dump(json_out, out, indent=4)
    
    for hostname in devices.keys():
        json_out = []
        singular = {"labels": {
                        "job": hostname
                    },
                    "targets": [devices[hostname]]}
        json_out.append(singular)
        with open(f"/home/sersandr/monitoring/{hostname}.json", "w") as out:
            json.dump(json_out, out, indent=4)


if __name__ == "__main__":
    scheduler.start()
    