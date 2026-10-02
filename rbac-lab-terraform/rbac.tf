# Three role assignments. Every field matters. The scope field is what makes
# each role apply to FS01 only — changing it to the resource group ID would
# silently expand the role to every resource in the group.

# Owner: full control on FS01 including the ability to assign
# and remove roles on this VM. In production you would split
# this into Contributor + User Access Administrator for finer control.
resource "azurerm_role_assignment" "sysadmin_owner" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Owner"
  principal_id         = var.sysadmin_object_id
}

# Virtual Machine Contributor: start, stop, restart, connect via RDP.
# Cannot delete the VM, resize it, or make any RBAC changes.
# This is the appropriate role for help desk or operations staff
# who manage VM availability but not VM configuration.
resource "azurerm_role_assignment" "supporttech_vm_contributor" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = var.support_user_object_id
}

# Reader: view configuration and status — no actions of any kind.
# Cannot start, stop, delete, or change the VM in any way.
# Appropriate for auditors who need visibility without risk.
resource "azurerm_role_assignment" "auditor_reader" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Reader"
  principal_id         = var.auditor_object_id
}
