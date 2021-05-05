package main

import (
	"log"
	"os"

	"github.com/ONSdigital/github-explorer/agent/pkg/github"
)

func main() {
	firestoreProject := ""
	if firestoreProject = os.Getenv("FIRESTORE_PROJECT"); len(firestoreProject) == 0 {
		log.Fatal("Missing FIRESTORE_PROJECT environment variable")
	}

	gitHubAPIBaseURI := ""
	if gitHubAPIBaseURI = os.Getenv("GITHUB_API_BASE_URI"); len(gitHubAPIBaseURI) == 0 {
		log.Fatal("Missing GITHUB_API_BASE_URI environment variable")
	}

	gitHubEnterpriseName := ""
	if gitHubEnterpriseName = os.Getenv("GITHUB_ENTERPRISE_NAME"); len(gitHubEnterpriseName) == 0 {
		log.Fatal("Missing GITHUB_ENTERPRISE_NAME environment variable")
	}

	gitHubOrganisationName := ""
	if gitHubOrganisationName = os.Getenv("GITHUB_ORGANISATION_NAME"); len(gitHubOrganisationName) == 0 {
		log.Fatal("Missing GITHUB_ORGANISATION_NAME environment variable")
	}

	gitHubToken := ""
	if gitHubToken = os.Getenv("GITHUB_TOKEN"); len(gitHubToken) == 0 {
		log.Fatal("Missing GITHUB_TOKEN environment variable")
	}

	if len(os.Args[1:]) == 0 {
		log.Fatal("Missing GraphQL query command-line argument")
	}

	client := github.NewClient(gitHubToken, gitHubAPIBaseURI+"/graphql")
	switch query := os.Args[1]; query {
	case "all-repositories":
	case "member-roles":
	case "team-membership":
		client.PerformTeamMembershipLookup(gitHubOrganisationName)
	default:
		log.Fatalf("Unknown GraphQL query: '%s'", query)
	}
}
