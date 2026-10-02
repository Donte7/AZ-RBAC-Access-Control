# No new storage account needed. Replace
# REPLACE_WITH_YOUR_LAB1_STORAGE_ACCOUNT_NAME with the same storage account
# name you used in Lab 1. The only difference from Lab 1's backend.tf is the
# key value — this keeps both labs' state completely separate in the same
# container.
terraform {
  backend "azurerm" {
    resource_group_name  = "RG-TerraformState"
    storage_account_name = "tfstatentfsnerdlab"
    container_name       = "tfstate"
    key                  = "rbac-lab.terraform.tfstate"
    # Lab 1 uses: ntfs-lab.terraform.tfstate
    # Both files live in the same container without touching each other
  }
}
