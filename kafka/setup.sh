export KSA_NAME=kafka-sa
export NAMESPACE=kafka
export GSA_NAME=kafka-sa
export GSA_PROJECT=sbx-stag
export PROJECT_ID=sbx-stag

kubectl create ns $NAMESPACE

kubectl create secret generic database-secrets --from-literal=password=$PASSWORD -n $NAMESPACE

gcloud config set project $PROJECT_ID

kubectl create serviceaccount $KSA_NAME \
    --namespace $NAMESPACE

gcloud iam service-accounts create $GSA_NAME \
    --project=$GSA_PROJECT

gcloud iam service-accounts add-iam-policy-binding $GSA_NAME@$GSA_PROJECT.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]"

kubectl annotate serviceaccount $KSA_NAME \
    --namespace $NAMESPACE \
    iam.gke.io/gcp-service-account=$GSA_NAME@$GSA_PROJECT.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding $GSA_PROJECT \
    --member "serviceAccount:$GSA_NAME@$GSA_PROJECT.iam.gserviceaccount.com" \
    --role "roles/managedkafka.client"