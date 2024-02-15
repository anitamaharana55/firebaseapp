# Terraform configuration to set up providers by version.
terraform {
  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
  }
}
provider "google-beta" {
  user_project_override = true
}
provider "google-beta" {
  alias = "no_user_project_override"
  user_project_override = false
}
resource "google_project" "default" {
  provider   = google-beta.no_user_project_override

  name       = "My New Project"
  project_id = "fine-justice-82493"
  billing_account = "01D776-E23893-E3C461"
  labels = {
    "firebase" = "enabled"
  }
}
resource "google_project_service" "default" {
  provider = google-beta.no_user_project_override
  project  = google_project.default.project_id
  for_each = toset([
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "firebase.googleapis.com",
    "serviceusage.googleapis.com",
  ])
  service = each.key
  disable_on_destroy = false
}

# Enables Firebase services for the new project created above.
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = google_project.default.project_id

  # Waits for the required APIs to be enabled.
  depends_on = [
    google_project_service.default

  ]
}

# Creates a Firebase Android App in the new project created above.
resource "google_firebase_android_app" "default" {
  provider = google-beta

  project      = google_project.default.project_id
  display_name = "My Awesome Android app"
  package_name = "awesome.package.name"

  # Wait for Firebase to be enabled in the Google Cloud project before creating this App.
  depends_on = [
    google_firebase_project.default,
  ]
}
# Create a Firebase Web App in the new project created above.
resource "google_firebase_web_app" "default" {
  provider = google-beta

  project      = google_firebase_project.default.project
  display_name = "My New Firebase Project Display Name"
  deletion_policy = "DELETE"
}
resource "google_firebase_hosting_site" "full" {
  provider = google-beta
  project  = google_firebase_project.default.project
  site_id = "site-with-app-abe4c"
  app_id = google_firebase_web_app.default.app_id
}
# Enable the Identity Toolkit API.
resource "google_project_service" "auth" {
  provider = google-beta

  project  = google_firebase_project.default.project
  service =  "identitytoolkit.googleapis.com"

  # Don't disable the service if the resource block is removed by accident.
  disable_on_destroy = false
}

# Create an Identity Platform config.
# Also, enable Firebase Authentication using Identity Platform (if Authentication isn't yet enabled).
resource "google_identity_platform_config" "auth" {
  provider = google-beta
  project  = google_firebase_project.default.project

  # For example, you can configure to auto-delete anonymous users.
  autodelete_anonymous_users = true

  # Wait for identitytoolkit.googleapis.com to be enabled before initializing Authentication.
  depends_on = [
    google_project_service.auth,
  ]
}
resource "google_identity_platform_default_supported_idp_config" "google_sign_in" {
  provider = google-beta
  project  = google_firebase_project.default.project

  enabled       = true
  idp_id        = "google.com"
  client_id     = "63817807393-bi81iag3pmc8a543qgp4uihht0avgrnm.apps.googleusercontent.com"
  client_secret = "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"
  #client_secret = var.oauth_client_secret

  depends_on = [
     google_identity_platform_config.auth
  ]
}

# Enable required APIs for Cloud Firestore.
resource "google_project_service" "firestore" {
  provider = google-beta

  project  = google_firebase_project.default.project
  for_each = toset([
    "firestore.googleapis.com",
    "firebaserules.googleapis.com",
  ])
  service = each.key

  # Don't disable the service if the resource block is removed by accident.
  disable_on_destroy = false
}

# Provision the Firestore database instance.
resource "google_firestore_database" "default" {
  provider                    = google-beta

  project                     = google_firebase_project.default.project
  name                        = "(default)"
  # https://firebase.google.com/docs/firestore/locations
  location_id                 = "us-central1"
  # "FIRESTORE_NATIVE" is required to use Firestore with Firebase SDKs,
  # authentication, and Firebase Security Rules.
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"

  depends_on = [
    google_project_service.firestore
  ]
}








