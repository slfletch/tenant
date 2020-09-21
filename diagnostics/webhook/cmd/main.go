/*
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
)

var postlogConfig config

// config is the structure for etc/postlog.json
type config struct {
	Host       *string `json:"host,omitempty"`
	HTTPPort   *int    `json:"httpPort,omitempty"`
	HTTPSPort  *int    `json:"httpsPort,omitempty"`
	PublicKey  *string `json:"publicKey,omitempty"`
	PrivateKey *string `json:"privateKey,omitempty"`
}

// postData is what we'll marshal the data posted from the webhook into
type postData struct {
	Body    interface{}         `json:"body,omitempty"`
	Headers map[string][]string `json:"headers,omitempty"`
}

// the intent is for this to be run as: nohup go run cmd/main.go > logs/SystemOut.log &
func main() {
	err := getConf()
	if err != nil {
		log.Fatalf("Unable to read etc/postlog.json %s", err)
	}

	// /endpoint is what the webhook should use to POST messages to
	http.HandleFunc("/endpoint", handleRequest)

	// /logs will allow you to see the logs without sshing to the box running this
	http.HandleFunc("/logs", handleLogs)

	// Calculate the address and start on the host and port specified in the config
	httpAddr := *postlogConfig.Host + ":" + strconv.Itoa(*postlogConfig.HTTPPort)
	log.Printf("Attempting to start http webservice on %s", httpAddr)

	// Calculate the address and start on the host and port specified in the config
	if postlogConfig.PublicKey != nil && postlogConfig.PrivateKey != nil {
		httpsAddr := *postlogConfig.Host + ":" + strconv.Itoa(*postlogConfig.HTTPSPort)
		log.Printf("Attempting to start https webservice on %s", httpsAddr)
		// go log.Fatal(http.ListenAndServe...) will block because the listen and serve is evaluated first
		go func() {
			log.Fatal(http.ListenAndServe(httpAddr, nil))
		}()
		// allow the log.Fatal to block here so the system doesn't exit till it is manually killed
		log.Fatal(http.ListenAndServeTLS(httpsAddr, *postlogConfig.PublicKey, *postlogConfig.PrivateKey, nil))
	} else {
		// only start the http webservice if no ssl certs are found
		log.Fatal(http.ListenAndServe(httpAddr, nil))
	}
}

// getConf reads etc/postlog.json and unmarshals it for us to use
func getConf() error {
	f, err := os.Open("etc/postlog.json")
	if err != nil {
		return err
	}
	defer f.Close()

	bytes, err := ioutil.ReadAll(f)
	if err != nil {
		return err
	}

	err = json.Unmarshal(bytes, &postlogConfig)
	if err != nil {
		return err
	}

	return nil
}

// handleRequest will reject anything other than an HTTP POST
func handleRequest(response http.ResponseWriter, request *http.Request) {
	switch request.Method {
	case http.MethodPost:
		post(response, request)
	default:
		response.WriteHeader(http.StatusNotImplemented)
		log.Printf("Method %s being rejected, not implemented", request.Method)
	}
}

// post handles the HTTP POST reqquest from the webhook
func post(response http.ResponseWriter, request *http.Request) {
	body, err := ioutil.ReadAll(request.Body)
	if err != nil {
		log.Printf("Error reading body: %v", err)
		http.Error(response, "can't read body", http.StatusBadRequest)
		return
	}

	headers := make(map[string][]string)
	for k, v := range request.Header {
		headers[k] = v
	}

	// the assumption is the webhook is sending JSON as the message body
	var jsonBody interface{}
	json.Unmarshal(body, &jsonBody)

	json, err := json.Marshal(postData{
		Body:    jsonBody,
		Headers: headers,
	})

	if err != nil {
		log.Printf("Error marshaling the json: %v", err)
		http.Error(response, "can't marshal json", http.StatusBadRequest)
		return
	}

	log.Println(string(json))
	response.WriteHeader(http.StatusCreated)
}

// handleLogs sends the logs/SystemOut.log to the browser so you don't have to ssh to see them
func handleLogs(response http.ResponseWriter, request *http.Request) {
	fileExists, err := exists("logs/SystemOut.log")
	if err != nil {
		log.Printf("Cannot find logs/SystemOut.log %v", err)
		http.Error(response, "Cannot find logs/SystemOut.log", http.StatusBadRequest)
		return
	}

	if fileExists {
		http.ServeFile(response, request, "logs/SystemOut.log")
	} else {
		http.Error(response, "Not Found", http.StatusNotFound)
	}
}

// exists returns true if a file or directory exists.
func exists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return true, err
}
