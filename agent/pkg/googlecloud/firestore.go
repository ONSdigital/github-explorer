package googlecloud

import (
	"context"
	"log"

	"cloud.google.com/go/firestore"
)

// NewFirestoreClient instantiates a new Firestore client for the passed GCP project name.
func NewFirestoreClient(projectName string) *FirestoreClient {
	ctx := context.Background()
	client, err := firestore.NewClient(ctx, projectName)
	if err != nil {
		log.Fatalf("Failed to instantiate Firestore client in project %s: %v", projectName, err)
	}

	return &FirestoreClient{
		projectName: projectName,
		context:     &ctx,
		client:      client,
	}
}
