# /bin/bash
sudo docker run -d -p 80:80 -p  8125:8125/udp -p 8126:8126  -v /mnt/data2/elasticsearch:/data -v /mnt/data2/whisper:/var/lib/graphite/storage/whisper --name grafana rblabs/grafana

