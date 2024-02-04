package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
)

type MyEvent struct {
	Name string `json:"name"` // Name
	Age  int    `json:"age"`  // Age
}

type MyResponse struct {
	Message string `json:"answer"`
}

func HandleLambdaEvent(event *MyEvent) (*MyResponse, error) {
	if event == nil {
		return nil, fmt.Errorf("received nil event")
	}
	return &MyResponse{Message: fmt.Sprintf("%s is %d years old!", event.Name, event.Age)}, nil
}

func main() {
	if _, exist := os.LookupEnv("AWS_LAMBDA_RUNTIME_API"); exist {
		lambda.Start(HandleLambdaEvent)
	} else {
		event := MyEvent{}

		flag.StringVar(&event.Name, "name", "", "Specify the name")
		flag.IntVar(&event.Age, "age", 0, "Specify the age")

		flag.Parse()

		if event.Name == "" && event.Age == 0 {
			fmt.Printf("Usage: %s\n\n", os.Args[0])
			flag.PrintDefaults()
			return
		}

		response, err := HandleLambdaEvent(&event)

		if err != nil {
			fmt.Fprintln(os.Stderr, response)
			os.Exit(1)
		}

		fmt.Println(response.Message)
	}
}
