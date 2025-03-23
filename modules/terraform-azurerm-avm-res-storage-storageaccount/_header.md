# Terraform Azure Storage Account Module

This Terraform module is designed to create Azure Storage Accounts and its related resources, including blob containers, queues, tables, and file shares. It also supports the creation of a storage account private endpoint which provides secure and direct connectivity to Azure Storage over a private network.

> [!WARNING]
> Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. A module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to <https://semver.org/>

## Features

* Create a storage account with various configuration options such as account kind, tier, replication type, network rules, and identity settings.
* Create blob containers, queues, tables, and file shares within the storage account.
* Support for customer-managed keys for encrypting the data in the storage account.
* Enable private endpoint for the storage account, providing secure access over a private network.

## Limitations

* The storage account name must be globally unique.
* The module creates resources in the same region as the storage account.

> **IMPORTANT** We recommend using Azure AD authentication over Shared Key for provisioning Storage Containers, Blobs, and other items. To achieve this, add the `storage_use_azuread` flag in the Provider block. However, it’s important to note that not all Azure Storage services support Active Directory authentication.(https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#storage_use_azuread) In the absence of the `storage_use_azuread` flag, you will need to enable Shared Key Access by setting the `shared_access_key_enabled` flag `True`.
