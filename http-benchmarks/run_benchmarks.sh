set -x

export GOMAXPROCS=1
export LD_PRELOAD=/usr/local/lib/libmimalloc.so

mkdir -p output

for cmd in "httpserv_go" "httpserv_lwt" "httpserv_effects"; do
  for rps in 2500 5000 10000 15000 20000 25000 30000 35000 40000 45000 50000 55000 60000; do
    for cons in 1000 5000 10000; do
			if [ ! -s output/run-$cmd-$rps-$cons.txt ]
			then
				./$cmd &
				running_pid=$!
				sleep 2;
				./wrk -t 24 -d60s -L -s json.lua -R $rps -c $cons http://localhost:8080 > output/run-$cmd-$rps-$cons.txt;
				kill ${running_pid};
				sleep 1;
			fi
    done
  done
done
