package main

import (
	"fmt"

	"example.com/monorepo/internal/auth"
	"example.com/monorepo/internal/metrics"
	"example.com/monorepo/internal/store"
)

func main() {
	fmt.Println(auth.Name(), store.Name(), metrics.Name())
}
