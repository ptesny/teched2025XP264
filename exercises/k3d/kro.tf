locals {
  oauth2mock_kro_rgds = flatten([
     { for fileName in fileset(path.module, "manifests/kro/oauth2mock/rgd*.yaml") : fileName => file("${path.module}/${fileName}") }
  ])  

  oauth2mock_kro_runs = flatten([
      { for fileName in fileset(path.module, "manifests/kro/oauth2mock/instance*.yaml") : fileName => templatefile("${path.module}/${fileName}", { namespace = "default" }) }
  ])
}

resource "kubectl_manifest" "oauth2mock_kro_rgds" {
  for_each  = merge(local.oauth2mock_kro_rgds...)

  yaml_body = each.value

  wait              = true
  force_conflicts   = true  
  server_side_apply = true
  ignore_fields     = ["metadata.annotations", "metadata.deletionTimestamp"]

  depends_on = [ helm_release.quovadis-kro ]  
}

resource "kubectl_manifest" "oauth2mock_kro_runs" {
  for_each  = merge(local.oauth2mock_kro_runs...)

  yaml_body = each.value

  wait              = true
  force_conflicts   = true  
  server_side_apply = true
  ignore_fields     = ["metadata.annotations", "metadata.deletionTimestamp"]

  depends_on = [ kubectl_manifest.oauth2mock_kro_rgds ]  
}



locals {
  namespaces = formatlist("kro-%03d", range(0, 10 + 1)) // list of string with 11 elements


  # flatten ensures that this local value is a flat list of objects, rather
  # than a list of lists of objects.
  teams_namespaces = flatten([
    for n in local.namespaces : [
      { for fileName in fileset(path.module, "manifests/teams-automation/teams/[a-z]*.yaml") : format("%s+%s",n,fileName) => templatefile("${path.module}/${fileName}", { namespace = n }) }
    ] 
  ])

  webapp_kro_rgds = flatten([
     { for fileName in fileset(path.module, "manifests/kro/webapp/rgd*.yaml") : fileName => file("${path.module}/${fileName}") }
  ])  

  webapp_kro_runs = flatten([
    for n in local.namespaces : [
      { for fileName in fileset(path.module, "manifests/kro/webapp/instance*.yaml") : format("%s+%s",n,fileName) => templatefile("${path.module}/${fileName}", { namespace = n, allowinternaltraffic = true }) }
    ] 
  ])
}

output "webapp_kro_rgds" {
  sensitive = true
  value = local.webapp_kro_rgds
}

output "webapp_kro_runs" {
  sensitive = true
  value = local.webapp_kro_runs
}

resource "kubectl_manifest" "teams_namespaces" {
  for_each  = merge(local.teams_namespaces...)

  yaml_body = each.value

  wait              = true
  server_side_apply = true
  ignore_fields     = ["metadata.annotations", "metadata.deletionTimestamp"]

  depends_on = [ terraform_data.modules, helm_release.quovadis-kro ]
}


resource "helm_release" "quovadis-kro" {
  name             = "quovadis-kro"
  chart            = "oci://registry.k8s.io/kro/charts/kro"

  namespace        = "kro"
  create_namespace = true
  force_update     = true
  cleanup_on_fail  = true
  upgrade_install  = true

//Unable to locate chart oci://registry.k8s.io/kro/charts/kro: failed to
//perform "FetchReference" on source: registry.k8s.io/kro/charts/kro:v0.7.0:
  version          = "0.7.0"

  description      = "kyma KRO module"
}

output "kro_helm_release" {
  sensitive = true
  value = nonsensitive(helm_release.quovadis-kro)
}

output "quovadis-kro" {
  sensitive = true
  value = nonsensitive(helm_release.quovadis-kro.metadata)
}

resource "kubectl_manifest" "webapp_kro_rgds" {
  for_each  = merge(local.webapp_kro_rgds...)

  yaml_body = each.value

  wait              = true
  force_conflicts   = true  
  server_side_apply = true
  ignore_fields     = ["metadata.annotations", "metadata.deletionTimestamp"]

  depends_on = [ kubectl_manifest.oauth2mock_kro_runs ]  
}

resource "kubectl_manifest" "webapp_kro_runs" {
  for_each  = merge(local.webapp_kro_runs...)

  yaml_body = each.value

  wait              = true
  force_conflicts   = true  
  server_side_apply = true
  ignore_fields     = ["metadata.annotations", "metadata.deletionTimestamp"]

  depends_on = [ kubectl_manifest.webapp_kro_rgds, kubectl_manifest.teams_namespaces ]  
}