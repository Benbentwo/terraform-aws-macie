locals {
  enabled                 = module.this.enabled
  account_enabled         = local.enabled && var.account_enabled
  admin_account_ids       = local.enabled && length(var.admin_account_ids) > 0 ? var.admin_account_ids : []
  members                 = local.enabled && length(var.members) > 0 ? { for member in flatten(var.members) : member.email => member } : {}
  custom_data_identifiers = local.enabled && length(var.custom_data_identifiers) > 0 ? { for cdi in flatten(var.custom_data_identifiers) : cdi.name => cdi } : {}
  classification_jobs     = local.enabled && length(var.classification_jobs) > 0 ? { for job in flatten(var.classification_jobs) : job.name => job } : {}
}

resource "aws_macie2_account" "default" {
  count = local.enabled ? 1 : 0

  finding_publishing_frequency = var.finding_publishing_frequency
  status                       = local.account_enabled ? "ENABLED" : "PAUSED"
}

resource "aws_macie2_organization_admin_account" "default" {
  for_each = toset(var.admin_account_ids)

  admin_account_id = each.value

  depends_on = [
    aws_macie2_account.default
  ]
}


module "member_label" {
  for_each = local.members

  source  = "cloudposse/label/null"
  version = "0.24.1"

  attributes = [replace(each.key, "/[[:punct:]]/", "-")]
  tags       = lookup(each.value, "tags", null)
  context    = module.this.context
}

resource "aws_macie2_member" "default" {
  for_each = local.members

  account_id                            = each.value.account_id
  email                                 = each.value.email
  invite                                = lookup(each.value, "invite", null)
  invitation_message                    = lookup(each.value, "invitation_message", null)
  invitation_disable_email_notification = lookup(each.value, "invitation_disable_email_notification", null)
  status                                = lookup(each.value, "status", "ENABLED")
  tags                                  = module.member_label[each.key].tags

  depends_on = [
    aws_macie2_account.default
  ]
}
