# Update the existing resource to use HCL object format
resource "azapi_update_resource" "aks_cluster_post_create" {
  type        = "Microsoft.ContainerService/managedClusters@2023-07-02-preview"
  resource_id = azurerm_kubernetes_cluster.main.id
  body = {
    properties = {
      kubernetesVersion = var.kubernetes_version
    }
  }
} 