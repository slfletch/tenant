# WebHook diagnostics
This is a go library designed to run a sample endpoint that can be used to output the header & body of HTTP Posts from an arbitrary system.

## How to use
1.  Configure the etc/postlog.json file.  If no publicKey or privateKey values are specified the system will start in http only mode
2.  Start the webservice: nohup go run cmd/main.go > logs/SystemOut.log &
3.  Watch the logs: tail -f logs/SystemOut.log
4.  Post data: curl --header "Content-Type: application/json" --request POST --data '{"hello":"world"}' http://localhost:8000/endpoint
5.  Check the output: 
    ``` 2020/09/21 13:39:43 {"body":{"hello":"world"},"headers":{"Accept":["*/*"],"Content-Length":["17"],"Content-Type":["application/json"],"User-Agent":["curl/7.66.0"]}}```
6.  (Optional) Post data via https: curl -k --header "Content-Type: application/json" --request POST --data '{"hello":"world"}' https://localhost:8443/endpoint
7.  (Optional) Check the output:
    ```2020/09/21 13:39:59 {"body":{"hello":"world"},"headers":{"Accept":["*/*"],"Content-Length":["17"],"Content-Type":["application/json"],"User-Agent":["curl/7.66.0"]}}```