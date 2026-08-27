package main

import (
	"flag"
	"fmt"
	"net/http"
)

func main() {
	listen := flag.String("listen", ":8080", "listen address")
	flag.Parse()
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	if err := http.ListenAndServe(*listen, nil); err != nil {
		panic(err)
	}
}
