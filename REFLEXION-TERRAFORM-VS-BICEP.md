# Réflexion — Terraform vs Bicep

## 1. Gestion de l'état

Terraform utilise un fichier `.tfstate` pour garder une trace des ressources qu'il gère. Cela permet de savoir précisément ce qui a été créé et de détecter les différences avec l'infrastructure réelle. Par contre, en équipe il faut mettre en place un backend distant et gérer le verrouillage du state.

Avec Bicep, il n'y a pas de fichier d'état à gérer : Azure Resource Manager regarde directement les ressources présentes dans Azure. Je trouve cela plus simple à mettre en place, mais il faut être plus attentif lors de la suppression car Bicep ne garde pas la liste des ressources comme Terraform.

## 2. Portabilité multi-cloud

Terraform est plus intéressant si une entreprise utilise plusieurs clouds, par exemple Azure et AWS, car le même outil peut gérer les différents fournisseurs.

Dans mon cas, si toute l'infrastructure est uniquement sur Azure, cet avantage est moins important. Bicep est alors très adapté car il est directement intégré à Azure.

## 3. Support des nouveaux services Azure

Bicep étant un outil Microsoft directement lié à ARM, les nouvelles ressources et versions d'API Azure sont généralement disponibles rapidement.

Avec Terraform, il faut attendre que le provider `azurerm` prenne en charge la nouvelle fonctionnalité. Cela pourrait devenir gênant dans un projet où l'on doit utiliser immédiatement une nouvelle fonctionnalité Azure qui n'est pas encore disponible dans le provider Terraform.

## 4. Syntaxe et écosystème de modules

J'ai trouvé Bicep assez direct pour créer des ressources Azure car les propriétés correspondent beaucoup à celles que l'on retrouve dans Azure et dans les templates ARM.

Terraform avec HCL reste également lisible et possède un écosystème de modules très important grâce au Terraform Registry. Pour un projet uniquement Azure, Bicep m'a semblé assez rapide à écrire. Pour un projet plus important ou multi-cloud, Terraform me paraît plus flexible grâce à son écosystème.

## 5. Cycle provisioning/destruction en CI

Avec Terraform, `terraform destroy` utilise le state pour savoir exactement quelles ressources doivent être supprimées.

Avec Bicep, nous avons dû écrire explicitement dans `bicep-destroy.yml` quels resource groups supprimer. Cela demande donc plus d'attention.

Dans une CI partagée, je trouve Terraform plus sécurisant pour la destruction grâce au state, à condition que le backend et les droits soient correctement configurés. Avec Bicep, je préfère utiliser un resource group distinct par exercice ou projet afin d'éviter de supprimer des ressources appartenant à quelqu'un d'autre.
