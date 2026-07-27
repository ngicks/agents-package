package main

import "fmt"

//go:generate cp version.tmpl version_gen.go

func main() {
	fmt.Println(version)
}
