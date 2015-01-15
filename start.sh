# /bin/bash
sudo docker run -d -p 80:80 -p  8125:8125/udp -p 8126:8126  -v /mnt/data2:/data -v /mn/data2:/var/lib/graphite/storage --name grafana rblabs/grafana

