package main

import (
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/elbv2"
	"github.com/hashicorp/logutils"
)

type MyEvent struct {
	TargetGroupArn string `json:"targetGroupArn"` // Target Group ARN
	DomainName     string `json:"domainName"`     // Domain name
	TargetPort     int64  `json:"targetPort"`     // Target port (default is to use traffic port)
}

type MyResponse struct {
	Status string `json:"status"`
}

var (
	name    = "lambda-lb-target-group-dns"
	version = "dev"
)

func getTargetGroup(svc *elbv2.ELBV2, targetGroupARN string) (*elbv2.TargetGroup, error) {
	input := &elbv2.DescribeTargetGroupsInput{
		TargetGroupArns: []*string{
			aws.String(targetGroupARN),
		},
	}

	output, err := svc.DescribeTargetGroups(input)
	if err != nil {
		return nil, err
	}

	if len(output.TargetGroups) == 0 {
		return nil, fmt.Errorf("target group %s not found", targetGroupARN)
	}

	return output.TargetGroups[0], nil
}

func getTargetGroupIPs(svc *elbv2.ELBV2, targetGroupArn string) ([]string, error) {
	input := &elbv2.DescribeTargetHealthInput{
		TargetGroupArn: aws.String(targetGroupArn),
	}

	result, err := svc.DescribeTargetHealth(input)
	if err != nil {
		return nil, err
	}

	var ipAddresses []string
	for _, targetHealth := range result.TargetHealthDescriptions {
		if targetHealth.Target != nil && targetHealth.Target.Id != nil {
			ipAddresses = append(ipAddresses, *targetHealth.Target.Id)
		}
	}

	return ipAddresses, nil
}

func registerTarget(svc *elbv2.ELBV2, targetGroupArn string, targetIP string, targetPort int64) error {
	input := &elbv2.RegisterTargetsInput{
		TargetGroupArn: aws.String(targetGroupArn),
		Targets: []*elbv2.TargetDescription{
			{
				Id:   aws.String(targetIP),
				Port: aws.Int64(targetPort),
			},
		},
	}

	_, err := svc.RegisterTargets(input)
	return err
}

func deregisterTarget(svc *elbv2.ELBV2, targetGroupArn string, targetIP string, targetPort int64) error {
	input := &elbv2.DeregisterTargetsInput{
		TargetGroupArn: aws.String(targetGroupArn),
		Targets: []*elbv2.TargetDescription{
			{
				Id:   aws.String(targetIP),
				Port: aws.Int64(targetPort),
			},
		},
	}

	_, err := svc.DeregisterTargets(input)
	return err
}

func lookupIp(domain string, ipAddressType string) ([]string, error) {
	ips, err := net.LookupIP(domain)
	if err != nil {
		if dnsErr, ok := err.(*net.DNSError); ok && dnsErr.Err == "no such host" {
			// The domain does not exist: just return empty list
			return []string{}, nil
		}
		return []string{}, err
	}

	var ipAddresses []string
	for _, ip := range ips {
		if ipAddressType == "ipv4" && ip.To4() != nil || ipAddressType == "ipv6" && ip.To4() == nil {
			log.Printf("[TRACE] %s %s", ipAddressType, ip.String())
			ipAddresses = append(ipAddresses, ip.String())
		}
	}

	return ipAddresses, nil
}

func HandleLambdaEvent(event *MyEvent) (*MyResponse, error) {
	var err error

	if event == nil {
		return nil, errors.New("received nil event")
	}

	awsRegion := os.Getenv("AWS_REGION")
	sess, err := session.NewSessionWithOptions(session.Options{
		SharedConfigState: session.SharedConfigEnable,
		Config: aws.Config{
			Region:                        aws.String(awsRegion),
			CredentialsChainVerboseErrors: aws.Bool(true),
		},
	})
	if err != nil {
		return nil, err
	}

	svc := elbv2.New(sess)

	tg, err := getTargetGroup(svc, event.TargetGroupArn)
	if err != nil {
		return nil, err
	}
	log.Printf("[TRACE] TargetGroup %s", strings.ReplaceAll(strings.ReplaceAll(tg.String(), "\n  ", " "), "\n", " "))

	if *tg.TargetType != "ip" {
		return nil, errors.New("target group type must be ip")
	}

	targetPort := event.TargetPort
	if targetPort == 0 {
		targetPort = *tg.Port
	}

	dnsIpAddresses, err := lookupIp(event.DomainName, *tg.IpAddressType)
	if err != nil {
		return nil, err
	}
	log.Printf("[DEBUG] %s resolves to %v", event.DomainName, dnsIpAddresses)

	dnsIpAddressesMap := make(map[string]bool)
	for _, ip := range dnsIpAddresses {
		dnsIpAddressesMap[ip] = true
	}

	tgIpAddresses, err := getTargetGroupIPs(svc, event.TargetGroupArn)
	if err != nil {
		return nil, err
	}
	log.Printf("[DEBUG] %s has targets %v", *tg.TargetGroupName, tgIpAddresses)

	tgIpAddressesMap := make(map[string]bool)
	for _, ip := range tgIpAddresses {
		tgIpAddressesMap[ip] = true
	}

	for _, ip := range dnsIpAddresses {
		if _, exists := tgIpAddressesMap[ip]; !exists {
			log.Printf("[DEBUG] Adding %s:%d to Target Group %s", ip, targetPort, *tg.TargetGroupName)
			err := registerTarget(svc, event.TargetGroupArn, ip, targetPort)
			if err != nil {
				return nil, err
			}
		}
	}

	for _, ip := range tgIpAddresses {
		if _, exists := dnsIpAddressesMap[ip]; !exists {
			log.Printf("[DEBUG] Removing %s:%d from Target Group %s", ip, targetPort, *tg.TargetGroupName)
			err := deregisterTarget(svc, event.TargetGroupArn, ip, targetPort)
			if err != nil {
				return nil, err
			}
		}
	}

	tgIpAddresses2, err := getTargetGroupIPs(svc, event.TargetGroupArn)
	if err != nil {
		return nil, err
	}

	log.Printf("[DEBUG] Registered IP addresses of domain %s to Target Group %s: %v", event.DomainName, *tg.TargetGroupName, tgIpAddresses2)

	return &MyResponse{Status: "OK"}, nil
}

func main() {
	logLevel := os.Getenv("LOG_LEVEL")
	if logLevel == "" {
		logLevel = "DEBUG"
	}

	filter := &logutils.LevelFilter{
		Levels:   []logutils.LogLevel{"TRACE", "DEBUG", "INFO", "ERROR"},
		MinLevel: logutils.LogLevel(logLevel),
		Writer:   os.Stderr,
	}
	log.SetOutput(filter)

	if version == "dev" {
		fmt.Println(name, version)
	} else {
		fmt.Printf("%s v%s\n", name, version)
	}

	if _, exist := os.LookupEnv("AWS_LAMBDA_RUNTIME_API"); exist {
		lambda.Start(HandleLambdaEvent)
	} else {
		event := MyEvent{}

		flag.StringVar(&event.TargetGroupArn, "target-group-arn", "", "Target Group ARN")
		flag.StringVar(&event.DomainName, "domain-name", "", "Domain name")
		flag.Int64Var(&event.TargetPort, "target-port", 0, "Target port")

		flag.Parse()

		if event.TargetGroupArn == "" || event.DomainName == "" {
			fmt.Printf("\nUsage: %s\n\n", os.Args[0])
			flag.PrintDefaults()
			os.Exit(2)
		}

		response, err := HandleLambdaEvent(&event)

		if err != nil {
			log.Fatalf("[ERROR] %v", err)
		}

		log.Printf("[TRACE] response: %v", response.Status)
	}
}
