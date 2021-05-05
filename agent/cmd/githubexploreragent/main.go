package main

import (
	"log"
	"os"
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
}
